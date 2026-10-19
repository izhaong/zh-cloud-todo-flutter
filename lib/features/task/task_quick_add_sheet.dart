import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/settings/quick_add_action_bar_setting.dart';
import '../../core/settings/smart_date_recognition_setting.dart';
import 'tasks_by_list_page.dart' show kInboxListId;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_entities.dart';
import '../../state/nlp_date.dart';
import '../../state/providers.dart';
import '../../state/repositories/task_capture_defaults_repository.dart';
import '../../state/repositories/template_repository.dart';
import '../tag/tag_color.dart';
import 'default_reminder_fire_at.dart';

/// M11-B2 任务快速添加 bottom sheet。
class TaskQuickAddSheet extends ConsumerStatefulWidget {
  const TaskQuickAddSheet({
    super.key,
    required this.listId,
    this.parentTaskId,
    this.sectionId,
  });

  final String listId;
  final String? parentTaskId;

  /// 非空时新建的任务直接落在该清单分组里（看板分组列的「+」）。
  final String? sectionId;

  @override
  ConsumerState<TaskQuickAddSheet> createState() => _TaskQuickAddSheetState();
}

class _TaskQuickAddSheetState extends ConsumerState<TaskQuickAddSheet> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  /// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》:15「你可以在输入完第一个子任务之后
  /// 点击「纸飞机」图标完成创建，或者点击键盘左下角的「换行」来完成创建当前子任务，并且可以继续创建
  /// 第二个同级的子任务，如此往复。」与 desktop tab 的 :56「点击「Enter」来继续创建第二个同级的子任务」。
  ///
  /// 只有**建子任务**这张表是连续的：`:15`/`:56` 两句都长在「创建子任务」那一节里，
  /// 收集箱/清单的快速添加原文没提"如此往复"，所以 `parentTaskId == null` 时提交仍然照旧关表。
  bool get _consecutive => widget.parentTaskId != null;

  // ── FL #344 面①：底部功能栏（产品裁决：日期→优先级→标签→清单，可调序）──
  // 手选覆盖（用户最后的动作最大）：手选过就压着 NLP 识别，识别行只在没手选时出现。
  DateTime? _manualDueAt;
  List<String>? _manualTagIds;
  String? _manualListId;
  // sectionId 降级为 state：切清单时必须清空（分区属于原清单，保留会撞
  // create 的 _requireSectionInList 直接抛 StateError —— opencode 点名）。
  late String _listId;
  String? _sectionId;
  List<String> _barOrder = List.of(QuickAddActionBarSetting.defaultOrder);
  int? _priorityOverride;
  DateTime? _nlpResolvedDueAt;

  /// 「智能识别日期」总开关（FL #344，`:85`）。默认开；关掉后**不再解析标题里的时间**。
  bool _smartDateEnabled = SmartDateRecognitionSetting.defaultEnabled;

  /// 用户**明确取消**过这一条的识别（FL #344，`:81`「点击「已识别的时间」，就能取消识别」）。
  ///
  /// 它要一直压着识别，直到这条任务建完（标题清空时复位）——
  /// 否则用户一取消、再敲一个字又回来了，那句"取消"就等于没做。
  bool _nlpCancelled = false;

  /// 「任务已建、提醒没建成」时记住任务 id：再点一次「保存」只补提醒，不建第二遍任务。
  String? _savedTaskId;
  bool _applyingTemplate = false;
  bool _saving = false;
  String? _feedback;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _listId = widget.listId;
    _sectionId = widget.sectionId;
    // 读总开关；读到之前按默认（开）——识别是既有行为，不能因为"还没读到"就停一屏。
    SmartDateRecognitionSetting().read().then((enabled) {
      if (mounted && enabled != _smartDateEnabled) {
        setState(() => _smartDateEnabled = enabled);
      }
    });
    // FL #344 面①：底栏序渲染**从配置读**（读不到=默认序）。v1 不给编辑入口，
    // 但路径必须走配置 —— 硬编码会把"推迟"变成"返工"（opencode）。
    QuickAddActionBarSetting().read().then((order) {
      if (mounted && order != _barOrder) {
        setState(() => _barOrder = order);
      }
    });
    _titleCtrl.addListener(_maybeResolveDate);
  }

  @override
  void dispose() {
    _titleCtrl
      ..removeListener(_maybeResolveDate)
      ..dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _maybeResolveDate() {
    if (_titleError != null && _titleCtrl.text.trim().isNotEmpty) {
      setState(() => _titleError = null);
    }
    // 两道闸门：总开关关掉（`:85`）或用户取消过这一条（`:81`）⇒ **不识别**。
    if (!_smartDateEnabled || _nlpCancelled) {
      if (_nlpResolvedDueAt != null) {
        setState(() => _nlpResolvedDueAt = null);
      }
      return;
    }
    final resolved = NlpDateParser().parse(_titleCtrl.text);
    if (resolved?.date != _nlpResolvedDueAt) {
      setState(() => _nlpResolvedDueAt = resolved?.date);
    }
  }

  /// 「保存」的 in-flight 闸门：`_saveOnce` 有 2–3 个 await，窗口内连点会建出重复任务。
  /// 模板路径 `_addFromTemplate` 已有 `_applyingTemplate` 同样的守卫，这条漏了。
  /// 复位放 finally：中途抛错或弹窗已被 pop 掉，都不该把按钮永久锁死。
  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      await _saveOnce();
    } finally {
      _saving = false;
    }
  }

  Future<void> _saveOnce() async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) {
      // 与 _addFromTemplate 同一措辞：未登录点「保存」不能静默吞掉这一次点击。
      // 排在标题校验之前：未登录是阻断性前置条件，不该让人点两次才知道自己没登录。
      _report('请先登录');
      return;
    }
    // 判据源《05-智能识别》:5「…自动识别并为您创建日期**和提醒**」。
    // `_nlpResolvedDueAt` 只由识别路径赋值（模板那条 `_addFromTemplate` 不碰它），
    // 所以"识别命中"与"有 dueAt"在这文件里是同一件事，不需要再引第二个标志位。
    // FL #344 面①：手选日期压着 NLP 识别（用户最后的动作最大）——
    // 手选过就不再看识别结果，识别行也只在没手选时出现。
    final dueAt = _manualDueAt ?? _nlpResolvedDueAt;
    String? savedTitle;
    TaskCaptureDefaults? defaults;
    if (_savedTaskId == null) {
      final text = _titleCtrl.text.trim();
      if (text.isEmpty) {
        setState(() => _titleError = '请输入任务标题');
        return;
      }
      try {
        defaults = await ref.read(taskCaptureDefaultsRepositoryProvider)?.get();
        final task = await repo.create(
          listId: _listId,
          parentTaskId: widget.parentTaskId,
          sectionId: _sectionId,
          title: text,
          priority: _priorityOverride ?? defaults?.defaultPriority ?? 0,
          dueAt: dueAt,
        );
        _savedTaskId = task.id;
        savedTitle = text;
        // FL #344 面①：标签是**二次写入**（opencode：v1 不给 create 加 tagIds）。
        // 失败语义照 _saveOnce 先例 —— 任务已建、标签没绑上 ⇒ 明说，不回滚任务。
        if (_manualTagIds != null && _manualTagIds!.isNotEmpty) {
          final db = ref.read(appDatabaseProvider);
          final queue = ref.read(syncChangeQueueProvider);
          if (db == null || queue == null) {
            _report('任务已建，但标签没设置成功');
            return;
          }
          try {
            for (final tagId in _manualTagIds!) {
              await db
                  .into(db.todoTaskTags)
                  .insert(
                    TodoTaskTagsCompanion.insert(taskId: task.id, tagId: tagId),
                  );
            }
            await queue.enqueue(
              entity: SyncEntities.taskTag,
              op: SyncOps.upsert,
              localId: task.id,
              serverId: task.serverId,
              payload: {'taskId': task.id, 'tagIds': _manualTagIds},
            );
          } catch (_) {
            _report('任务已建，但标签没设置成功');
            // 标签失败不阻断保存 —— dueAt/提醒链继续走
          }
        }
      } on StateError catch (error) {
        _report(error.message.toString());
        return;
      } catch (_) {
        _report('保存任务失败，请稍后重试');
        return;
      }
    }
    if (dueAt == null) {
      _afterSaved(savedTitle);
      return;
    }
    // 提醒那半：任务已经落库，这一步失败不能说成"保存成功"，也不能回滚任务。
    final reminders = ref.read(reminderRepositoryProvider);
    if (reminders == null) {
      // 写成 `?.create(...)` 就是一次静默早退——正是 #289/#292 清掉的那类缺陷。
      _report('任务已建，但提醒没建成：提醒功能当前不可用');
      return;
    }
    try {
      final fireAt = reminderFireAtFor(
        dueAt,
        defaultReminderMinutes: defaults?.defaultReminderMinutes,
        now: DateTime.now(),
      );
      // 默认提醒把时刻推到过去（<= now）：不建提醒也不报错。给过期时刻建
      // 提醒只会立刻响一次，不是「默认提醒」该有的行为；任务本身照建。
      if (fireAt == null) {
        _afterSaved(savedTitle);
        return;
      }
      await reminders.create(taskId: _savedTaskId!, fireAt: fireAt);
      _afterSaved(savedTitle);
    } on StateError catch (error) {
      _report('任务已建，但提醒没建成：${error.message}');
    } catch (_) {
      _report('任务已建，但提醒没建成，请稍后在任务里添加提醒');
    }
  }

  /// 建完一条之后的收尾：连续档把这张表留在原地（清空标题、抢回焦点、复位"已建过"标记），
  /// 其余一律按原行为关表。
  ///
  /// `_savedTaskId = null` 是关键的一步：`_saveOnce` 靠它区分「这次只补提醒，不建第二遍任务」。
  /// 不复位的话第二次「保存」会跳过建任务、只给第一条补提醒 ⇒ 用户以为建了两条，实际只有一条。
  void _afterSaved(String? savedTitle) {
    if (!_consecutive) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!mounted) return;
    setState(() {
      _savedTaskId = null;
      _titleCtrl.clear();
      // `_nlpResolvedDueAt` 是从标题里识别出来的，标题清空后它不能再留着。
      _nlpResolvedDueAt = null;
      // 取消标记同理：这一条已经建完，下一条该重新按用户的意愿识别。
      _nlpCancelled = false;
      _titleError = null;
      // 优先级是人在这张表上手选的，连续建同级子任务时不该被抹回默认值。
      _feedback = savedTitle == null ? null : '已添加子任务「$savedTitle」，可以继续输入下一个';
    });
    _titleFocus.requestFocus();
  }

  /// 结果只写在弹窗自己的一行里，不走 SnackBar：生产里本弹窗是 `showModalBottomSheet`
  /// 的一层路由，根 ScaffoldMessenger 的 SnackBar 画在弹窗底下，手机上等于没有反馈。
  void _report(String message) {
    if (!mounted) return;
    setState(() => _feedback = message);
  }

  /// 嘀嗒《如何使用任务模板？》移动端：「点击任务输入弹窗下方的「...」按钮，选择「模板」」。
  Future<void> _addFromTemplate() async {
    final templates = ref.read(templateRepositoryProvider);
    if (templates == null) {
      _report('请先登录');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _QuickAddTemplatePicker(
        templates: templates,
        onPick: (template) async {
          if (_applyingTemplate) return;
          _applyingTemplate = true;
          // 请求在飞时用户可以先滑掉弹层：那时元素还没 dispose，只有路由已不是当前路由。
          final pickerRoute = ModalRoute.of(sheetContext);
          String message;
          try {
            final seed = templates.taskSeed(template);
            final repo = ref.read(taskRepositoryProvider)!;
            await repo.create(
              listId: _listId,
              parentTaskId: widget.parentTaskId,
              sectionId: _sectionId,
              title: seed.title,
              description: seed.description,
              priority: seed.priority,
            );
            message = '已应用模板“${template.name}”';
          } on StateError catch (error) {
            message = error.message.toString();
          } catch (_) {
            message = '保存任务失败，请稍后重试';
          } finally {
            _applyingTemplate = false;
          }
          // 两道判定各管一件事：mounted 保证 `Navigator.of` 不越界，
          // isCurrent 保证不把下一层路由（宿主的快速添加弹窗）一起关掉。
          if (sheetContext.mounted &&
              pickerRoute != null &&
              pickerRoute.isCurrent) {
            Navigator.of(sheetContext).pop();
          }
          _report(message);
        },
      ),
    );
  }

  /// FL #344 面①：日期弹层（tap=打开；长按=清除 —— 与桌面底栏逐字对齐）。
  /// FL #344 第二步：功能栏顺序编辑器（`:24`「点击「...」-「设置」，
  /// 快速设置你的常用功能」）。v1 用**上移/下移**（不引拖拽依赖）：
  /// 四个固定项的排序，上移/下移操作可见、可撤销（reset），比拖拽便宜一个量级。
  Future<void> _openBarOrderEditor() async {
    final setting = QuickAddActionBarSetting();
    var working = List.of(_barOrder);
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.5,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '设置常用功能',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < working.length; i++)
                        ListTile(
                          key: Key('todo-bar-order-row-${working[i]}'),
                          leading: const Icon(Icons.drag_handle),
                          title: Text(_barOrderLabelOf(working[i])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: Key('todo-bar-order-up-${working[i]}'),
                                icon: const Icon(Icons.arrow_upward),
                                onPressed: i == 0
                                    ? null
                                    : () => setSheet(() {
                                        final row = working.removeAt(i);
                                        working.insert(i - 1, row);
                                      }),
                              ),
                              IconButton(
                                key: Key('todo-bar-order-down-${working[i]}'),
                                icon: const Icon(Icons.arrow_downward),
                                onPressed: i == working.length - 1
                                    ? null
                                    : () => setSheet(() {
                                        final row = working.removeAt(i);
                                        working.insert(i + 1, row);
                                      }),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('todo-bar-order-reset'),
                        onPressed: () {
                          setSheet(
                            () => working = List.of(
                              QuickAddActionBarSetting.defaultOrder,
                            ),
                          );
                        },
                        child: const Text('恢复默认'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('todo-bar-order-save'),
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(working),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || saved == null) return;
    try {
      await setting.write(saved);
      if (mounted) {
        setState(() => _barOrder = List.of(saved));
      }
    } on ArgumentError catch (error) {
      // write 侧恰等校验 —— 理论上 UI 路径凑不出坏序（四项全在、只换位置），
      // 但留这条防线：坏序不许落库。
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message?.toString() ?? '顺序无效，未保存')),
        );
      }
    }
  }

  String _barOrderLabelOf(String id) => switch (id) {
    'date' => '日期',
    'priority' => '优先级',
    'tag' => '标签',
    'list' => '清单',
    _ => id,
  };

  Future<void> _openDateSheet() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final entry in const [('今天', 0), ('明天', 1), ('下周一', 7)])
              ListTile(
                title: Text(entry.$1),
                onTap: () =>
                    Navigator.pop(sheetContext, _dateFromOffset(entry.$2)),
              ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('选择日期…'),
              onTap: () async {
                final base = _manualDueAt ?? DateTime.now();
                final d = await showDatePicker(
                  context: sheetContext,
                  initialDate: base,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext, d);
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _manualDueAt = picked);
    }
  }

  DateTime _dateFromOffset(int days) =>
      DateTime.now().add(Duration(days: days));

  /// 优先级弹层。chip 显示**生效档**（求值结果）—— 用户看到的 == 将要保存的，
  /// 没有"未选"这个可见状态（opencode：v1 不做三态）。
  Future<void> _openPrioritySheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in const [3, 2, 1, 0])
              ListTile(
                title: Text(priorityLabel(p)),
                trailing: CircleAvatar(
                  backgroundColor: priorityColor(p),
                  radius: 8,
                ),
                onTap: () => Navigator.pop(sheetContext, p),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _priorityOverride = picked);
    }
  }

  /// 标签弹层。
  Future<void> _openTagSheet() async {
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? const [];
    if (tags.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在标签页创建标签')));
      return;
    }
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (listContext, setSheetState) => ListView(
            shrinkWrap: true,
            children: [
              for (final tag in tags)
                CheckboxListTile(
                  key: Key('todo-quick-add-tag-${tag.id}'),
                  value: _manualTagIds?.contains(tag.id) ?? false,
                  title: Text(tag.name),
                  onChanged: (v) => setSheetState(() {
                    final next = {...?_manualTagIds};
                    if (v ?? false) {
                      next.add(tag.id);
                    } else {
                      next.remove(tag.id);
                    }
                    // 直接改字段：StatefulBuilder 让弹层内即时回显
                    _manualTagIds = next.isEmpty ? null : next.toList();
                  }),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  key: const Key('todo-quick-add-tag-done'),
                  onPressed: () =>
                      Navigator.pop(sheetContext, _manualTagIds?.toSet()),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {});
    }
  }

  /// 清单弹层。**切清单必须联动清空 sectionId**（分区属于原清单，
  /// 保留会撞 create 的 _requireSectionInList 直接抛 StateError）。
  Future<void> _openListSheet() async {
    // 弹层打开前等 stream 首值：`valueOrNull` 在首次订阅的微任务未完成前是
    // null，直接开弹层会渲染成只有「收集箱」（树里 0 个清单项 —— FL #344 判据抓到的）。
    final lists = await ref.read(listsStreamProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: const Text('收集箱'),
              onTap: () => Navigator.pop(sheetContext, kInboxListId),
            ),
            for (final list in lists)
              ListTile(
                leading: const Icon(Icons.list_outlined),
                title: Text(list.name),
                onTap: () => Navigator.pop(sheetContext, list.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != _listId) {
      setState(() {
        _manualListId = picked;
        _listId = picked;
        _sectionId = null; // FL #344：分区属于原清单 —— 切清单必须清空
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = _priorityOverride ?? 0;
    return Padding(
      key: const Key('todo-quick-add-sheet'),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        // reverse：键盘弹起时内容底部对齐，保证「保存」与最后一行反馈可见。
        // 非滚动布局在同一档位下裁掉底部 45px（内容含 NLP 识别行 + 反馈行；不含 NLP 行时是 8.2px），
        // 而反馈行是 Column 的最后一个子节点 —— 被裁到视口外以后连都查不到（skipOffstage 过滤）。
        reverse: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.parentTaskId == null ? '新建任务' : '新建子任务',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('todo-quick-add-title-field'),
              controller: _titleCtrl,
              focusNode: _titleFocus,
              autofocus: true,
              // 连续档才改这一档动作：非连续传 null 就是平台默认值，与改动前逐字节等价。
              textInputAction: _consecutive ? TextInputAction.newline : null,
              onSubmitted: _consecutive ? (_) => unawaited(_save()) : null,
              decoration: InputDecoration(
                labelText: '标题',
                errorText: _titleError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _QuickAddActionBar(
              order: _barOrder,
              effectivePriority: priority,
              hasManualDate: _manualDueAt != null,
              hasManualTags: _manualTagIds?.isNotEmpty ?? false,
              hasManualList: _manualListId != null,
              manualListId: _manualListId ?? _listId,
              onTapDate: _openDateSheet,
              onLongPressDate: () => setState(() => _manualDueAt = null),
              onTapPriority: _openPrioritySheet,
              onTapTag: _openTagSheet,
              onTapList: _openListSheet,
              onTapEditOrder: _openBarOrderEditor,
            ),
            const SizedBox(height: 16),
            // FL #344 面①：手选日期压着 NLP —— 识别行只在**没手选**时出现
            // （手选过仍显示会让"两个来源"同时挂着，用户不知道谁生效）。
            if (_manualDueAt == null && _nlpResolvedDueAt != null)
              // `:81`「点击「已识别的时间」，就能取消识别」⇒ 这一行不是只读展示，
              // 它**本身就是取消入口**（原文给的两种方式之一；另一种是按删除键）。
              InkWell(
                key: const Key('todo-quick-add-recognized-date'),
                onTap: () => setState(() {
                  _nlpCancelled = true;
                  _nlpResolvedDueAt = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '已识别截止时间：${_nlpResolvedDueAt!.toLocal()} ✕',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                // tooltip 进不了读屏标签（`child:` 与 `icon:` 两种写法实测都拿不到，
                // 后者在本仓的 PopupMenuButton + ensureSemantics 组合下仍为 0 命中），
                // 所以显式补一个语义节点，措辞与 tooltip 同源。
                Semantics(
                  label: '更多',
                  button: true,
                  container: true,
                  child: PopupMenuButton<String>(
                    key: const Key('todo-quick-add-more'),
                    tooltip: '更多',
                    onSelected: (value) {
                      if (value == 'template') _addFromTemplate();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'template', child: Text('模板')),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  key: const Key('todo-quick-add-feedback'),
                  _feedback!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 优先级辅助：把 0/1/2/3 翻译成 UI 文案 + 颜色。
String priorityLabel(int p) {
  switch (p) {
    case 3:
      return '高';
    case 2:
      return '中';
    case 1:
      return '低';
    default:
      return '无';
  }
}

Color priorityColor(int p) {
  switch (p) {
    case 3:
      return Colors.red;
    case 2:
      return Colors.orange;
    case 1:
      return Colors.green;
    default:
      return Colors.grey;
  }
}

/// 工具函数：把 hex 字符串标签颜色包装成可用 Color（re-export）。
Color tagColorFromHex(String? hex) => parseHexColor(hex);

/// 快速添加弹窗「模板」项打开的本地模板选择层。
class _QuickAddTemplatePicker extends StatelessWidget {
  const _QuickAddTemplatePicker({
    required this.templates,
    required this.onPick,
  });

  final TemplateRepository templates;
  final void Function(TodoTemplate template) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        key: const Key('todo-quick-add-template-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: StreamBuilder<List<TodoTemplate>>(
          stream: templates.watchAll(),
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <TodoTemplate>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('模板', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (list.isEmpty) const Text('暂无本地模板'),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final template in list)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      template.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      template.status == 'synced'
                                          ? '已同步'
                                          : '等待同步',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => onPick(template),
                                child: const Text('添加'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// FL #344 面①：快速添加底部功能栏（产品裁决：日期→优先级→标签→清单，可调序）。
///
/// 渲染**从配置读**（`QuickAddActionBarSetting`，读不到=默认序）——
/// 顺序表由 state 传入，本类只按序摆放。chip 语义：
/// - tap = 打开弹层；**长按日期 = 清除**（与桌面底栏逐字对齐，opencode）；
/// - 优先级 chip 显示**生效档**（用户看到的 == 将要保存的，无"未选"态）；
/// - 有手选值时高亮（用户最后的动作最大 —— 手选压着 NLP 识别）。
class _QuickAddActionBar extends StatelessWidget {
  const _QuickAddActionBar({
    required this.order,
    required this.effectivePriority,
    required this.hasManualDate,
    required this.hasManualTags,
    required this.hasManualList,
    required this.manualListId,
    required this.onTapDate,
    required this.onLongPressDate,
    required this.onTapPriority,
    required this.onTapTag,
    required this.onTapList,
    required this.onTapEditOrder,
  });

  final List<String> order;
  final int effectivePriority;
  final bool hasManualDate;
  final bool hasManualTags;
  final bool hasManualList;
  final String manualListId;
  final VoidCallback onTapDate;
  final VoidCallback onLongPressDate;
  final VoidCallback onTapPriority;
  final VoidCallback onTapTag;
  final VoidCallback onTapList;

  /// FL #344 第二步：` :24`「点击「...」-「设置」，快速设置你的常用功能」。
  final VoidCallback onTapEditOrder;

  @override
  Widget build(BuildContext context) {
    Widget chipFor(String id) {
      switch (id) {
        case 'date':
          return _BarChip(
            key: const Key('todo-quick-add-bar-date'),
            icon: Icons.event_outlined,
            label: hasManualDate ? '已选日期' : '日期',
            highlighted: hasManualDate,
            onTap: onTapDate,
            onLongPress: onLongPressDate,
          );
        case 'priority':
          return _BarChip(
            key: const Key('todo-quick-add-bar-priority'),
            icon: Icons.flag_outlined,
            label: priorityLabel(effectivePriority),
            highlighted: effectivePriority > 0,
            onTap: onTapPriority,
          );
        case 'tag':
          return _BarChip(
            key: const Key('todo-quick-add-bar-tag'),
            icon: Icons.sell_outlined,
            label: hasManualTags ? '已选标签' : '标签',
            highlighted: hasManualTags,
            onTap: onTapTag,
          );
        case 'list':
          return _BarChip(
            key: const Key('todo-quick-add-bar-list'),
            icon: Icons.list_alt_outlined,
            label: '清单',
            highlighted: hasManualList,
            onTap: onTapList,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (final id in order) ...[Expanded(child: chipFor(id))],
          // 「...」编辑入口（:24 原文）。 Expanded 均分之外的固定宽小按钮。
          _BarChip(
            key: const Key('todo-quick-add-bar-edit-order'),
            icon: Icons.more_horiz,
            label: '…',
            highlighted: false,
            onTap: onTapEditOrder,
          ),
        ],
      ),
    );
  }
}

/// 底栏单个功能位（图标 + 短文案；高亮 = 有手选值）。
class _BarChip extends StatelessWidget {
  const _BarChip({
    super.key,
    required this.icon,
    required this.label,
    required this.highlighted,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
