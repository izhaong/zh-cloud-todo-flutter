import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';
import '../account/account_security_page.dart';

/// 设置页：账户安全 + 当前账号 + 退出登录。
class SettingsRoute extends ConsumerWidget {
  const SettingsRoute({super.key, this.signedInMobile});

  final String? signedInMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('账号', style: theme.textTheme.titleSmall),
          ),
          if (signedInMobile != null && signedInMobile!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.phone_iphone_outlined),
              title: const Text('当前账号'),
              subtitle: Text(signedInMobile!),
            ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('账户安全'),
            subtitle: const Text('双重验证（2FA）与数据导出'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountSecurityPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('退出登录'),
            onTap: () => _signOut(context, ref),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('关于', style: theme.textTheme.titleSmall),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本号'),
            subtitle: Text('zh-cloud todo（本地离线优先版）'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
