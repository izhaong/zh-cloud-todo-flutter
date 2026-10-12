import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/update/update_surface.dart';

void main() {
  test('macOS 与 Windows 走 Sparkle，Linux 打开 Release 页', () {
    expect(
      updateSurfaceFor(isWeb: false, operatingSystem: 'macos'),
      UpdateSurface.sparkle,
    );
    expect(
      updateSurfaceFor(isWeb: false, operatingSystem: 'windows'),
      UpdateSurface.sparkle,
    );
    expect(
      updateSurfaceFor(isWeb: false, operatingSystem: 'linux'),
      UpdateSurface.releasePage,
    );
    expect(
      updateSurfaceFor(isWeb: false, operatingSystem: 'android'),
      UpdateSurface.apk,
    );
  });

  test('Web 与 iOS 不检查桌面或 APK 更新', () {
    expect(
      updateSurfaceFor(isWeb: true, operatingSystem: 'macos'),
      UpdateSurface.none,
    );
    expect(
      updateSurfaceFor(isWeb: false, operatingSystem: 'ios'),
      UpdateSurface.none,
    );
  });
}
