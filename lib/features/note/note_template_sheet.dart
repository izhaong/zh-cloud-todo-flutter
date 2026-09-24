import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';

/// 嘀嗒《03-特色功能/11-笔记与摘要》「用模板高效记笔记」：
/// 进笔记详情页点「使用模板」，选中任意一个即把内容加进笔记。返回用户选中的模板正文。
Future<String?> showNoteTemplateSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.82,
      child: const NoteTemplateSheet(),
    ),
  );
}

class NoteTemplateSheet extends ConsumerStatefulWidget {
  const NoteTemplateSheet({super.key});

  @override
  ConsumerState<NoteTemplateSheet> createState() => _NoteTemplateSheetState();
}

class _NoteTemplateSheetState extends ConsumerState<NoteTemplateSheet> {
  List<NoteTemplateDto> _templates = const [];
  bool _loading = true;
  String? _error;

  /// 「新的先到、旧的后到」时，旧响应不许覆盖新结果。
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final api = ref.read(todoApiProvider).templates;
      final results = await Future.wait([api.listMy(), api.listPublic()]);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _templates = <NoteTemplateDto>[...results[0], ...results[1]];
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      // 失败保留已加载列表：清成空态会让人以为模板被删了。
      setState(() {
        _error = '模板加载失败：$error';
        _loading = false;
      });
    }
  }

  void _choose(NoteTemplateDto template) =>
      Navigator.of(context).pop(template.content);

  List<Widget> _group(String title, List<NoteTemplateDto> items) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      for (final item in items)
        ListTile(
          key: ValueKey('note-template-${item.id}'),
          title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _choose(item),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mine = _templates.where((item) => !item.isPublic).toList();
    final presets = _templates.where((item) => item.isPublic).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('使用模板', style: TextStyle(fontSize: 18)),
              ),
              IconButton(
                key: const Key('note-template-reload'),
                tooltip: '重新加载模板',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        if (_loading && _templates.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_templates.isEmpty && !_loading)
          const Expanded(
            child: Center(child: Text('还没有可用模板，可在任务详情里「保存当前任务为模板」')),
          )
        else
          Expanded(
            child: ListView(
              children: [..._group('我的模板', mine), ..._group('预设模板', presets)],
            ),
          ),
      ],
    );
  }
}
