/// 当前版本已经不低于 GitHub Release。
class UpdateAlreadyCurrent implements Exception {
  const UpdateAlreadyCurrent();
}

class GithubApkAsset {
  const GithubApkAsset({required this.version, required this.downloadUrl});

  final String version;
  final String downloadUrl;
}

/// 从 `v1.2.3` 或 `1.2.3+6` 取出 `1.2.3`。无法识别时返回 null。
String? semverFromTag(String tag) {
  final trimmed = tag.trim();
  final normalized = trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(normalized);
  if (match == null) return null;
  return '${match[1]}.${match[2]}.${match[3]}';
}

/// a 比 b 新时返回正数。
int compareSemver(String a, String b) {
  final left = a.split('.').map(int.parse).toList();
  final right = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final av = i < left.length ? left[i] : 0;
    final bv = i < right.length ? right[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

/// 从 GitHub Release JSON 里挑出 `*-android.apk`。
GithubApkAsset? apkAssetFromReleaseJson(Object? json) {
  if (json is! Map) return null;
  final version = semverFromTag('${json['tag_name'] ?? ''}');
  final assets = json['assets'];
  if (version == null || assets is! List) return null;
  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = '${asset['name'] ?? ''}';
    final url = asset['browser_download_url'];
    if (name.endsWith('-android.apk') && url is String && url.isNotEmpty) {
      // 同 appcast：国内直连 github.com 不稳，OTA 下载统一走 gh-proxy 前缀
      // （downloadUrl 只用于 OtaUpdate 下载，不进 UI 展示）。
      const proxy = 'https://gh-proxy.com/';
      return GithubApkAsset(
        version: version,
        downloadUrl: url.startsWith(proxy) ? url : '$proxy$url',
      );
    }
  }
  return null;
}
