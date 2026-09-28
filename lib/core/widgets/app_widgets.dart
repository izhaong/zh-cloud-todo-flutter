import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/brand_colors.dart';
import '../theme/todo_layout_tokens.dart';

/// 品牌化卡片：替换 Material 默认 Card。
/// 圆角 12 + 细微边框 + 底阴影，背景纯白（surface）。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
    this.hovered = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: hovered
              ? colors.accent.withValues(alpha: 0.28)
              : colors.border,
          width: hovered ? 0.9 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hovered ? 0.06 : 0.03),
            blurRadius: hovered ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: card,
    );
  }
}

/// 品牌化圆形 checkbox（带填充动画），替换 Material 默认 Checkbox。
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.visualSize = 22,
    this.tapTargetSize = 22,
    this.strokeWidth = 1.5,
  }) : assert(visualSize > 0),
       assert(tapTargetSize >= visualSize),
       assert(strokeWidth > 0);

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double visualSize;
  final double tapTargetSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final toggle = onChanged == null ? null : () => onChanged!(!value);
    return Semantics(
      key: const Key('app-checkbox-semantics'),
      checked: value,
      enabled: onChanged != null,
      onTap: toggle,
      child: SizedBox.square(
        dimension: tapTargetSize,
        child: InkWell(
          onTap: toggle,
          excludeFromSemantics: true,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedContainer(
              duration: TodoLayoutTokens.stateTransitionDurationFor(context),
              curve: Curves.easeOutCubic,
              width: visualSize,
              height: visualSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? colors.accent : Colors.transparent,
                border: Border.all(
                  color: value ? colors.accent : colors.mutedForeground,
                  width: strokeWidth,
                ),
              ),
              child: value
                  ? Icon(
                      Icons.check,
                      size: visualSize * 7 / 11,
                      color: colors.accentForeground,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 品牌化按钮（主按钮）：圆角 8，accent 背景。
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.danger = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final bg = danger ? colors.destructive : colors.accent;
    final fg = danger ? colors.destructiveForeground : colors.accentForeground;
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : (icon == null ? const SizedBox.shrink() : Icon(icon)),
      label: child,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

/// 品牌化标签/芯片（彩色日期/优先级）。
class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final c = color ?? colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// 品牌化标签块（标签 chips，多选/筛选场景）。
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: colors.accent.withValues(alpha: 0.12),
      checkmarkColor: colors.accent,
      labelStyle: TextStyle(
        color: selected ? colors.accent : colors.foreground,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? colors.accent : colors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

/// 空状态组件（CustomPainter 抽象插画避版权）。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 抽象品牌插画（.CustomPainter 圆环 + 勾选占位）
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 40,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.mutedForeground),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 刷新失败但页面仍持有上一次数据时的可见提示（#375）。
/// 用 `liveRegion` 让读屏在数据保留、界面其余部分未变的情况下也能播报这条新增提示。
class AppRefreshFailedHint extends StatelessWidget {
  const AppRefreshFailedHint({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('app-refresh-failed-hint'),
        color: colors.muted,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.wifi_tethering_error,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
