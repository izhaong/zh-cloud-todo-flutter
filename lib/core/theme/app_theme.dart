import 'package:flutter/material.dart';

/// 品牌化设计令牌 —— 来自 TickTick 视觉基准 + ui-ux-pro-max Productivity 域。
///
/// 色板角色（5 角色系统，对齐 impeccable/ui-ux-pro-max 语义）：
/// - background: 页面底色（TickTick 暖白，非纯白）
/// - surface: 卡片/输入框 底色（纯白）
/// - ink / foreground: 主文字（深墨绿黑）
/// - accent: 强调色（品牌蓝，选中/按钮/链接）
/// - muted: 次要文字与禁用态
@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.ink,
    required this.foreground,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.success,
    required this.warning,
    required this.info,
    required this.overdue,
    required this.today,
    required this.future,
    required this.completed,
  });

  final Color background; // 页面暖白底
  final Color surface; // 卡片/输入（纯白）
  final Color ink; // 最深文字（空状态标题）
  final Color foreground; // 主文字
  final Color muted; // 次要元素
  final Color mutedForeground; // 次要文字
  final Color border; // 分割线
  final Color accent; // 品牌强调蓝
  final Color accentForeground; // accent 上的文字（通常白）
  final Color destructive; // 红（删除/错误）
  final Color destructiveForeground;
  final Color success; // 绿
  final Color warning; // 橙
  final Color info; // 浅蓝

  // 任务状态语义色（对齐 zh-cloud-docs todo-tokens.json）
  final Color overdue; // 逾期红
  final Color today; // 今天蓝
  final Color future; // 未来灰
  final Color completed; // 已完成绿/灰

  /// Phase 0 初始品牌色 —— TickTick 视觉基准。
  static const light = AppColors(
    background: Color(0xFFF7F6F3), // TickTick 暖白底
    surface: Color(0xFFFFFFFF), // 卡片纯白
    ink: Color(0xFF1A1A1A), // 空状态/强调标题
    foreground: Color(0xFF2C2C2C), // 主文字
    muted: Color(0xFFE8E6E1), // 次要元素
    mutedForeground: Color(0xFF8A8A89), // 次要文字
    border: Color(0xFFE0DFDA), // 分割线
    accent: Color(0xFF2B7EFD), // 品牌蓝（选中/按钮/链接）
    accentForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFE5484D), // 删除红
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF30A46C), // 完成绿
    warning: Color(0xFFF59E0B), // 提醒橙
    info: Color(0xFF3E63DD), // 信息蓝
    overdue: Color(0xFFE5484D), // 逾期
    today: Color(0xFF2B7EFD), // 今天
    future: Color(0xFF8A8A89), // 未来
    completed: Color(0xFF30A46C), // 已完成
  );

  /// 暗色模式（后续解锁；Phase 0 先置 stub）
  static const dark = AppColors(
    background: Color(0xFF1A1A1A),
    surface: Color(0xFF2C2C2C),
    ink: Color(0xFFFFFFFF),
    foreground: Color(0xFFF5F5F5),
    muted: Color(0xFF3A3A3A),
    mutedForeground: Color(0xFFA1A1A1),
    border: Color(0xFF3A3A3A),
    accent: Color(0xFF4D8FFA),
    accentForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFE5484D),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF30A46C),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF3E63DD),
    overdue: Color(0xFFE5484D),
    today: Color(0xFF4D8FFA),
    future: Color(0xFFA1A1A1),
    completed: Color(0xFF30A46C),
  );
}

/// 颜色 ThemeExtension（便于 Theme.of(context).extension<AppColors>()）
class AppThemeExtension extends ThemeExtension<AppColors> {
  const AppThemeExtension(this.colors);
  final AppColors colors;

  @override
  ThemeExtension<AppColors> copyWith({AppColors? colors}) =>
      AppThemeExtension(colors ?? this.colors);

  @override
  ThemeExtension<AppColors> lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// 圆角令牌（对齐 todo-tokens.json radius 4/6/8）
class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 999;
}

/// 间距令牌（4 基础网格）
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// 阴影令牌
class AppShadows {
  static List<BoxShadow> card(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> popup(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
