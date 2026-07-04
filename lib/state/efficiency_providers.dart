import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/efficiency_api.dart';
import '../features/habit/habit_repository.dart';
import 'providers.dart';

final pomodoroApiProvider = Provider<PomodoroApi>((ref) {
  return PomodoroApi(ref.watch(todoApiClientProvider).raw);
});

final countdownApiProvider = Provider<CountdownApi>((ref) {
  return CountdownApi(ref.watch(todoApiClientProvider).raw);
});

final reminderActionApiProvider = Provider<ReminderActionApi>((ref) {
  return ReminderActionApi(ref.watch(todoApiClientProvider).raw);
});

/// M11-B4 习惯仓库（纯后端驱动）。
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(todoApiClientProvider).raw);
});

/// 当前活跃番茄会话 id（null 表示未在专注）。
final activePomodoroIdProvider = StateProvider<int?>((ref) => null);

/// 番茄会话历史（最近 7 天）。
final pomodoroStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(pomodoroApiProvider);
  return api.stats(days: 7);
});

/// 倒数日列表。
final countdownsProvider =
    FutureProvider.autoDispose<List<CountdownDto>>((ref) async {
  final api = ref.watch(countdownApiProvider);
  return api.list();
});

/// 我的习惯列表。
final myHabitsProvider =
    FutureProvider.autoDispose<List<HabitDto>>((ref) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.listMine();
});

/// 习惯统计。
final habitStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.stats();
});