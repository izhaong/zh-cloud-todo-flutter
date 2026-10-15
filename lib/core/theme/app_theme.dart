import 'package:flutter/material.dart';

import 'todo_layout_tokens.dart';

/// Todo 产品的基础语义色与通用设计令牌。
///
/// 色板角色（5 角色系统，对齐 impeccable/ui-ux-pro-max 语义）：
/// - background: 页面画布底色
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

  /// 浅色品牌语义色。
  static const light = AppColors(
    background: TodoLayoutTokens.lightCanvas,
    surface: TodoLayoutTokens.lightSurface,
    ink: TodoLayoutTokens.lightPrimaryText,
    foreground: TodoLayoutTokens.lightPrimaryText,
    muted: TodoLayoutTokens.lightSelectedRow,
    mutedForeground: TodoLayoutTokens.lightMutedText,
    border: TodoLayoutTokens.lightDivider,
    accent: Color(0xFF2B7EFD), // 品牌蓝（选中/按钮/链接）
    accentForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFE5484D), // 删除红
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF30A46C), // 完成绿
    warning: Color(0xFFB45309), // 提醒橙（白底可读）
    info: Color(0xFF3E63DD), // 信息蓝
    overdue: Color(0xFFC52A30), // 逾期
    today: Color(0xFF1D5FD1), // 今天
    future: Color(0xFF5F6368), // 未来
    completed: Color(0xFF666666), // 已完成
  );

  /// 暗色模式（后续解锁；Phase 0 先置 stub）
  static const dark = AppColors(
    background: TodoLayoutTokens.darkCanvas,
    surface: TodoLayoutTokens.darkSurface,
    ink: Color(0xFFFFFFFF),
    foreground: Color(0xFFF5F5F5),
    muted: Color(0xFF3A3A3A),
    mutedForeground: Color(0xFFA1A1A1),
    border: TodoLayoutTokens.darkDivider,
    accent: Color(0xFF4D8FFA),
    accentForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFE5484D),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF30A46C),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF3E63DD),
    overdue: Color(0xFFFF6B70),
    today: Color(0xFF4D8FFA),
    future: Color(0xFFA1A1A1),
    completed: Color(0xFFB0B0B0),
  );
}

/// 颜色 ThemeExtension（便于 `Theme.of(context).extension<AppThemeExtension>()`）。
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension(this.colors);
  final AppColors colors;

  @override
  ThemeExtension<AppThemeExtension> copyWith({AppColors? colors}) =>
      AppThemeExtension(colors ?? this.colors);

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
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

/// 文字层级令牌（A 路线排版收敛）。
///
/// 全局 [ThemeData.textTheme] 在 app.dart 接管兜底；业务内联 fontSize
/// 应逐步收敛到这里，避免 10/11/13/13.5/15/17 散落漂移。
///
/// 层级阶梯（一眼可辨，而不是挤在 11-13 之间）：
/// - display 18/24：空状态大标题、页面主标题
/// - title   15/22：任务标题、面板标题
/// - subtitle 14/20：区块标题、弹层标题
/// - body    13/18：正文、侧栏行、列表项
/// - label   12/16：字段标签、分组标题（w600 拉开与正文的对比）
/// - caption 11/15：元数据、时间戳、徽章文字
abstract final class AppTextStyles {
  // ---------- display ----------

  /// 空状态大标题 / 页面主标题。
  static const TextStyle display = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  // ---------- title ----------

  /// 任务标题 / 面板标题（15px / 行高 22）。
  static const TextStyle taskTitle = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
  );

  /// 完成态任务标题（同层级、灰化 + 划线）。
  static const TextStyle taskTitleCompleted = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  /// 面板 / 弹层标题（w600，比正文明显重）。
  static const TextStyle panelTitle = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
  );

  /// 字段值（详情面板的输入框文字等），与正文同层但行高更舒朗。
  static const TextStyle fieldValue = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  // ---------- subtitle ----------

  /// 区块标题（详情面板「截止时间」「清单」这类分区名）。
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  /// 弹层 / 空状态副文案。
  static const TextStyle emptySubtitle = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  // ---------- body ----------

  /// 侧栏行 / 正文（13px）。
  static const TextStyle body = TextStyle(fontSize: 13, height: 1.35);

  /// 侧栏行选中态（w600 与未选中拉开）。
  static const TextStyle bodySelected = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  // ---------- label ----------

  /// 字段标签（详情面板「标题」「描述」这类小标签）。
  static const TextStyle fieldLabel = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// 分组标题（中文小字，不加 letterSpacing / 大写化）。
  static const TextStyle groupHeader = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  // ---------- caption ----------

  /// 元数据 / 时间戳（11px）。
  static const TextStyle metadata = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  /// 徽章 / 计数文字（11px w600，用于选中与未选中的数字对比）。
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  /// 空状态标题（保留旧名，等价于 [display]）。
  static const TextStyle emptyTitle = display;
}

/// 阴影令牌（浅色下按层级给质感，暗色下由调用方降级为边框）。
class AppShadows {
  static List<BoxShadow> card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 1),
          ),
        ];

  static List<BoxShadow> elevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ];

  static List<BoxShadow> popup(BuildContext context) => elevated(context);
}
