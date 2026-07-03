import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 桌面端平台（用于匹配 Release 安装包文件名后缀）。
enum DesktopReleasePlatform {
  macos,
  linux,
  windows,
}

/// GitHub Release 检查结果。
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.downloadUrl,
    required this.currentVersion,
    this.releaseNotes,
  });

  final String tagName;
  final String version;
  final String downloadUrl;
  final String currentVersion;
  final String? releaseNotes;
}

/// 拉取 GitHub Release 元数据（便于测试注入 Fake）。
abstract class GithubReleaseGateway {
  Future<Map<String, dynamic>?> fetchRelease({required bool includePrerelease});
}

class GithubReleaseHttpClient implements GithubReleaseGateway {
  GithubReleaseHttpClient({
    required this.repo,
    http.Client? client,
    this.apiBase = 'https://api.github.com',
  }) : _client = client ?? http.Client();

  final String repo;
  final String apiBase;
  final http.Client _client;

  @override
  Future<Map<String, dynamic>?> fetchRelease({
    required bool includePrerelease,
  }) async {
    if (includePrerelease) {
      final uri = Uri.parse('$apiBase/repos/$repo/releases?per_page=30');
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'application/vnd.github+json'},
      );
      if (response.statusCode != 200) {
        return null;
      }
      final list = jsonDecode(response.body) as List<dynamic>;
      for (final item in list) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        if (item['draft'] == true) {
          continue;
        }
        final tag = item['tag_name'] as String? ?? '';
        if (parseSemverFromTag(tag) != null) {
          return item;
        }
      }
      return null;
    }

    final uri = Uri.parse('$apiBase/repos/$repo/releases/latest');
    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void close() => _client.close();
}

/// 从 tag（如 `v1.2.3`）解析语义化版本；非 semver tag 返回 null。
String? parseSemverFromTag(String tag) {
  final trimmed = tag.trim();
  final normalized = trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(normalized);
  if (match == null) {
    return null;
  }
  return '${match.group(1)}.${match.group(2)}.${match.group(3)}';
}

/// 比较语义化版本：a>b 返回正数，相等返回 0。
int compareSemver(String a, String b) {
  final ap = a.split('.').map(int.parse).toList();
  final bp = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final av = i < ap.length ? ap[i] : 0;
    final bv = i < bp.length ? bp[i] : 0;
    if (av != bv) {
      return av.compareTo(bv);
    }
  }
  return 0;
}

DesktopReleasePlatform? desktopPlatformForHost() {
  if (kIsWeb) {
    return null;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      return DesktopReleasePlatform.macos;
    case TargetPlatform.linux:
      return DesktopReleasePlatform.linux;
    case TargetPlatform.windows:
      return DesktopReleasePlatform.windows;
    default:
      return null;
  }
}

/// RustDesk 风格安装包后缀（按优先级：EXE/DMG/DEB 优先于 MSI）。
List<String> assetSuffixesForPlatform(DesktopReleasePlatform platform) {
  switch (platform) {
    case DesktopReleasePlatform.macos:
      return ['-aarch64.dmg', '-x86_64.dmg', '.dmg'];
    case DesktopReleasePlatform.linux:
      return ['-x86_64.deb', '.deb'];
    case DesktopReleasePlatform.windows:
      return ['-x86_64.exe', '-x86_64.msi', '.exe', '.msi'];
  }
}

String? pickDownloadUrl(
  Map<String, dynamic> release,
  DesktopReleasePlatform platform,
) {
  final suffixes = assetSuffixesForPlatform(platform);
  final assets = release['assets'];
  if (assets is! List<dynamic>) {
    return null;
  }
  for (final suffix in suffixes) {
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }
      final name = asset['name'] as String? ?? '';
      final url = asset['browser_download_url'] as String? ?? '';
      if (name.endsWith(suffix) && url.isNotEmpty) {
        return url;
      }
    }
  }
  final htmlUrl = release['html_url'] as String?;
  return htmlUrl?.isNotEmpty == true ? htmlUrl : null;
}

bool shouldCheckGithubReleaseUpdate() {
  if (kIsWeb) {
    return false;
  }
  const enabled = String.fromEnvironment(
    'TODO_UPDATE_CHECK',
    defaultValue: 'true',
  );
  if (enabled.toLowerCase() == 'false') {
    return false;
  }
  return desktopPlatformForHost() != null;
}

bool githubReleaseIncludePrerelease() {
  const channel = String.fromEnvironment(
    'TODO_UPDATE_CHANNEL',
    defaultValue: '',
  );
  if (channel == 'test') {
    return true;
  }
  if (channel == 'prod') {
    return false;
  }
  const apiBase = String.fromEnvironment(
    'TODO_API_BASE_URL',
    defaultValue: '',
  );
  return apiBase.contains('-test.');
}

String githubReleaseRepo() {
  return const String.fromEnvironment(
    'TODO_GITHUB_REPO',
    defaultValue: 'izhaong/zh-cloud-todo-flutter',
  );
}

class GithubReleaseUpdateChecker {
  GithubReleaseUpdateChecker({
    required this.gateway,
    required this.currentVersion,
    this.platform,
    this.includePrerelease = false,
  });

  final GithubReleaseGateway gateway;
  final String currentVersion;
  final DesktopReleasePlatform? platform;
  final bool includePrerelease;

  Future<AppUpdateInfo?> checkForUpdate() async {
    final hostPlatform = platform ?? desktopPlatformForHost();
    if (hostPlatform == null) {
      return null;
    }

    final release = await gateway.fetchRelease(
      includePrerelease: includePrerelease,
    );
    if (release == null) {
      return null;
    }

    final tag = release['tag_name'] as String? ?? '';
    final remoteVersion = parseSemverFromTag(tag);
    if (remoteVersion == null) {
      return null;
    }

    final current = parseSemverFromTag(currentVersion) ?? currentVersion;
    if (compareSemver(remoteVersion, current) <= 0) {
      return null;
    }

    final downloadUrl = pickDownloadUrl(release, hostPlatform);
    if (downloadUrl == null || downloadUrl.isEmpty) {
      return null;
    }

    return AppUpdateInfo(
      tagName: tag,
      version: remoteVersion,
      downloadUrl: downloadUrl,
      currentVersion: current,
      releaseNotes: release['body'] as String?,
    );
  }
}
