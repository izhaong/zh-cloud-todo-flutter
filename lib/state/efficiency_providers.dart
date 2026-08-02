import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/efficiency_api.dart';
import '../features/habit/habit_repository.dart';
import 'providers.dart';

final pomodoroApiProvider = Provider<PomodoroApi>((ref) {
  return PomodoroApi(ref.watch(apiClientProvider).raw);
});

final countdownApiProvider = Provider<CountdownApi>((ref) {
  return CountdownApi(ref.watch(apiClientProvider).raw);
});

final achievementApiProvider = Provider<AchievementApi>((ref) {
  return AchievementApi(ref.watch(apiClientProvider).raw);
});

final quadrantApiProvider = Provider<QuadrantApi>((ref) {
  return QuadrantApi(ref.watch(apiClientProvider).raw);
});

final quadrantRulesProvider = FutureProvider.autoDispose<List<QuadrantRuleDto>>(
  (ref) {
    return ref.watch(quadrantApiProvider).listRules();
  },
);

final quadrantBoardProvider = FutureProvider.autoDispose
    .family<Map<String, Set<int>>, int>((ref, ruleId) {
      return ref.watch(quadrantApiProvider).board(ruleId: ruleId);
    });

final reminderActionApiProvider = Provider<ReminderActionApi>((ref) {
  return ReminderActionApi(ref.watch(apiClientProvider).raw);
});

/// M11-B4 习惯仓库（纯后端驱动）。
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(apiClientProvider).raw);
});

/// 当前活跃番茄会话 id（null 表示未在专注）。
final activePomodoroIdProvider = StateProvider<int?>((ref) => null);

/// 倒数日列表。
final countdownsProvider = FutureProvider.autoDispose<List<CountdownDto>>((
  ref,
) async {
  final api = ref.watch(countdownApiProvider);
  return api.list();
});

/// 当前会员的成就值、等级与勋章墙。
final achievementWallProvider = FutureProvider.autoDispose<AchievementWallDto>((
  ref,
) {
  return ref.watch(achievementApiProvider).wall();
});

/// 我的习惯列表。
final myHabitsProvider = FutureProvider.autoDispose<List<HabitDto>>((
  ref,
) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.listMine();
});

/// 习惯统计。
final habitStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.overviewStats();
});
