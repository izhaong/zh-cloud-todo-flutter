import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

/// 设置页（精简版）：仅展示当前登录手机号 + 退出登录。
///
/// 旧版基于 [github_release_update] 的"检测更新"入口在此轮移除，避免与即将
/// 删除的遗留文件产生硬依赖；后续若需恢复，可独立实现 IO 更新通道，再回来
/// 接入。
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
