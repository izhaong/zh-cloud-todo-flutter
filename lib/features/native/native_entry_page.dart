import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../native/native_intents.dart';

/// M11-B5 原生增强入口页：
/// - 桌面便签
/// - 快捷指令（URL Scheme）
/// - 系统分享
/// - 锁屏重要任务
/// - 桌面小组件数据预览
class NativeEntryPage extends StatefulWidget {
  const NativeEntryPage({super.key});

  @override
  State<NativeEntryPage> createState() => _NativeEntryPageState();
}

class _NativeEntryPageState extends State<NativeEntryPage> {
  final TextEditingController _noteCtl = TextEditingController(text: '今日重点：…');
  String _lastResult = '';

  @override
  void initState() {
    super.initState();
    _bootstrapUri();
  }

  Future<void> _bootstrapUri() async {
    final uri = await NativeIntents.handleIncomingUri();
    if (uri != null && mounted) {
      setState(() => _lastResult = 'URI 入参: $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('原生增强')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_lastResult.isNotEmpty) Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_lastResult),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle('桌面便签'),
          TextField(
            controller: _noteCtl,
            maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.sticky_note_2),
            label: const Text('写入桌面便签'),
            onPressed: () async {
              final ok = await NativeIntents.setStickyNote(_noteCtl.text);
              _toast(ok ? '已写入桌面便签' : '不支持当前平台');
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle('快捷指令 / URL Scheme'),
          const Text('zhcloudtodo://task/add?title=…&due=2026-06-20'),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.link),
            label: const Text('复制 Scheme'),
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: 'zhcloudtodo://task/add?title=…'),
              );
              _toast('已复制到剪贴板');
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle('系统分享'),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('分享今日任务列表'),
            onPressed: () async {
              final ok = await NativeIntents.shareText(
                '我的今日任务：…',
                subject: 'ZH-CLOUD Todo',
              );
              _toast(ok ? '已打开系统分享面板' : '分享失败');
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle('锁屏重要任务'),
          const Text('把勾选了"重要"的任务同步到锁屏小组件'),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.lock_outline),
            label: const Text('推送锁屏（演示 1/2/3）'),
            onPressed: () async {
              final ok = await NativeIntents.pushLockScreenTasks([1, 2, 3]);
              _toast(ok ? '已推送' : '不支持当前平台');
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle('桌面小组件数据预览'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: NativeIntents.widgetTodaySnapshot(),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('小组件暂未启用或无今日任务'),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .map((t) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.task_alt),
                          title: Text(t['title']?.toString() ?? ''),
                          subtitle: Text(t['dueAt']?.toString() ?? ''),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}