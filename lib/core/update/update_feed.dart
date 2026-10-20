/// GitHub Release 上的 Sparkle / WinSparkle 订阅地址。
const String kDesktopUpdateFeedUrl = String.fromEnvironment(
  'TODO_UPDATE_FEED_URL',
  defaultValue:
      'https://gh-proxy.com/https://github.com/izhaong/zh-cloud-todo-flutter/releases/latest/download/appcast.xml',
);

/// Linux 没有 Sparkle 实现时打开的发布页。
const String kGithubReleasesUrl =
    'https://github.com/izhaong/zh-cloud-todo-flutter/releases/latest';

/// Android 从这里取最新 Release 里的 `*-android.apk`。
const String kGithubLatestReleaseApi =
    'https://api.github.com/repos/izhaong/zh-cloud-todo-flutter/releases/latest';

/// 设为 false 时不后台检查，设置页也不显示「检查更新」。
const bool kDesktopUpdateCheckEnabled = bool.fromEnvironment(
  'TODO_UPDATE_CHECK',
  defaultValue: true,
);
