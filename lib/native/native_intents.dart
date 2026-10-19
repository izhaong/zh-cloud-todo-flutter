/// 原生增强入口。
///
/// 系统分享、桌面今日任务小组件、专注常亮分别交给 `share_plus`、
/// `home_widget`、`wakelock_plus`。深链、系统便签和锁屏通知仍走
/// `zh_cloud_todo/native`，插件缺失或平台不支持时安全返回失败。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class NativeLockScreenTask {
  const NativeLockScreenTask({required this.serverId, required this.title});

  final int serverId;
  final String title;

  Map<String, Object> toJson() => {'id': serverId, 'title': title};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeLockScreenTask &&
          serverId == other.serverId &&
          title == other.title;

  @override
  int get hashCode => Object.hash(serverId, title);
}

class NativeTaskAddRequest {
  const NativeTaskAddRequest({
    required this.title,
    required this.dueAt,
    required this.allDay,
  });

  final String title;
  final DateTime? dueAt;
  final bool allDay;

  static NativeTaskAddRequest? tryParse(Uri uri) {
    if (uri.scheme.toLowerCase() != NativeIntents.urlScheme ||
        uri.host.toLowerCase() != 'task' ||
        uri.path != '/add' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final titleValues = uri.queryParametersAll['title'];
    if (titleValues == null || titleValues.length != 1) return null;
    final title = titleValues.single.trim();
    if (title.isEmpty) return null;

    final dueValues = uri.queryParametersAll['due'];
    if (dueValues != null && dueValues.length != 1) return null;
    final dueAt = dueValues == null ? null : _parseDate(dueValues.single);
    if (dueValues != null && dueAt == null) return null;
    return NativeTaskAddRequest(
      title: title,
      dueAt: dueAt,
      allDay: dueAt != null,
    );
  }

  static DateTime? _parseDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}

class NativeIntents {
  NativeIntents._();

  static const MethodChannel _channel = MethodChannel('zh_cloud_todo/native');
  static const EventChannel _linkEvents = EventChannel(
    'zh_cloud_todo/native_links',
  );

  /// 注册 URL Scheme handler（iOS: CFBundleURLTypes；Android: intent-filter）。
  /// 协议：zhcloudtodo://task/add?title=xxx&due=2026-06-20
  static const String urlScheme = 'zhcloudtodo';

  /// 处理从 URL Scheme 进入的指令。
  static Future<Uri?> handleIncomingUri() async {
    try {
      final uri = await _channel.invokeMethod<String>('getInitialLink');
      if (uri == null) return null;
      return Uri.tryParse(uri);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 监听应用已运行时收到的 URL Scheme。先通过 MethodChannel 确认平台
  /// 已注册事件 handler；不支持时返回空流，避免 EventChannel 把激活失败
  /// 直接上报为未处理的 FlutterError。
  static Stream<Uri> incomingUris() async* {
    try {
      final supported = await _channel.invokeMethod<bool>('supportsLinkEvents');
      if (supported != true) return;
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
    await for (final event in _linkEvents.receiveBroadcastStream()) {
      if (event is! String) continue;
      final uri = Uri.tryParse(event);
      if (uri != null) yield uri;
    }
  }

  /// 系统分享：交给 [SharePlus]，覆盖 Android / iOS / 桌面 / Web。
  static Future<bool> shareText(String text, {String? subject}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final trimmedSubject = subject?.trim();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: trimmed,
          subject: (trimmedSubject == null || trimmedSubject.isEmpty)
              ? null
              : trimmedSubject,
        ),
      );
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 桌面便签：把字符串写入系统便签（Android StickyNote API / iOS Today Extension）。
  /// 失败时返回 false，由调用方 fallback 到应用内便签 UI。
  static Future<bool> setStickyNote(String content) async {
    try {
      await _channel.invokeMethod('setStickyNote', {'content': content});
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 前台专注会话保持屏幕常亮。插件缺失或平台拒绝时返回 false。
  static Future<bool> setKeepScreenAwake(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 锁屏重要任务：Android 以 ongoing 通知展示最多五项已同步任务；
  /// 空快照会清除通知。iOS 未实现时安全返回 false。
  static Future<bool> pushLockScreenTasks(
    Iterable<NativeLockScreenTask> tasks,
  ) async {
    final candidates = tasks.take(5).toList(growable: false);
    if (candidates.any(
      (task) => task.serverId <= 0 || task.title.trim().isEmpty,
    )) {
      return false;
    }
    final snapshot = candidates
        .map(
          (task) => NativeLockScreenTask(
            serverId: task.serverId,
            title: task.title.trim(),
          ).toJson(),
        )
        .toList(growable: false);
    try {
      final rendered = await _channel.invokeMethod<bool>(
        'pushLockScreenTasks',
        {'tasks': snapshot},
      );
      return rendered == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// FL #345 A′：鸿蒙「智感握姿」能力探测（嘀嗒《01-添加任务》:28-33 ——
  /// 「在支持『智感握姿』的设备上…设定不同持握姿式的添加位置」，
  /// 需 HarmonyOS 6.0.0.115+ 且设备支持）。
  ///
  /// 裁决口径：**能力探测失败则明说不支持，不造假**。本端 Flutter 侧拿不到
  /// 厂商握姿 SDK 的通道 ⇒ 探测结果恒为 false —— 但**不许**因此删掉探测：
  /// 桌面/移动小组件与快捷键都已落，握姿这一面保持"探测→如实报告"的形状，
  /// 平台通道补上时只改这里一处。
  static Future<bool> supportsGripPosture() async {
    try {
      final supported = await _channel.invokeMethod<bool>(
        'supportsGripPosture',
      );
      return supported == true;
    } on PlatformException {
      return false; // 探测失败 = 不支持（明说，不猜）
    } on MissingPluginException {
      return false; // 通道未实现（当前所有平台）—— 如实报告不支持
    }
  }

  static const _widgetTasksKey = 'tasks';
  static const _androidWidgetProvider =
      'com.zh04.zh_cloud_todo_flutter.TodayTasksWidgetProvider';

  /// 读回 [home_widget] 里保存的今日任务标题。
  static Future<List<Map<String, dynamic>>> widgetTodaySnapshot() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>(_widgetTasksKey);
      return _decodeWidgetTitles(raw);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// 把当前账号的今日任务标题写入桌面小组件并刷新。
  static Future<bool> updateTodayWidgetSnapshot(Iterable<String> titles) async {
    final tasks = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .take(5)
        .toList(growable: false);
    try {
      final saved = await HomeWidget.saveWidgetData<String>(
        _widgetTasksKey,
        jsonEncode(tasks),
      );
      if (saved != true) return false;
      final updated = await HomeWidget.updateWidget(
        qualifiedAndroidName: _androidWidgetProvider,
      );
      return updated == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static List<Map<String, dynamic>> _decodeWidgetTitles(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.trim().isNotEmpty) {'title': item.trim()},
      ];
    } on FormatException {
      return const [];
    }
  }
}
