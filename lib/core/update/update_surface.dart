/// 各端怎么走更新。macOS / Windows 用 auto_updater，Android 用 ota_update，Linux 打开 Release 页。
enum UpdateSurface { sparkle, apk, releasePage, none }

UpdateSurface updateSurfaceFor({
  required bool isWeb,
  required String operatingSystem,
}) {
  if (isWeb) return UpdateSurface.none;
  switch (operatingSystem) {
    case 'macos':
    case 'windows':
      return UpdateSurface.sparkle;
    case 'linux':
      return UpdateSurface.releasePage;
    case 'android':
      return UpdateSurface.apk;
    case 'ios':
    case 'fuchsia':
    case 'web':
      return UpdateSurface.none;
    default:
      return UpdateSurface.none;
  }
}
