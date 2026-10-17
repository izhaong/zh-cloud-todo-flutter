import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/settings/smart_date_recognition_setting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
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
    // 读总开关；读到之前按默认（开）——识别是既有行为，不能因为"还没读到"就停一屏。
    SmartDateRecognitionSetting().read().then((enabled) {
      if (mounted && enabled != _smartDateEnabled) {
        setState(() => _smartDateEnabled = enabled);
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
    final dueAt = _nlpResolvedDueAt;
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
          listId: widget.listId,
          parentTaskId: widget.parentTaskId,
          sectionId: widget.sectionId,
          title: text,
          priority: _priorityOverride ?? defaults?.defaultPriority ?? 0,
          dueAt: dueAt,
        );
        _savedTaskId = task.id;
        savedTitle = text;
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
              listId: widget.listId,
              parentTaskId: widget.parentTaskId,
              sectionId: widget.sectionId,
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
            DropdownButtonFormField<int>(
              key: ValueKey(priority),
              initialValue: priority,
              decoration: const InputDecoration(
                labelText: '优先级',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('无')),
                DropdownMenuItem(value: 1, child: Text('低')),
                DropdownMenuItem(value: 2, child: Text('中')),
                DropdownMenuItem(value: 3, child: Text('高')),
              ],
              onChanged: (v) => setState(() => _priorityOverride = v ?? 0),
            ),
            const SizedBox(height: 16),
            if (_nlpResolvedDueAt != null)
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
