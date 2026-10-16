import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// macOS 应用内更新在沙盒下的接线判据。
///
/// 真实现象：点「检查更新」下载完 DMG 后弹
/// `Update Error! An error occurred while launching the installer.`。
/// 这句来自 Sparkle 的 `SPUInstallerDriver`：沙盒应用没打开 Installer XPC 服务时，
/// Installer 起不来，更新永远装不上（本机 ad-hoc 签名档实测如此）。
///
/// 官方要求两件事，缺任一件都复现同一句报错：
///   1. Info.plist 里 `SUEnableInstallerLauncherService = YES`；
///   2. entitlements 里放行 `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki`
///      两个 mach-lookup 服务名。
/// 见 https://sparkle-project.org/documentation/sandboxing/
///
/// 用文件判据而不是读构建产物：这两个开关一旦被删，构建仍然成功、静态分析也
/// 全绿，只有真正点更新才炸——所以必须靠机械判据钉住。
void main() {
  test('macOS 沙盒档打开了 Sparkle Installer 服务，且放行两个 mach 服务名', () {
    final plist = File('macos/Runner/Info.plist').readAsStringSync();

    expect(
      plist,
      contains('<key>SUEnableInstallerLauncherService</key>'),
      reason: '沙盒下不打开 Installer 服务，更新下完也装不上（launching the installer 报错）',
    );
    expect(
      plist,
      isNot(contains('<key>SUEnableDownloaderService</key>')),
      reason: '本应用已声明 network.client，按官方文档不该再开 Downloader 服务',
    );
    // 订阅地址与公钥是签名校验的另一半：删了会静默地「永远没有新版本」。
    expect(plist, contains('<key>SUFeedURL</key>'));
    expect(plist, contains('<key>SUPublicEDKey</key>'));
  });

  test('Debug 与 Release 两档都放行 Installer 的 mach-lookup 服务名', () {
    for (final path in const [
      'macos/Runner/Release.entitlements',
      'macos/Runner/DebugProfile.entitlements',
    ]) {
      final entitlements = File(path).readAsStringSync();
      expect(
        entitlements,
        contains(
          '<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>',
        ),
        reason: '$path 少了这条，Sparkle 连不上 Installer ⇒ 更新装不上',
      );
      expect(
        entitlements,
        contains(r'<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>'),
        reason: '$path 必须放行 -spks（Installer 状态服务）',
      );
      expect(
        entitlements,
        contains(r'<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>'),
        reason: '$path 必须放行 -spki（Installer 安装服务）',
      );
      // 沙盒本身要是关掉的，就不需要上面那两条；留着这个断言是为了让
      // 「有人顺手关沙盒」时也回来改这份判据，而不是让配置半半拉拉。
      expect(
        entitlements,
        contains('<key>com.apple.security.app-sandbox</key>'),
        reason: '本档是沙盒应用；关沙盒要连同本条判据一起改',
      );
    }
  });
}
