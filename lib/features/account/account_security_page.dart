import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';
import 'change_password_page.dart';

/// 账户安全页：修改密码 + 2FA 双重验证 + 数据导出。
///
/// service 契约：
/// - `GET /security/2fa/status` → bool（当前 2FA 是否开启）
/// - `POST /security/2fa/enable` → Long（2FA 记录 ID）
/// - `POST /security/2fa/disable` → Boolean
/// - `POST /security/export?exportType=FULL` → Long（导出任务 ID）
/// - `GET /security/export/list` → `List<DataExportItem>`
class AccountSecurityPage extends ConsumerWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(todoApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账户安全')),
      body: _Body(api: api),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.api});

  final TodoRestApi api;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SignedInAs(mobile: session?.mobile ?? ''),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            key: const ValueKey('account-security-change-password'),
            leading: const Icon(Icons.password_outlined),
            title: const Text('修改密码'),
            subtitle: const Text('短信验证后设置新的登录密码'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TwoFactorCard(api: api),
        const SizedBox(height: 16),
        _ExportCard(api: api),
      ],
    );
  }
}

class _SignedInAs extends StatelessWidget {
  const _SignedInAs({required this.mobile});

  final String mobile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: const Text('已登录账号'),
        subtitle: Text(mobile.isEmpty ? '—' : mobile),
      ),
    );
  }
}

class _TwoFactorCard extends ConsumerStatefulWidget {
  const _TwoFactorCard({required this.api});

  final TodoRestApi api;

  @override
  ConsumerState<_TwoFactorCard> createState() => _TwoFactorCardState();
}

class _TwoFactorCardState extends ConsumerState<_TwoFactorCard> {
  bool? _enabled; // null = 加载中
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await widget.api.security.isTwoFactorEnabled();
      if (mounted) setState(() => _enabled = v);
    } catch (_) {
      // 接口不可用时视为 false，不阻塞页面。
      if (mounted) setState(() => _enabled = false);
    }
  }

  Future<void> _toggle(bool target) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (target) {
        await widget.api.security.enableTwoFactor();
      } else {
        await widget.api.security.disableTwoFactor();
      }
      if (mounted) setState(() => _enabled = target);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(target ? '已开启双重验证' : '已关闭双重验证')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 8),
                Text(
                  '双重验证（2FA）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_busy || _enabled == null)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(value: enabled, onChanged: _toggle),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              enabled ? '已开启：登录时需要额外的动态验证码，账号更安全。' : '未开启：建议开启双重验证以保护账号。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportCard extends ConsumerStatefulWidget {
  const _ExportCard({required this.api});

  final TodoRestApi api;

  @override
  ConsumerState<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends ConsumerState<_ExportCard> {
  bool _busy = false;
  List<DataExportItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.security.listExports();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // 接口不可用时展示空列表。
      if (mounted) setState(() => _items = const []);
    }
  }

  Future<void> _requestExport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.security.requestExport(exportType: 'FULL');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已提交导出请求，请稍后回来下载')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_outlined),
                const SizedBox(width: 8),
                Text('数据导出', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _requestExport,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('导出全部数据'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Text('暂无导出记录', style: Theme.of(context).textTheme.bodyMedium)
            else
              ..._items.map(
                (e) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text('${e.exportType} · ${e.status}'),
                  trailing: e.exportUrl.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('下载：${e.exportUrl}')),
                            );
                          },
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
