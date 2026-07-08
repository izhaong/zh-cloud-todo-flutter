import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';

/// ICS 订阅状态容器。
@immutable
class CalSubState {
  const CalSubState({
    required this.loading,
    required this.items,
    this.error,
  });

  final bool loading;
  final List<CalSubscription> items;
  final String? error;
}

/// 拉取当前用户的 ICS 订阅列表。
final calSubscriptionProvider =
    FutureProvider.autoDispose<CalSubState>((ref) async {
  final api = ref.watch(todoApiProvider).calSubscription;
  try {
    final list = await api.list();
    return CalSubState(loading: false, items: list);
  } catch (e) {
    return CalSubState(
      loading: false,
      items: const [],
      error: e.toString(),
    );
  }
});

/// ICS 订阅管理页：
/// - 订阅：POST /cal-sub/create (url, name, enabled)
/// - 删除：POST /cal-sub/delete (id)
/// - 列表：GET /cal-sub/list
/// - 导出 own ICS feed：GET /cal-sub/export-ics（后端入口，预留）
class CalendarSubscriptionPage extends ConsumerStatefulWidget {
  const CalendarSubscriptionPage({super.key});

  @override
  ConsumerState<CalendarSubscriptionPage> createState() =>
      _CalendarSubscriptionPageState();
}

class _CalendarSubscriptionPageState
    extends ConsumerState<CalendarSubscriptionPage> {
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _add() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || Uri.tryParse(url)?.isAbsolute != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入合法的 URL（含 http:// 等）')),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    _urlCtrl.clear();
    _nameCtrl.clear();
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(todoApiProvider).calSubscription.create(
            url: url,
            name: name.isEmpty ? null : name,
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已添加订阅')));
      ref.invalidate(calSubscriptionProvider);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('订阅失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(CalSubscription s) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(todoApiProvider).calSubscription.delete(s.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已移除订阅')));
      ref.invalidate(calSubscriptionProvider);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calSubscriptionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历订阅'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(calSubscriptionProvider),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (s) => _content(s),
      ),
    );
  }

  Widget _content(CalSubState s) {
    if (s.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: ${s.error}'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => ref.invalidate(calSubscriptionProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '订阅 ICS 日历',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ICS URL',
                    hintText: 'https://example.com/cal.ics',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '备注名（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add_link),
                  label: const Text('添加订阅'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '已订阅（${s.items.length}）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _exportOwnFeed(context),
              icon: const Icon(Icons.ios_share),
              label: const Text('导出我的 ICS'),
            ),
          ],
        ),
        if (s.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('暂无 ICS 订阅')),
          )
        else
          ...s.items.map((it) => Card(
                child: ListTile(
                  leading: Icon(
                    it.enabled
                        ? Icons.event_available
                        : Icons.event_busy,
                  ),
                  title: Text(it.name),
                  subtitle: Text(
                    '${it.url}${it.lastSyncAt != null ? '\n同步于 ${it.lastSyncAt!.toLocal().toString().substring(0, 16)}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: it.lastSyncAt != null,
                  trailing: IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(it),
                  ),
                ),
              )),
      ],
    );
  }

  // 导出自己的 ICS 入口：后端约定 GET /cal-sub/export-ics 返回
  // `{feedUrl}` 或用户专属 token；真实分享可在本方法中调用 Link.share /
  // Clipboard.setData，目前仅作为入口示意。
  Future<void> _exportOwnFeed(BuildContext context) async {
    const snackBar = SnackBar(
      content: Text(
        '导出自己的 ICS 链接：GET /cal-sub/export-ics（由后端生成）',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
