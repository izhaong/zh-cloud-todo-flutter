import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 取品牌颜色；若主题未注入 [AppThemeExtension]（如部分测试用 plain
/// MaterialApp），回退到 ColorScheme 派生，保证视图不崩溃。
AppColors brandColors(BuildContext context) {
  final ext = Theme.of(context).extension<AppThemeExtension>();
  if (ext != null) return ext.colors;
  final scheme = Theme.of(context).colorScheme;
  return AppColors(
    background: Theme.of(context).scaffoldBackgroundColor,
    surface: scheme.surface,
    ink: scheme.onSurface,
    foreground: scheme.onSurface,
    muted: scheme.surfaceContainerHighest,
    mutedForeground: scheme.onSurfaceVariant,
    border: scheme.outlineVariant,
    accent: scheme.primary,
    accentForeground: scheme.onPrimary,
    destructive: scheme.error,
    destructiveForeground: scheme.onError,
    success: Colors.green,
    warning: Colors.orange,
    info: Colors.blue,
    overdue: scheme.error,
    today: scheme.primary,
    future: Colors.grey,
    completed: Colors.green,
    dangerSurface: scheme.errorContainer,
    dangerOnSurface: scheme.onErrorContainer,
  );
}
