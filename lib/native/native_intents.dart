/// 原生增强的 Dart 侧 platform channel 契约与安全降级入口。
///
/// Android 已实现冷/热启动 URL Scheme、系统分享与可用时创建系统便签；
/// iOS、锁屏任务和真实桌面小组件等尚未接入的能力仍返回“不支持”或空结果。
library;

import 'package:flutter/services.dart';

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

  /// 锁屏重要任务：把任务 id 列表推送给系统（Android: KeyguardManager；iOS: Lock Screen widget）。
  static Future<bool> pushLockScreenTasks(List<int> taskIds) async {
    try {
      await _channel.invokeMethod('pushLockScreenTasks', {'ids': taskIds});
      return true;
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
