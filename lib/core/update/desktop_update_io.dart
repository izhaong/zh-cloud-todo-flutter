import 'dart:async';
import 'dart:convert';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'github_apk_release.dart';
import 'update_feed.dart';
import 'update_surface.dart';

Future<void> prepareDesktopUpdate() async {
  if (!kDesktopUpdateCheckEnabled) return;
  if (_surface() != UpdateSurface.sparkle) {
    if (_surface() == UpdateSurface.apk) {
      try {
        await installAndroidApkUpdate();
      } on UpdateAlreadyCurrent {
        // 启动时已经是最新版，不打扰用户。
      } catch (error) {
        debugPrint('android update check failed: $error');
      }
    }
    return;
  }
  try {
    await autoUpdater.setFeedURL(kDesktopUpdateFeedUrl);
    await autoUpdater.setScheduledCheckInterval(86400);
    await autoUpdater.checkForUpdates(inBackground: true);
  } catch (error) {
    debugPrint('desktop update check failed: $error');
  }
}

Future<void> checkDesktopUpdateNow() async {
  if (!kDesktopUpdateCheckEnabled) return;
  switch (_surface()) {
    case UpdateSurface.sparkle:
      await autoUpdater.setFeedURL(kDesktopUpdateFeedUrl);
      await autoUpdater.checkForUpdates();
    case UpdateSurface.releasePage:
      final opened = await launchUrl(
        Uri.parse(kGithubReleasesUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw StateError('无法打开 GitHub Release');
      }
    case UpdateSurface.apk:
      await installAndroidApkUpdate();
    case UpdateSurface.none:
      return;
  }
}

UpdateSurface _surface() {
  if (kIsWeb) {
    return updateSurfaceFor(isWeb: true, operatingSystem: 'web');
  }
  final operatingSystem = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.fuchsia => 'fuchsia',
  };
  return updateSurfaceFor(isWeb: false, operatingSystem: operatingSystem);
}

Future<void> installAndroidApkUpdate() async {
  final response = await http.get(
    Uri.parse(kGithubLatestReleaseApi),
    headers: const {'Accept': 'application/vnd.github+json'},
  );
  if (response.statusCode != 200) {
    throw StateError('GitHub Release 暂时不可用');
  }
  final latest = apkAssetFromReleaseJson(jsonDecode(response.body));
  if (latest == null) {
    throw StateError('Release 里没有 Android 安装包');
  }
  final current = (await PackageInfo.fromPlatform()).version;
  if (compareSemver(latest.version, current) <= 0) {
    throw const UpdateAlreadyCurrent();
  }
  final done = Completer<void>();
  OtaUpdate()
      .execute(latest.downloadUrl, destinationFilename: 'todo-flutter-android.apk')
      .listen(
        (event) {
          if (done.isCompleted) return;
          switch (event.status) {
            case OtaStatus.INSTALLING:
              done.complete();
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.CANCELED:
              done.completeError(StateError(event.value ?? '下载安装包失败'));
            case OtaStatus.DOWNLOADING:
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.INSTALLATION_DONE:
            case OtaStatus.INSTALLATION_ERROR:
              break;
          }
        },
        onError: (Object error) {
          if (!done.isCompleted) done.completeError(error);
        },
      );
  await done.future;
}
