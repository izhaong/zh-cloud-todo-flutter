import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 登录页的 Todo 品牌表达；只负责展示，不读取认证或会话状态。
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppThemeExtension>()?.colors;
    final accent = colors?.accent ?? theme.colorScheme.primary;
    final muted = colors?.mutedForeground ?? theme.colorScheme.onSurfaceVariant;

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BrandMark(accent: accent, compact: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todo',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '把任务、日程与专注留在一个地方',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Todo，让今天的任务更清楚',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  _BrandMark(accent: accent, compact: false),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Todo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                '把今天安排得更清楚',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '从捕捉想法到完成回顾，随时回到真正重要的事情。',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: muted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                '今日节奏',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RhythmItem(
                icon: Icons.check_rounded,
                title: '捕捉今天的想法',
                state: '已完成',
                accent: accent,
                muted: muted,
              ),
              _RhythmItem(
                icon: Icons.radio_button_checked,
                title: '完成本周计划',
                state: '进行中',
                accent: accent,
                muted: muted,
              ),
              _RhythmItem(
                icon: Icons.circle_outlined,
                title: '留一点时间做回顾',
                state: '稍后',
                accent: accent,
                muted: muted,
                showConnector: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.accent, required this.compact});

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 44.0;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: compact ? 24 : 28,
          ),
        ),
      ),
    );
  }
}

class _RhythmItem extends StatelessWidget {
  const _RhythmItem({
    required this.icon,
    required this.title,
    required this.state,
    required this.accent,
    required this.muted,
    this.showConnector = true,
  });

  final IconData icon;
  final String title;
  final String state;
  final Color accent;
  final Color muted;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(icon, size: 20, color: accent),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: accent.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? 20 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.bodyLarge),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    state,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
