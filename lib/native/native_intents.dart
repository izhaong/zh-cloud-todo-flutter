/// 原生增强的 Dart 侧 platform channel 契约与安全降级入口。
///
/// Android / iOS 等平台侧 handler 尚未注册，因此当前调用会返回“不支持”
/// 或空结果；原生实现接入后必须继续保持这里的参数与返回值契约。
library;

import 'package:flutter/services.dart';

class NativeIntents {
  NativeIntents._();

  static const MethodChannel _channel = MethodChannel('zh_cloud_todo/native');

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
}
