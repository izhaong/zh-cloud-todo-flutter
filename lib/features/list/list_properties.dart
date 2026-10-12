import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/attachment_upload_api.dart';
import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'list_color.dart';

/// 清单「Emoji 图标 + 背景」的取值与 UI（specs/105 / FL #339、#340）。
///
/// 嘀嗒《02-用清单管理任务.md》：
/// - :86「在清单编辑页面，点击名称前面的「图标」，选择需要的 Emoji 表情」
/// - :87「清单名称最前面输入 Emoji 表情，可自动设置为清单的图标」
/// - :103-:111 背景四样式：跟随应用主题 / 颜色背景 / 渐变背景 / 图片背景
/// - :118「已完成」「已放弃」「垃圾桶」不支持设置背景（本端智能清单一律拒绝）
///
/// 背景入口的形态偏差：嘀嗒在移动端清单详情页「…-背景」，本端在侧栏清单
/// 动作表（长按/左滑）里加「背景」，覆盖同一个设置面。

/// Emoji 候选集：常用表情的固定清单，取值本端裁定（嘀嗒未公开面板内容）。
const kListEmojiChoices = [
  '📌',
  '🎯',
  '🏠',
  '💼',
  '📚',
  '🏃',
  '🍎',
  '☕',
  '✈️',
  '🎵',
  '💡',
  '🛒',
  '❤️',
  '⭐',
  '🔥',
  '🌈',
  '🐱',
  '🌸',
  '⚡',
  '🎁',
  '🕐',
  '📝',
  '🎬',
  '🏔️',
];

/// 方式二：名称最前面是 Emoji 时自动设为图标。按首 rune 判定，
/// 覆盖常见符号区与补充符号区；中文/字母/数字都不算。
final _leadingEmojiPattern = RegExp(
  '[\\u{1F000}-\\u{1FAFF}\\u{2600}-\\u{27BF}\\u{2B00}-\\u{2BFF}]',
  unicode: true,
);

String? detectLeadingEmoji(String name) {
  if (name.isEmpty) return null;
  final first = String.fromCharCode(name.runes.first);
  return _leadingEmojiPattern.hasMatch(first) ? first : null;
}

/// 渐变背景的预设对（取值本端裁定），value 存 `hex1,hex2`。
const kListGradientPresets = [
  '#FF9A9E,#FAD0C4',
  '#A1C4FD,#C2E9FB',
  '#FBC2EB,#A6C1EE',
  '#84FAB0,#8FD3F4',
];

(bool, Color?, Color?) parseGradientValue(String? value) {
  if (value == null) return (false, null, null);
  final parts = value.split(',');
  if (parts.length != 2) return (false, null, null);
  final start = listColorFromHex(parts[0].trim());
  final end = listColorFromHex(parts[1].trim());
  return (start != null && end != null, start, end);
}

/// 清单详情页的背景装饰；theme（或无效值）回 null 即不做任何装饰。
Decoration? listBackgroundDecoration(TodoList? list) {
  final type = list?.backgroundType ?? 'theme';
  final value = list?.backgroundValue;
  switch (type) {
    case 'color':
      final color = listColorFromHex(value);
      return color == null ? null : BoxDecoration(color: color);
    case 'gradient':
      final (ok, start, end) = parseGradientValue(value);
      if (!ok) return null;
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [start!, end!],
        ),
      );
    case 'image':
      final url = value;
      if (url == null || url.isEmpty) return null;
      return BoxDecoration(
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      );
    default:
      return null;
  }
}

/// 背景设置弹层：四样式单选 + 保存。
class ListBackgroundSheet extends ConsumerStatefulWidget {
  const ListBackgroundSheet({
    super.key,
    required this.list,
    this.pickImage,
    this.uploadImage,
  });

  final TodoList list;

  /// 图片档的选图与上传通道（测试注入用；不传走相册选择 + 文件服务上传）。
  final Future<String?> Function()? pickImage;
  final Future<String> Function(String localPath, String name)? uploadImage;

  static Future<void> show(BuildContext context, TodoList list) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ListBackgroundSheet(list: list),
    );
  }

  @override
  ConsumerState<ListBackgroundSheet> createState() =>
      _ListBackgroundSheetState();
}

class _ListBackgroundSheetState extends ConsumerState<ListBackgroundSheet> {
  late String _type;
  String? _color;
  late String _gradient;
  late TextEditingController _imageUrl;
  String? _error;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.list.backgroundType;
    _color = _type == 'color' ? widget.list.backgroundValue : null;
    _gradient = _type == 'gradient'
        ? (widget.list.backgroundValue ?? kListGradientPresets.first)
        : kListGradientPresets.first;
    _imageUrl = TextEditingController(
      text: _type == 'image' ? (widget.list.backgroundValue ?? '') : '',
    );
  }

  @override
  void dispose() {
    _imageUrl.dispose();
    super.dispose();
  }

  /// 相册选图 → 上传拿 URL → 填回「图片地址」那一格（保存仍走 `setBackground`）。
  Future<void> _pickAndUpload() async {
    final pick =
        widget.pickImage ??
        () async {
          final result = await FilePicker.pickFiles(type: FileType.image);
          if (result == null || result.files.isEmpty) return null;
          return result.files.first.path;
        };
    setState(() {
      _uploading = true;
      _error = null;
    });
    String? localPath;
    try {
      localPath = await pick();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = '没能选好图片：${describeError(e)}，背景还是原来的';
      });
      return;
    }
    if (localPath == null || localPath.isEmpty) {
      if (!mounted) return;
      setState(() => _uploading = false);
      return;
    }
    final name = localPath.split('/').last;
    final upload =
        widget.uploadImage ??
        (path, fileName) => DioAttachmentUploadApi(
          ref.read(apiClientProvider),
        ).uploadFile(localPath: path, name: fileName);
    try {
      final url = await upload(localPath, name);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _imageUrl.text = url;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = '图片上传失败：${describeError(e)}，可以先粘别的地址或切回其它背景';
      });
    }
  }

  Future<void> _save() async {
    final repo = ref.read(listRepositoryProvider);
    if (repo == null) {
      setState(() => _error = '本地数据库尚未就绪，背景没能保存');
      return;
    }
    final value = switch (_type) {
      'color' => _color,
      'gradient' => _gradient,
      'image' => _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      _ => null,
    };
    if (_type == 'color' && value == null) {
      setState(() => _error = '先选一个颜色，或切回跟随应用主题');
      return;
    }
    setState(() => _error = null);
    try {
      await repo.setBackground(widget.list.id, _type, value);
    } on Object catch (e) {
      setState(() => _error = '保存失败：${describeError(e)}');
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('背景', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _type,
              onChanged: (v) => setState(() {
                _type = v!;
                _error = null;
              }),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RadioListTile<String>(
                    key: const Key('todo-list-background-theme'),
                    value: 'theme',
                    title: const Text('跟随应用主题'),
                  ),
                  RadioListTile<String>(
                    key: const Key('todo-list-background-color'),
                    value: 'color',
                    title: const Text('颜色背景'),
                  ),
                  if (_type == 'color')
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final hex in kListColorChoices)
                            _BackgroundSwatch(
                              key: Key(
                                'todo-list-background-color-'
                                '${hex.substring(1).toLowerCase()}',
                              ),
                              color: listColorFromHex(hex)!,
                              selected: _color == hex,
                              onTap: () => setState(() => _color = hex),
                            ),
                        ],
                      ),
                    ),
                  RadioListTile<String>(
                    key: const Key('todo-list-background-gradient'),
                    value: 'gradient',
                    title: const Text('渐变背景'),
                  ),
                  if (_type == 'gradient')
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in kListGradientPresets)
                            _BackgroundSwatch(
                              key: Key(
                                'todo-list-background-gradient-'
                                '${preset.split(',').first.substring(1).toLowerCase()}',
                              ),
                              gradient: parseGradientValue(preset),
                              selected: _gradient == preset,
                              onTap: () => setState(() => _gradient = preset),
                            ),
                        ],
                      ),
                    ),
                  RadioListTile<String>(
                    key: const Key('todo-list-background-image'),
                    value: 'image',
                    title: const Text('图片背景'),
                  ),
                ],
              ),
            ),
            if (_type == 'image')
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('todo-list-background-image-url'),
                      controller: _imageUrl,
                      decoration: const InputDecoration(
                        labelText: '图片地址',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 嘀嗒《02-用清单管理任务》:111 的图片档给的是相册选图，不是让用户
                    // 手贴地址 ⇒ 选完上传拿到 URL 再填回同一格，保存路径不变。
                    OutlinedButton.icon(
                      key: const Key('todo-list-background-pick-image'),
                      onPressed: _uploading ? null : _pickAndUpload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(_uploading ? '上传中…' : '从相册选择'),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('todo-list-background-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('todo-list-background-save'),
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({
    super.key,
    this.color,
    this.gradient,
    required this.selected,
    required this.onTap,
  }) : assert((color == null) != (gradient == null), '色块要么纯色要么渐变');

  final Color? color;
  final (bool, Color?, Color?)? gradient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (gOk, gStart, gEnd) = gradient ?? (false, null, null);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          gradient: gOk ? LinearGradient(colors: [gStart!, gEnd!]) : null,
          shape: BoxShape.circle,
          border: color == null && !gOk
              ? Border.all(color: theme.dividerColor)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 20, color: Colors.white)
            : null,
      ),
    );
  }
}
