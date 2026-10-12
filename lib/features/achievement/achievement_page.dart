import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/efficiency_api.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';

/// 会员成就墙：只读展示服务端计算的成就值、等级与勋章状态。
class AchievementPage extends ConsumerWidget {
  const AchievementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wall = ref.watch(achievementWallProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('成就与勋章')),
      body: wall.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AppEmptyState(
          title: '成就数据加载失败',
          subtitle: '请检查网络后重试。',
          action: AppButton(
            key: const ValueKey('achievement-wall-retry'),
            icon: Icons.refresh,
            onPressed: () => ref.invalidate(achievementWallProvider),
            child: const Text('重试'),
          ),
        ),
        data: (value) => RefreshIndicator(
          onRefresh: () => ref.refresh(achievementWallProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _LevelCard(wall: value),
              const SizedBox(height: 20),
              _BadgeSection(
                title: '已获得 · ${value.earnedBadges.length}',
                badges: value.earnedBadges,
                earned: true,
              ),
              const SizedBox(height: 20),
              _BadgeSection(
                title: '未解锁 · ${value.lockedBadges.length}',
                badges: value.lockedBadges,
                earned: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.wall});

  final AchievementWallDto wall;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final remaining = wall.nextLevelRequired - wall.totalScore;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: colors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv${wall.level}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${wall.totalScore} 成就值',
                      style: TextStyle(color: colors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: wall.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: colors.muted,
          ),
          const SizedBox(height: 8),
          Text(
            wall.isMaxLevel
                ? '已达到当前最高等级'
                : '距离 ${wall.nextLevelName} 还需 $remaining',
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  const _BadgeSection({
    required this.title,
    required this.badges,
    required this.earned,
  });

  final String title;
  final List<AchievementBadgeDto> badges;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (badges.isEmpty)
          AppCard(
            child: Text(
              earned ? '完成任务与专注目标后，勋章会出现在这里。' : '全部勋章都已解锁。',
              style: TextStyle(color: colors.mutedForeground),
            ),
          )
        else
          for (var index = 0; index < badges.length; index++) ...[
            _BadgeCard(badge: badges[index], earned: earned),
            if (index < badges.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.earned});

  final AchievementBadgeDto badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final color = earned ? colors.warning : colors.mutedForeground;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: earned ? 0.16 : 0.1),
            child: Icon(
              earned ? _badgeIcon(badge.badgeType) : Icons.lock_outline,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: earned ? colors.foreground : colors.mutedForeground,
                  ),
                ),
                if (badge.description.isNotEmpty)
                  Text(
                    badge.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          if (earned) Icon(Icons.check_circle, color: colors.success, size: 20),
        ],
      ),
    );
  }
}

IconData _badgeIcon(int type) => switch (type) {
  1 => Icons.flag_outlined,
  2 => Icons.local_fire_department_outlined,
  3 => Icons.timer_outlined,
  4 => Icons.task_alt_outlined,
  5 => Icons.calendar_month_outlined,
  _ => Icons.emoji_events_outlined,
};
