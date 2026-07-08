import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主题模式（亮/暗/跟随系统）。默认跟随系统，可在 设置 中切换。
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system);
  void set(ThemeMode mode) => state = mode;
}

/// UI 文案：把 [ThemeMode] 翻译成中文标签。
String themeModeLabel(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:
      return '浅色';
    case ThemeMode.dark:
      return '深色';
    case ThemeMode.system:
      return '跟随系统';
  }
}
