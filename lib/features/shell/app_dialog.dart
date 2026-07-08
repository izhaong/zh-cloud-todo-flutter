import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';

/// 品牌化弹窗系统（对齐 TickTick 圆角弹窗）。
///
/// - 圆角 16（AppRadius.xl）+ 品牌强调按钮 + AppSpacing 间距规范
/// - [confirm] / [alert] 两个常用入口，避免重复写 AlertDialog 样式。
class AppDialog {
  /// 确认弹窗：标题 + 内容 + 取消/确认按钮。
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? content,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    bool danger = false,
  }) async {
    final colors = brandColors(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
        ),
        content: content == null
            ? null
            : Text(
                content,
                style: TextStyle(color: colors.foreground),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel, style: TextStyle(color: colors.mutedForeground)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: danger ? colors.destructive : colors.accent,
              foregroundColor:
                  danger ? colors.destructiveForeground : colors.accentForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 提示弹窗（单确认按钮）。
  static Future<void> alert(
    BuildContext context, {
    required String title,
    String? content,
    String confirmLabel = '知道了',
  }) async {
    final colors = brandColors(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.ink),
        ),
        content: content == null
            ? null
            : Text(content, style: TextStyle(color: colors.foreground)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.accentForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
