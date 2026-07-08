import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/session_state.dart';
import '../account/account_security_page.dart';

/// 设置页：分组列表（账户/主题/关于）+ 2FA 开关（复用 AccountSecurityPage）。
class SettingsRoute extends ConsumerWidget {
  const SettingsRoute({super.key, this.signedInMobile});

  final String? signedInMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(title: '账号'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (signedInMobile != null && signedInMobile!.isNotEmpty)
                  _Tile(
                    icon: Icons.phone_iphone_outlined,
                    title: '当前账号',
                    subtitle: signedInMobile,
                    colors: colors,
                  ),
                _Tile(
                  icon: Icons.verified_user_outlined,
                  title: '账户安全',
                  subtitle: '双重验证（2FA）与数据导出',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountSecurityPage()),
                  ),
                ),
                _Tile(
                  icon: Icons.logout,
                  title: '退出登录',
                  colors: colors,
                  destructive: true,
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(title: '关于'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _Tile(
              icon: Icons.info_outline,
              title: '版本号',
              subtitle: 'zh-cloud todo（本地离线优先版）',
              colors: colors,
            ),
          ),
          const SizedBox(height: 24),
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

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.mutedForeground,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.colors,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData? trailing;
  final AppColors colors;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? colors.destructive : colors.foreground;
    return ListTile(
      leading: Icon(icon, color: fg),
      title: Text(title, style: TextStyle(color: fg)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: colors.mutedForeground)),
      trailing: trailing == null ? null : Icon(trailing, color: colors.mutedForeground),
      onTap: onTap,
    );
  }
}
