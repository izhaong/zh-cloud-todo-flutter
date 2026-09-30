import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/nlp_date.dart';
import '../../state/providers.dart';
import '../../state/repositories/template_repository.dart';
import '../tag/tag_color.dart';

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
  int? _priorityOverride;
  DateTime? _nlpResolvedDueAt;

  /// 「任务已建、提醒没建成」时记住任务 id：再点一次「保存」只补提醒，不建第二遍任务。
  String? _savedTaskId;
  bool _applyingTemplate = false;
  bool _saving = false;
  String? _feedback;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_maybeResolveDate);
  }

  @override
  void dispose() {
    _titleCtrl
      ..removeListener(_maybeResolveDate)
      ..dispose();
    super.dispose();
  }

  void _maybeResolveDate() {
    if (_titleError != null && _titleCtrl.text.trim().isNotEmpty) {
      setState(() => _titleError = null);
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
    if (_savedTaskId == null) {
      final text = _titleCtrl.text.trim();
      if (text.isEmpty) {
        setState(() => _titleError = '请输入任务标题');
        return;
      }
      try {
        final defaults = await ref
            .read(taskCaptureDefaultsRepositoryProvider)
            ?.get();
        final task = await repo.create(
          listId: widget.listId,
          parentTaskId: widget.parentTaskId,
          sectionId: widget.sectionId,
          title: text,
          priority: _priorityOverride ?? defaults?.defaultPriority ?? 0,
          dueAt: dueAt,
        );
        _savedTaskId = task.id;
      } on StateError catch (error) {
        _report(error.message.toString());
        return;
      } catch (_) {
        _report('保存任务失败，请稍后重试');
        return;
      }
    }
    if (dueAt == null) {
      if (mounted) Navigator.pop(context);
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
      await reminders.create(taskId: _savedTaskId!, fireAt: dueAt);
      if (mounted) Navigator.pop(context);
    } on StateError catch (error) {
      _report('任务已建，但提醒没建成：${error.message}');
    } catch (_) {
      _report('任务已建，但提醒没建成，请稍后在任务里添加提醒');
    }
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
              controller: _titleCtrl,
              autofocus: true,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '已识别截止时间：${_nlpResolvedDueAt!.toLocal()}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
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
