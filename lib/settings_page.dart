import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 打开设置页（由快捷键 `Actions` 派发）。
class OpenTodoSettingsIntent extends Intent {
  const OpenTodoSettingsIntent();
}

class TodoSettingsPage extends StatelessWidget {
  const TodoSettingsPage({
    super.key,
    required this.canCheckUpdate,
    required this.checkingUpdate,
    required this.onCheckUpdate,
    this.signedInMobile,
  });

  final bool canCheckUpdate;
  final bool checkingUpdate;
  final VoidCallback? onCheckUpdate;
  final String? signedInMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '—';
          final buildNumber = snapshot.data?.buildNumber;
          final versionLabel = buildNumber == null || buildNumber.isEmpty
              ? version
              : '$version ($buildNumber)';

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (signedInMobile != null && signedInMobile!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('账号', style: theme.textTheme.titleSmall),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_iphone_outlined),
                  title: const Text('当前账号'),
                  subtitle: Text(signedInMobile!),
                ),
                const Divider(height: 24),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('关于', style: theme.textTheme.titleSmall),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('版本号'),
                subtitle: Text(versionLabel),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: FilledButton.icon(
                  onPressed: canCheckUpdate && !checkingUpdate
                      ? onCheckUpdate
                      : null,
                  icon: checkingUpdate
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_outlined),
                  label: Text(checkingUpdate ? '正在检测更新…' : '检测更新'),
                ),
              ),
              if (!canCheckUpdate)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '当前环境未启用 GitHub Release 更新检查。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
