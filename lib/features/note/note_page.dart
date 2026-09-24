import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import 'task_summary_sheet.dart';

class NotePage extends ConsumerStatefulWidget {
  const NotePage({super.key});

  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  List<TodoNoteItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await ref.read(noteRepositoryProvider).list();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([TodoNoteItem? note]) async {
    final draft = await showDialog<_NoteDraft>(
      context: context,
      builder: (dialogContext) => _NoteEditorDialog(note: note),
    );
    if (draft == null || !mounted) return;
    final repository = ref.read(noteRepositoryProvider);
    try {
      if (note == null) {
        await repository.create(title: draft.title, content: draft.content);
      } else {
        await repository.update(
          id: note.id,
          title: draft.title,
          content: draft.content,
          sortOrder: note.sortOrder,
        );
      }
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }

  Future<void> _archive(TodoNoteItem note) async {
    try {
      await ref.read(noteRepositoryProvider).archive(note.id, archived: true);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('归档失败：$error')));
      }
    }
  }

  Future<void> _delete(TodoNoteItem note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确认删除“${note.title}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(noteRepositoryProvider).delete(note.id);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
    }
  }

  void _preview(TodoNoteItem note) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(note.title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: note.content.isEmpty ? '暂无内容' : note.content,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            tooltip: '刷新笔记',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('todo-note-add'),
        onPressed: _edit,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('新建笔记'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败：$_error'),
            const SizedBox(height: 8),
            FilledButton(onPressed: _reload, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无笔记，记录灵感、复盘与工作资料吧。'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final note = _items[index];
        return Card(
          child: ListTile(
            key: ValueKey('todo-note-${note.id}'),
            leading: const Icon(Icons.description_outlined),
            title: Text(note.title),
            subtitle: Text(
              note.content.isEmpty ? '暂无内容' : note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _preview(note),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                switch (action) {
                  case 'edit':
                    await _edit(note);
                    return;
                  case 'archive':
                    await _archive(note);
                    return;
                  case 'delete':
                    await _delete(note);
                    return;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'archive', child: Text('归档')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NoteDraft {
  const _NoteDraft({required this.title, required this.content});

  final String title;
  final String content;
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({this.note});

  final TodoNoteItem? note;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title);
    _content = TextEditingController(text: widget.note?.content);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, _NoteDraft(title: title, content: _content.text));
  }

  /// 嘀嗒的摘要只从笔记插入；确认后写进光标处，光标无效时追加到末尾。
  Future<void> _insertSummary() async {
    final summary = await showNoteTaskSummarySheet(context);
    if (summary == null || !mounted) return;
    final value = _content.value;
    final caret = value.selection.isValid
        ? value.selection.start.clamp(0, value.text.length)
        : value.text.length;
    final before = value.text.substring(0, caret);
    final after = value.text.substring(caret);
    final joined =
        '${before.isEmpty || before.endsWith('\n') ? before : '$before\n'}'
        '$summary'
        '${after.isEmpty || after.startsWith('\n') ? after : '\n$after'}';
    _content.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: joined.length - after.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('todo-note-title'),
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('todo-note-insert-summary'),
                  onPressed: _insertSummary,
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text('插入摘要'),
                ),
              ),
              TextField(
                key: const Key('todo-note-content'),
                controller: _content,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: '内容（支持 Markdown）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('todo-note-save'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
