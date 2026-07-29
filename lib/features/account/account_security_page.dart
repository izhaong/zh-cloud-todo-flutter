import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';
import 'change_password_page.dart';

/// 账户安全页：修改密码 + 2FA 双重验证 + 数据导出。
///
/// service 契约：
/// - `GET /security/2fa/status` → bool（当前 2FA 是否开启）
/// - `POST /security/2fa/setup` → TOTP 密钥与 otpauth URI
/// - `POST /security/2fa/confirm?code=...` → Boolean
/// - `POST /security/2fa/disable?code=...` → Boolean
/// - `POST /security/export?exportType=FULL` → Long（导出任务 ID）
/// - `GET /security/export/list` → `List<DataExportItem>`
/// - `GET /security/export/{id}/download` → 鉴权 JSON 文件
typedef DataExportSaver = Future<bool> Function(DataExportDownload file);

Future<bool> saveDataExport(DataExportDownload file) async {
  final savedPath = await FilePicker.saveFile(
    dialogTitle: '保存 Todo 数据导出',
    fileName: file.filename,
    type: FileType.custom,
    allowedExtensions: const ['json'],
    bytes: file.bytes,
  );
  // Web 的下载由浏览器接管，插件按契约始终返回 null。
  return kIsWeb || savedPath != null;
}

class AccountSecurityPage extends ConsumerWidget {
  const AccountSecurityPage({super.key, this.exportSaver = saveDataExport});

  final DataExportSaver exportSaver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(todoApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账户安全')),
      body: _Body(api: api, exportSaver: exportSaver),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.api, required this.exportSaver});

  final TodoRestApi api;
  final DataExportSaver exportSaver;

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
        _ExportCard(api: api, exportSaver: exportSaver),
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
        final setup = await widget.api.security.setupTwoFactor();
        if (!mounted) return;
        final code = await _requestCode(
          title: '绑定认证器',
          description: '请在认证器中添加下方密钥，再输入当前显示的 6 位动态码完成启用。',
          setup: setup,
        );
        if (code == null) return;
        final confirmed = await widget.api.security.confirmTwoFactor(code);
        if (!confirmed) {
          throw Exception('动态码校验失败，请确认设备时间后重试');
        }
      } else {
        final code = await _requestCode(
          title: '关闭双重验证',
          description: '请输入认证器当前显示的 6 位动态码，以确认由你本人关闭。',
        );
        if (code == null) return;
        await widget.api.security.disableTwoFactor(code);
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

  Future<String?> _requestCode({
    required String title,
    required String description,
    TwoFactorSetup? setup,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _TwoFactorCodeDialog(
      title: title,
      description: description,
      setup: setup,
    ),
  );

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
                  Switch(
                    key: const ValueKey('account-security-two-factor-switch'),
                    value: enabled,
                    onChanged: _toggle,
                  ),
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

class _TwoFactorCodeDialog extends StatefulWidget {
  const _TwoFactorCodeDialog({
    required this.title,
    required this.description,
    this.setup,
  });

  final String title;
  final String description;
  final TwoFactorSetup? setup;

  @override
  State<_TwoFactorCodeDialog> createState() => _TwoFactorCodeDialogState();
}

class _TwoFactorCodeDialogState extends State<_TwoFactorCodeDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final code = _controller.text.trim();
    if (RegExp(r'^\d{6}$').hasMatch(code)) {
      Navigator.of(context).pop(code);
    } else {
      setState(() => _errorText = '请输入 6 位动态码');
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            if (setup != null) ...[
              const SizedBox(height: 16),
              Text('手工密钥', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                setup.secret,
                key: const ValueKey('two-factor-setup-secret'),
              ),
              const SizedBox(height: 12),
              Text(
                'otpauth URI',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(
                setup.otpauthUri,
                key: const ValueKey('two-factor-setup-uri'),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('two-factor-code-input'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '6 位动态码',
                errorText: _errorText,
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('two-factor-code-confirm'),
          onPressed: _confirm,
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _ExportCard extends ConsumerStatefulWidget {
  const _ExportCard({required this.api, required this.exportSaver});

  final TodoRestApi api;
  final DataExportSaver exportSaver;

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
        ).showSnackBar(const SnackBar(content: Text('导出已生成，可立即下载')));
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

  Future<void> _download(DataExportItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await widget.api.security.downloadExport(item.id);
      final saved = await widget.exportSaver(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(saved ? '已保存 ${file.filename}' : '已取消保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败：$e')));
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
                  trailing: e.status == 'READY'
                      ? IconButton(
                          key: ValueKey(
                            'account-security-export-download-${e.id}',
                          ),
                          tooltip: '下载导出文件',
                          icon: const Icon(Icons.download),
                          onPressed: _busy ? null : () => _download(e),
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
