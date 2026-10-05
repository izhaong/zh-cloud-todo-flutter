import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

/// 批量「设置标签」的弹窗本体。
///
/// 单独成 Widget 是为了能直接写判据：长在页面私有方法里时，「零标签时只弹一句提示、
/// 不给建」这种入口缺失没法在 widget 层被量到（FL #493）。
/// 表内给一行「新建标签」：先按名字命中已有标签，没有才建，避免同名长出两条。
class BatchTagPickerSheet extends StatefulWidget {
  const BatchTagPickerSheet({
    super.key,
    required this.tags,
    required this.onCreate,
  });

  final List<TodoTag> tags;
  final Future<TodoTag> Function(String name) onCreate;

  static Future<List<String>?> show(
    BuildContext context, {
    required List<TodoTag> tags,
    required Future<TodoTag> Function(String name) onCreate,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (_) => BatchTagPickerSheet(tags: tags, onCreate: onCreate),
    );
  }

  @override
  State<BatchTagPickerSheet> createState() => _BatchTagPickerSheetState();
}

class _BatchTagPickerSheetState extends State<BatchTagPickerSheet> {
  final _controller = TextEditingController();
  late final List<TodoTag> _available = [...widget.tags];
  final Set<String> _selected = <String>{};
  String? _error;
  var _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '先输入标签名');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final existing = _available.where((tag) => tag.name == name);
      final tag = existing.isNotEmpty ? existing.first : await widget.onCreate(name);
      if (!mounted) return;
      setState(() {
        if (!_available.any((item) => item.id == tag.id)) _available.add(tag);
        _selected.add(tag.id);
        _controller.clear();
        _error = null;
        _creating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '建标签没成功，请稍后再试';
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '设置标签',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('todo-batch-new-tag-input'),
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: '新建标签',
                        isDense: true,
                        errorText: _error,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('todo-batch-create-tag'),
                    onPressed: _creating ? null : _create,
                    child: const Text('添加'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _available.isEmpty
                  ? const Center(
                      child: Text('还没有标签，用上面一行建一个'),
                    )
                  : ListView(
                      children: [
                        for (final tag in _available)
                          CheckboxListTile(
                            key: Key('todo-batch-tag-${tag.id}'),
                            title: Text(tag.name),
                            value: _selected.contains(tag.id),
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                _selected.add(tag.id);
                              } else {
                                _selected.remove(tag.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('todo-batch-apply-tags'),
                  onPressed: () => Navigator.of(context).pop(
                    _selected.toList(growable: false),
                  ),
                  child: const Text('应用标签'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
