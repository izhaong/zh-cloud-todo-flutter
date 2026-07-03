import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/github_release_update.dart';

void main() {
  group('parseSemverFromTag', () {
    test('parses v-prefixed tags', () {
      expect(parseSemverFromTag('v1.2.3'), '1.2.3');
    });

    test('rejects non-semver tags', () {
      expect(parseSemverFromTag('desktop-test-abc123'), isNull);
    });
  });

  group('compareSemver', () {
    test('orders versions', () {
      expect(compareSemver('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareSemver('1.0.0', '1.0.0'), 0);
      expect(compareSemver('0.9.9', '1.0.0'), lessThan(0));
    });
  });

  group('pickDownloadUrl', () {
    test('selects platform asset', () {
      final release = {
        'assets': [
          {
            'name': 'todo-flutter-prod-v1.0.0+1-macos.zip',
            'browser_download_url': 'https://example.com/macos.zip',
          },
          {
            'name': 'todo-flutter-prod-v1.0.0+1-linux-x64.tar.gz',
            'browser_download_url': 'https://example.com/linux.tar.gz',
          },
        ],
      };

      expect(
        pickDownloadUrl(release, DesktopReleasePlatform.linux),
        'https://example.com/linux.tar.gz',
      );
    });
  });

  group('GithubReleaseUpdateChecker', () {
    test('returns update when remote is newer', () async {
      final checker = GithubReleaseUpdateChecker(
        gateway: _FakeGateway({
          'tag_name': 'v1.1.0',
          'body': '修复若干问题',
          'assets': [
            {
              'name': 'todo-flutter-prod-v1.1.0+2-macos.zip',
              'browser_download_url': 'https://example.com/update.zip',
            },
          ],
        }),
        currentVersion: '1.0.0',
        platform: DesktopReleasePlatform.macos,
      );

      final info = await checker.checkForUpdate();
      expect(info, isNotNull);
      expect(info!.version, '1.1.0');
      expect(info.downloadUrl, 'https://example.com/update.zip');
    });

    test('returns null when already up to date', () async {
      final checker = GithubReleaseUpdateChecker(
        gateway: _FakeGateway({
          'tag_name': 'v1.0.0',
          'assets': [
            {
              'name': 'todo-flutter-prod-v1.0.0+1-macos.zip',
              'browser_download_url': 'https://example.com/update.zip',
            },
          ],
        }),
        currentVersion: '1.0.0',
        platform: DesktopReleasePlatform.macos,
      );

      expect(await checker.checkForUpdate(), isNull);
    });
  });
}

class _FakeGateway implements GithubReleaseGateway {
  _FakeGateway(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<Map<String, dynamic>?> fetchRelease({
    required bool includePrerelease,
  }) async {
    return payload;
  }
}
