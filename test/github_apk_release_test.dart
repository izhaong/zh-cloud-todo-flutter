import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/update/github_apk_release.dart';

void main() {
  test('从 Release JSON 取出 android apk', () {
    final asset = apkAssetFromReleaseJson({
      'tag_name': 'v1.0.6',
      'assets': [
        {
          'name': 'todo-flutter-1.0.6-x86_64.deb',
          'browser_download_url': 'https://example.com/app.deb',
        },
        {
          'name': 'todo-flutter-1.0.6-android.apk',
          'browser_download_url': 'https://example.com/app.apk',
        },
      ],
    });
    expect(asset?.version, '1.0.6');
    // OTA 下载统一走 gh-proxy 前缀（国内直连 github 不稳，见 github_apk_release.dart）
    expect(
      asset?.downloadUrl,
      'https://gh-proxy.com/https://example.com/app.apk',
    );
  });

  test('1.0.6 比 1.0.5 新，相同版本不更新', () {
    expect(compareSemver('1.0.6', '1.0.5'), greaterThan(0));
    expect(compareSemver('1.0.5', '1.0.5'), 0);
    expect(compareSemver('1.0.4', '1.0.5'), lessThan(0));
  });
}
