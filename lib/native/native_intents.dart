/// 原生增强的 Dart 侧 platform channel 契约与安全降级入口。
///
/// Android 已实现冷/热启动 URL Scheme、系统分享、可用时创建系统便签、
/// 锁屏重要任务通知与今日任务桌面小组件；iOS 尚未接入的能力仍返回
/// “不支持”或空结果。
library;

import 'package:flutter/services.dart';

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

  /// 监听应用已运行时收到的 URL Scheme。平台未注册事件通道时会向订阅者
  /// 报错，调用方应安全忽略并继续使用应用内功能。
  static Stream<Uri> incomingUris() async* {
    await for (final event in _linkEvents.receiveBroadcastStream()) {
      if (event is! String) continue;
      final uri = Uri.tryParse(event);
      if (uri != null) yield uri;
    }
  }

  /// 系统分享入口：把文本/链接转发到 Android Share / iOS UIActivityViewController。
  static Future<bool> shareText(String text, {String? subject}) async {
    try {
      await _channel.invokeMethod('share', {'text': text, 'subject': ?subject});
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

  /// 小组件数据：返回今日任务的 JSON 序列化字符串（widget renderer 读取）。
  static Future<List<Map<String, dynamic>>> widgetTodaySnapshot() async {
    try {
      final r = await _channel.invokeMethod<List<dynamic>>(
        'widgetTodaySnapshot',
      );
      if (r == null) return const [];
      return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// 把 Flutter 当前账号 Drift 中的真实今日任务投影写入原生桌面小组件。
  static Future<bool> updateTodayWidgetSnapshot(Iterable<String> titles) async {
    final tasks = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .take(5)
        .map((title) => {'title': title})
        .toList(growable: false);
    try {
      await _channel.invokeMethod('updateTodayWidgetSnapshot', {
        'tasks': tasks,
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
