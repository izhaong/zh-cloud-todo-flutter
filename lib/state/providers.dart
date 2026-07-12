import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/api/sync_api.dart';
import '../core/api/todo_api.dart';
import '../core/db/app_database.dart';
import '../core/sync/sync_change_queue.dart';
import '../core/sync/sync_coordinator.dart';
import '../state/session_state.dart';
import 'repositories/folder_repository.dart';
import 'repositories/activity_repository.dart';
import 'repositories/list_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/template_repository.dart';
import 'repositories/task_repository.dart';

/// UI-facing clock. Production reads the current instant on each rebuild;
/// deterministic widget/golden fixtures override the callback explicitly.
final currentDateTimeProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// ----- API 客户端 --------------------------------------------------------

/// 业务 API 客户端：随 [sessionProvider] 变化重建，始终携带最新 token。
/// token / tenantId 均从会话取（tenantId 默认回退 ApiConfig.defaultTenantId）。
final apiClientProvider = Provider<ApiClient>((ref) {
  ref.watch(sessionProvider);
  return ApiClient(
    tokenProvider: () => ref.read(sessionProvider)?.accessToken ?? '',
    tenantIdProvider: () =>
        ref.read(sessionProvider)?.tenantId ?? ApiConfig.defaultTenantId,
    onUnauthorized: () {
      Future.microtask(() => ref.read(sessionProvider.notifier).signOut());
    },
  );
});

/// 直连 REST 容器（TaskRestApi/ChecklistApi/FolderApi/NlpApi/TagApi 的统一入口），
/// 调用方通过 `ref.read(todoApiProvider).<subApi>` 取任一子 helper。
final todoApiProvider = Provider<TodoRestApi>((ref) {
  return TodoRestApi(ref.watch(apiClientProvider));
});

/// ----- 本地库（多租户隔离）-----------------------------------------------

/// 设备唯一标识（持久化，跨启动稳定，供 sync `device_id` 用）。
final deviceIdProvider = FutureProvider<String>((ref) async {
  final store = ref.watch(sessionStoreProvider);
  return store.readOrCreateDeviceId(generate: () => const Uuid().v4());
});

/// 按 `tenantId + userId` 构建用户专属本地库；会话重建时跟随重建。
/// 未登录（会话 null）时返回 null，下游仓库/同步可选置空。
final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  ref.watch(sessionProvider);
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final db = AppDatabase.forUser(
    tenantId: session.tenantId,
    userId: session.userId,
  );
  ref.onDispose(db.close);
  return db;
});

/// 同步变更队列（依赖用户本地库）。
final syncChangeQueueProvider = Provider<SyncChangeQueue?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return SyncChangeQueue(db);
});

/// ----- 各领域仓库 ---------------------------------------------------------

final listRepositoryProvider = Provider<ListRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return ListRepository(db, queue);
});

final folderRepositoryProvider = Provider<FolderRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return FolderRepository(db, queue);
});

final tagRepositoryProvider = Provider<TagRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TagRepository(db, queue);
});

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TaskRepository(db, queue);
});

final activityRepositoryProvider = Provider<ActivityRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return ActivityRepository(db, ref.watch(todoApiProvider).activity);
});

final templateRepositoryProvider = Provider<TemplateRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TemplateRepository(db, queue);
});

// --- 同步 ---------------------------------------------------------------

final syncApiProvider = Provider<SyncApi?>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull;
  final session = ref.watch(sessionProvider);
  if (deviceId == null || session == null) return null;
  return SyncApi(
    ref.watch(apiClientProvider),
    clientId: 'flutter',
    deviceId: deviceId,
  );
});

final syncCoordinatorProvider = Provider<SyncCoordinator?>((ref) {
  final syncApi = ref.watch(syncApiProvider);
  final db = ref.watch(appDatabaseProvider);
  if (syncApi == null || db == null) return null;
  return SyncCoordinator(
    db: db,
    api: syncApi,
    todoApi: ref.watch(apiClientProvider),
  );
});

// --- 任务 / 清单 / 文件夹 / 标签流 -----------------------------------------

/// 任务列表 stream（顶层任务，按 listId 过滤）。[listId] 本地 UUID。
final tasksByListProvider = StreamProvider.family<List<TodoTask>, String>((
  ref,
  listId,
) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchTopLevelByList(listId);
});

/// 清单列表 stream（不含智能清单）。
final listsStreamProvider = StreamProvider<List<TodoList>>((ref) {
  final repo = ref.watch(listRepositoryProvider);
  if (repo == null) return const Stream<List<TodoList>>.empty();
  return repo.watchAll();
});

/// 用户保存的智能清单 stream（`smart:` 前缀）。
final smartListsStreamProvider = StreamProvider<List<TodoList>>((ref) {
  final repo = ref.watch(listRepositoryProvider);
  if (repo == null) return const Stream<List<TodoList>>.empty();
  return repo.watchSmartLists();
});

/// 文件夹列表 stream。
final foldersStreamProvider = StreamProvider<List<TodoFolder>>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  if (repo == null) return const Stream<List<TodoFolder>>.empty();
  return repo.watchAll();
});

/// 标签列表 stream。
final tagsStreamProvider = StreamProvider<List<TodoTag>>((ref) {
  final repo = ref.watch(tagRepositoryProvider);
  if (repo == null) return const Stream<List<TodoTag>>.empty();
  return repo.watchAll();
});

/// 任务统计（all / inbox / today / upcoming），供 Sidebar 徽章计数。
/// 完全基于本地 Drift watchAll()，离线可用。
final taskStatsProvider = StreamProvider<TaskStats>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return Stream.value(TaskStats.empty);
  final now = ref.watch(currentDateTimeProvider)();
  return repo.watchAll().map((tasks) => TaskStats.fromTasks(tasks, now: now));
});

/// 轻量任务计数集合（Sidebar 徽章用）。
/// - all: 全部顶层未完成任务
/// - inbox: listId == kInboxListId 的未完成任务
/// - today: 截止日 = 今天 的未完成任务
/// - upcoming: 截止日在 (今天, +7天] 的未完成任务
class TaskStats {
  const TaskStats(this.all, this.inbox, this.today, this.upcoming);
  final int all;
  final int inbox;
  final int today;
  final int upcoming;

  static const empty = TaskStats(0, 0, 0, 0);

  static TaskStats fromTasks(List tasks, {DateTime? now}) {
    var all = 0, inbox = 0, today = 0, upcoming = 0;
    final effectiveNow = now ?? DateTime.now();
    final todayStart = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekEnd = todayStart.add(const Duration(days: 7));
    for (final t in tasks) {
      if (t.completed || t.cancelled) continue;
      all++;
      if (t.listId == 'inbox') inbox++;
      final due = t.dueAt;
      if (due != null) {
        if (due.isBefore(todayEnd) && !due.isBefore(todayStart)) {
          today++;
        } else if (due.isAfter(todayStart) && !due.isAfter(weekEnd)) {
          upcoming++;
        }
      }
    }
    return TaskStats(all, inbox, today, upcoming);
  }
}
