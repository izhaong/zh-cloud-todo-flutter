import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../github_release_update.dart';
import '../../settings_page.dart';
import '../../state/session_state.dart';

/// [TodoSettingsPage] 的状态容器：管理「检测更新」按钮的加载态与结果展示，
/// 桌面自动更新逻辑迁移自旧版 main.dart（保持行为不变）；退出登录接入
/// [sessionProvider]。
class SettingsRoute extends ConsumerStatefulWidget {
  const SettingsRoute({super.key, this.signedInMobile});

  final String? signedInMobile;

  @override
  ConsumerState<SettingsRoute> createState() => _SettingsRouteState();
}

class _SettingsRouteState extends ConsumerState<SettingsRoute> {
  GithubReleaseGateway? _releaseGateway;
  bool _ownsReleaseGateway = false;
  bool _checkingUpdate = false;

  bool get _canCheckUpdate => shouldCheckGithubReleaseUpdate();

  @override
  void initState() {
    super.initState();
    if (_canCheckUpdate) {
      _releaseGateway = GithubReleaseHttpClient(repo: githubReleaseRepo());
      _ownsReleaseGateway = true;
    }
  }

  @override
  void dispose() {
    if (_ownsReleaseGateway && _releaseGateway is GithubReleaseHttpClient) {
      (_releaseGateway! as GithubReleaseHttpClient).close();
    }
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    final gateway = _releaseGateway;
    if (gateway == null || _checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final checker = GithubReleaseUpdateChecker(
        gateway: gateway,
        currentVersion: info.version,
        includePrerelease: githubReleaseIncludePrerelease(),
      );
      final update = await checker.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发现新版本 ${update.version}'),
          action: SnackBarAction(
            label: '下载',
            onPressed: () => launchUrl(Uri.parse(update.downloadUrl)),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('检测更新失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(sessionProvider.notifier).signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return TodoSettingsPage(
      canCheckUpdate: _canCheckUpdate,
      checkingUpdate: _checkingUpdate,
      onCheckUpdate: _canCheckUpdate ? _checkForUpdate : null,
      signedInMobile: widget.signedInMobile,
      onSignOut: _signOut,
    );
  }
}
