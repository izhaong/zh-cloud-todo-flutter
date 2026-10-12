import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/error_text.dart';
import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';

typedef TaskImportFilePicker = Future<PortableTaskImportFile?> Function();

class TaskImportTarget {
  const TaskImportTarget({required this.id, required this.name});

  final int id;
  final String name;
}

class PortableTaskImportFile {
  const PortableTaskImportFile({
    required this.name,
    required this.source,
    required this.tasks,
    required this.skippedCount,
  });

  factory PortableTaskImportFile.parse({
    required String name,
    required Uint8List bytes,
  }) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const FormatException('文件不是有效的 UTF-8 JSON');
    }
    if (decoded is! Map) {
      throw const FormatException('JSON 根节点必须是对象');
    }
    final root = Map<String, dynamic>.from(decoded);
    final nestedData = root['data'];
    final isZhCloudExport = nestedData is Map && nestedData['tasks'] is List;
    final dynamic rawTasks = isZhCloudExport
        ? nestedData['tasks']
        : root['tasks'];
    if (rawTasks is! List) {
      throw const FormatException('JSON 中未找到 tasks 数组');
    }

    final tasks = <PortableTaskImportTask>[];
    var skippedCount = 0;
    for (var index = 0; index < rawTasks.length; index++) {
      final raw = rawTasks[index];
      if (raw is! Map) {
        skippedCount++;
        continue;
      }
      final item = Map<String, dynamic>.from(raw);
      final title = item['title']?.toString().trim() ?? '';
      if (title.isEmpty) {
        skippedCount++;
        continue;
      }
      if (title.length > 255) {
        throw FormatException('第 ${index + 1} 个任务标题超过 255 个字符');
      }
      final sourceTaskId = (item['sourceTaskId'] ?? item['id'])
          ?.toString()
          .trim();
      if (sourceTaskId != null && sourceTaskId.length > 128) {
        throw FormatException('第 ${index + 1} 个任务来源标识超过 128 个字符');
      }
      final rawPriority = item['priority'];
      final parsedPriority = rawPriority is num
          ? rawPriority.toInt()
          : int.tryParse(rawPriority?.toString() ?? '') ?? 0;
      final status = item['status']?.toString().toUpperCase();
      final completed =
          item['completed'] == true ||
          status == 'COMPLETED' ||
          status == 'DONE' ||
          item['completedAt'] != null ||
          item['completed_at'] != null;
      tasks.add(
        PortableTaskImportTask(
          sourceTaskId: sourceTaskId?.isEmpty == true ? null : sourceTaskId,
          title: title,
          description: (item['description'] ?? item['content'])?.toString(),
          dueAt: _parseDateTime(item['dueAt'] ?? item['due_at']),
          priority: parsedPriority.clamp(0, 3).toInt(),
          completed: completed,
        ),
      );
    }
    if (tasks.isEmpty) {
      throw const FormatException('文件中没有可导入的有效任务');
    }
    if (tasks.length > 500) {
      throw const FormatException('单次最多导入 500 个任务');
    }
    return PortableTaskImportFile(
      name: name,
      source: isZhCloudExport ? 'ZH_CLOUD_EXPORT' : 'PORTABLE_JSON',
      tasks: List.unmodifiable(tasks),
      skippedCount: skippedCount,
    );
  }

  final String name;
  final String source;
  final List<PortableTaskImportTask> tasks;
  final int skippedCount;

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

Future<PortableTaskImportFile?> pickPortableTaskImportFile() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: '选择 Todo JSON 导出文件',
    type: FileType.custom,
    allowedExtensions: const ['json'],
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.single;
  final bytes = picked.bytes;
  if (bytes == null) {
    throw const FormatException('无法读取所选文件');
  }
  return PortableTaskImportFile.parse(name: picked.name, bytes: bytes);
}

class TaskImportPage extends ConsumerStatefulWidget {
  const TaskImportPage({
    super.key,
    this.api,
    this.targets,
    this.filePicker = pickPortableTaskImportFile,
    this.afterMutation,
  });

  final TodoTaskImportApi? api;
  final List<TaskImportTarget>? targets;
  final TaskImportFilePicker filePicker;
  final Future<void> Function()? afterMutation;

  @override
  ConsumerState<TaskImportPage> createState() => _TaskImportPageState();
}

class _TaskImportPageState extends ConsumerState<TaskImportPage> {
  static const _uuid = Uuid();

  PortableTaskImportFile? _file;
  String? _requestId;
  int? _targetListId;
  List<TodoTaskImportBatch> _batches = const [];
  List<TaskImportTarget> _ownedTargets = const [];
  bool _loadingHistory = true;
  bool _loadingTargets = false;
  bool _busy = false;
  String? _historyError;
  String? _targetError;

  TodoTaskImportApi get _api =>
      widget.api ?? ref.read(todoApiProvider).taskImport;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBatches);
    if (widget.targets == null) {
      Future.microtask(_loadOwnedTargets);
    }
  }

  List<TaskImportTarget> _targets() {
    return widget.targets ?? _ownedTargets;
  }

  Future<void> _loadOwnedTargets() async {
    if (mounted) {
      setState(() {
        _loadingTargets = true;
        _targetError = null;
      });
    }
    final userId = ref.read(sessionProvider)?.userId;
    if (userId == null || userId <= 0) {
      if (mounted) {
        setState(() {
          _loadingTargets = false;
          _targetError = '登录状态无效，无法确认清单归属';
        });
      }
      return;
    }
    try {
      final lists = await ref.read(listsStreamProvider.future);
      final candidates = lists.where((list) => list.serverId != null).toList();
      final checks = await Future.wait(
        candidates.map((list) async {
          try {
            final owned = await ref
                .read(todoApiProvider)
                .listCollaboration
                .isOwner(listId: list.serverId!, userId: userId);
            return (
              target: TaskImportTarget(id: list.serverId!, name: list.name),
              owned: owned,
              failed: false,
            );
          } on Object {
            return (
              target: TaskImportTarget(id: list.serverId!, name: list.name),
              owned: false,
              failed: true,
            );
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _ownedTargets = checks
            .where((check) => check.owned)
            .map((check) => check.target)
            .toList(growable: false);
        _loadingTargets = false;
        _targetError = checks.any((check) => check.failed)
            ? '部分清单归属校验失败，已仅显示确认属于你的清单'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingTargets = false;
        _targetError = '清单归属校验失败：${describeError(error)}';
      });
    }
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await _api.listBatches();
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _loadingHistory = false;
        _historyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyError = '导入历史加载失败：${describeError(error)}';
      });
    }
  }

  Future<void> _pickFile() async {
    if (_busy) return;
    try {
      final file = await widget.filePicker();
      if (file == null || !mounted) return;
      setState(() {
        _file = file;
        _requestId = _uuid.v4();
      });
    } catch (error) {
      if (mounted) _message('文件解析失败：${describeError(error)}');
    }
  }

  int? _effectiveTargetId(List<TaskImportTarget> targets) {
    if (targets.any((target) => target.id == _targetListId)) {
      return _targetListId;
    }
    return targets.isEmpty ? null : targets.first.id;
  }

  Future<void> _submit() async {
    if (_busy || _file == null || _requestId == null) return;
    final targetId = _effectiveTargetId(_targets());
    if (targetId == null) {
      _message('请先创建并同步至少一个普通清单');
      return;
    }
    setState(() => _busy = true);
    try {
      final batch = await _api.importTasks(
        requestId: _requestId!,
        targetListId: targetId,
        tasks: _file!.tasks,
        source: _file!.source,
      );
      await _afterMutation();
      await _loadBatches();
      if (!mounted) return;
      _message(
        batch.idempotentReplay
            ? '该文件已导入，未重复创建任务'
            : '已导入 ${batch.importedCount} 个任务',
      );
    } on TodoTaskImportException catch (error) {
      if (mounted) {
        _message(
          error.code == TodoTaskImportApi.busyCode
              ? '相同导入请求正在处理中，请稍后重试'
              : '导入失败：${error.message}',
        );
      }
    } catch (error) {
      if (mounted) _message('导入失败：${describeError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rollback(TodoTaskImportBatch batch) async {
    if (_busy || batch.status == 'ROLLED_BACK') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('回滚本批导入？'),
        content: Text('将删除本批仍存在的 ${batch.importedCount} 个任务，其他任务不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: ValueKey('task-import-rollback-confirm-${batch.batchId}'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认回滚'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final rolledBack = await _api.rollback(batch.batchId);
      await _afterMutation();
      await _loadBatches();
      if (mounted) _message('已回滚 ${rolledBack.rolledBackCount} 个任务');
    } catch (error) {
      if (mounted) _message('回滚失败：${describeError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _afterMutation() async {
    try {
      if (widget.afterMutation != null) {
        await widget.afterMutation!();
      } else {
        await ref.read(syncCoordinatorProvider)?.syncOnce();
      }
    } on Object {
      // 服务端导入/回滚已成功；同步失败由既有重试机制继续处理。
    }
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets();
    final targetId = _effectiveTargetId(targets);
    final file = _file;
    return Scaffold(
      appBar: AppBar(title: const Text('任务导入')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '从 JSON 导入',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('支持本应用数据导出文件与包含根级 tasks 数组的便携 JSON；单次最多 500 个任务。'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const ValueKey('task-import-pick-file'),
                    onPressed: _busy ? null : _pickFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('选择 JSON 文件'),
                  ),
                  if (file != null) ...[
                    const SizedBox(height: 12),
                    Text(file.name),
                    Text('可导入 ${file.tasks.length} 个任务'),
                    if (file.skippedCount > 0)
                      Text('已忽略 ${file.skippedCount} 个空标题或无效项目'),
                  ],
                  const SizedBox(height: 16),
                  if (_loadingTargets) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('正在确认清单归属…'),
                    const SizedBox(height: 8),
                  ],
                  DropdownButtonFormField<int>(
                    key: ValueKey(targetId),
                    initialValue: targetId,
                    decoration: const InputDecoration(
                      labelText: '目标清单',
                      border: OutlineInputBorder(),
                    ),
                    items: targets
                        .map(
                          (target) => DropdownMenuItem(
                            value: target.id,
                            child: Text(target.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy || _loadingTargets
                        ? null
                        : (value) => setState(() => _targetListId = value),
                  ),
                  if (_targetError != null) ...[
                    const SizedBox(height: 8),
                    Text(_targetError!),
                    TextButton.icon(
                      onPressed: _loadingTargets ? null : _loadOwnedTargets,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新校验'),
                    ),
                  ],
                  if (!_loadingTargets && targets.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('暂无已确认属于你的同步清单，请先完成同步或检查协作角色。'),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('task-import-submit'),
                    onPressed: _busy || file == null || targetId == null
                        ? null
                        : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(_busy ? '处理中…' : '开始导入'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('导入历史', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loadingHistory ? null : _loadBatches,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_loadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_historyError != null)
            Text(_historyError!)
          else if (_batches.isEmpty)
            const Text('暂无导入记录')
          else
            ..._batches.map(
              (batch) => Card(
                child: ListTile(
                  title: Text(batch.status == 'ROLLED_BACK' ? '已回滚' : '已导入'),
                  subtitle: Text(
                    '导入 ${batch.importedCount} · 已回滚 ${batch.rolledBackCount}',
                  ),
                  trailing: batch.status == 'ROLLED_BACK'
                      ? const Icon(Icons.check_circle_outline)
                      : IconButton(
                          key: ValueKey(
                            'task-import-rollback-${batch.batchId}',
                          ),
                          tooltip: '回滚本批',
                          onPressed: _busy ? null : () => _rollback(batch),
                          icon: const Icon(Icons.undo),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
