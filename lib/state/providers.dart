import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/api/sync_api.dart';
import '../core/api/todo_api.dart';
import '../core/db/app_database.dart';
import '../core/notification/local_notification_service.dart';
import '../core/notification/reminder_notification_poller.dart';
import '../core/sync/sync_change_queue.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/time/task_time_formatter.dart';
import '../core/time/week_start.dart';
import '../state/session_state.dart';
import 'repositories/board_preference_repository.dart';
import 'repositories/filter_repository.dart';
import 'repositories/folder_repository.dart';
import 'repositories/activity_repository.dart';
import 'repositories/list_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/recommendation_repository.dart';
import 'repositories/reminder_dispatch_action_repository.dart';
import 'repositories/reminder_inbox_repository.dart';
import 'repositories/reminder_repository.dart';
import 'repositories/repeat_rule_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/task_batch_edit_repository.dart';
import 'repositories/task_query_repository.dart';
import 'repositories/template_repository.dart';
import 'repositories/task_capture_defaults_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/task_section_repository.dart';
import 'repositories/task_sort_preference_repository.dart';
import 'repositories/sidebar_visibility_repository.dart';
import 'repositories/task_view_action_repository.dart';
import 'repositories/week_start_preference_repository.dart';
import 'repositories/summary_repository.dart';

/// UI-facing clock. Production reads the current instant on each rebuild;
/// deterministic widget/golden fixtures override the callback explicitly.
final currentDateTimeProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// 网络状态变化流。测试和预览夹具可覆盖为空流，避免订阅真实平台通道。
final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// 当前连接状态读取，与变化流分开注入，以覆盖离线冷启动后的首次联网恢复。
final connectivityInitialStateProvider =
    Provider<Future<List<ConnectivityResult>> Function()>(
      (ref) => Connectivity().checkConnectivity,
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

typedef CalendarEventWindow = ({DateTime start, DateTime end});

/// 订阅日历是服务端只读投影，不写入本地任务库。
final externalCalendarEventsProvider = FutureProvider.autoDispose
    .family<List<CalendarExternalEvent>, CalendarEventWindow>((ref, window) {
      return ref
          .watch(todoApiProvider)
          .calSubscription
          .events(start: window.start, end: window.end);
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
  const testNamespace = String.fromEnvironment('TODO_E2E_DATABASE_SUFFIX');
  final db = AppDatabase.forUser(
    tenantId: session.tenantId,
    userId: session.userId,
    testNamespace:
        const bool.fromEnvironment('FLUTTER_TEST') && testNamespace.isNotEmpty
        ? testNamespace
        : null,
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

/// 需要用户显式恢复的同步变更。网络失败的 queued 项会按退避自动重试；
/// failed 项保留在本地，供 UI 展示并在用户确认后重新入队。
final failedSyncChangesProvider = StreamProvider<List<TodoSyncChange>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return const Stream<List<TodoSyncChange>>.empty();
  return (db.select(
    db.todoSyncChanges,
  )..where((row) => row.status.equals('failed'))).watch();
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

final sidebarVisibilityRepositoryProvider =
    Provider<SidebarVisibilityRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return SidebarVisibilityRepository(db, queue);
    });

/// 侧栏「显示标签」偏好流（嘀嗒《…04-用标签管理任务.md》:10/:16/:23/:27）。
///
/// 没有仓库（未登录/库未就绪）时按默认「显示」走。消费侧的三态口径（侧栏与设置页同一套读法）：
/// **首值就失败**才回兜底默认；**出过一次值之后失败**要留住那次读到的值（四件套 ③）；
/// **加载中且从未有值**不回兜底 —— 侧栏不画标签区，设置页显示「…」。
final sidebarShowTagsProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(sidebarVisibilityRepositoryProvider);
  if (repo == null) {
    return Stream.value(SidebarVisibilityRepository.defaultShowTags);
  }
  return repo.watch();
});

final tagRepositoryProvider = Provider<TagRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TagRepository(db, queue);
});

final filterRepositoryProvider = Provider<FilterRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return FilterRepository(db, queue);
});

/// 已保存过滤器（本地 Drift 事实源，含服务端 pull 落库的）。
final savedFiltersStreamProvider = StreamProvider<List<TodoFilter>>((ref) {
  final repo = ref.watch(filterRepositoryProvider);
  if (repo == null) return Stream<List<TodoFilter>>.value(const []);
  return repo.watchAll();
});

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TaskRepository(db, queue);
});

final taskSectionRepositoryProvider = Provider<TaskSectionRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TaskSectionRepository(db, queue);
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return ApiNoteRepository(ref.watch(todoApiProvider).note);
});

/// 摘要只读本地任务库；未登录时无库可查，下游按 null 降级为不可生成。
final summaryRepositoryProvider = Provider<SummaryRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return DriftSummaryRepository(db);
});

/// 推荐为只读服务端投影，成功拉取后落入 Drift；不使用 outbox。
final recommendationRepositoryProvider = Provider<RecommendationRepository?>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return RecommendationRepository(
    db,
    ref.watch(todoApiProvider).recommendation,
  );
});

final taskQueryRepositoryProvider = Provider<TaskQueryRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return TaskQueryRepository(db);
});

final taskBatchEditRepositoryProvider = Provider<TaskBatchEditRepository?>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TaskBatchEditRepository(db, queue);
});

final taskViewActionRepositoryProvider = Provider<TaskViewActionRepository?>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TaskViewActionRepository(db, queue);
});

final boardPreferenceRepositoryProvider = Provider<BoardPreferenceRepository?>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return BoardPreferenceRepository(db, queue);
});

final boardPreferenceRecoveryAvailableProvider =
    FutureProvider.family<bool, String>((ref, listId) {
      final repository = ref.watch(boardPreferenceRepositoryProvider);
      if (repository == null) return false;
      return repository.hasRecoverableFailed(listId: listId);
    });

final boardViewPreferenceProvider = StreamProvider.autoDispose
    .family<BoardViewPreference, String>((ref, listId) {
      final repository = ref.watch(boardPreferenceRepositoryProvider);
      if (repository == null) {
        return Stream.value(const BoardViewPreference());
      }
      return repository.watch(listId);
    });

final reminderRepositoryProvider = Provider<ReminderRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return ReminderRepository(db, queue);
});

final repeatRuleRepositoryProvider = Provider<RepeatRuleRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return RepeatRuleRepository(db, queue);
});

final reminderDispatchActionRepositoryProvider =
    Provider<ReminderDispatchActionRepository?>((ref) {
      final queue = ref.watch(syncChangeQueueProvider);
      if (queue == null) return null;
      return ReminderDispatchActionRepository(queue);
    });

final reminderInboxRepositoryProvider = Provider<ReminderInboxRepository>((
  ref,
) {
  return ReminderInboxRepository(ref.watch(todoApiProvider).reminder);
});

final reminderNotificationPollerProvider =
    Provider<ReminderNotificationPoller?>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final session = ref.watch(sessionProvider);
      if (database == null || session == null) return null;
      final notificationScope = '${session.tenantId}_${session.userId}';
      return ReminderNotificationPoller(
        repository: ref.watch(reminderInboxRepositoryProvider),
        database: database,
        notifications: ref.watch(localNotificationServiceProvider),
        stateStore: SharedPreferencesReminderNotificationStateStore(
          namespace: notificationScope,
        ),
        notificationScope: notificationScope,
        now: ref.watch(currentDateTimeProvider),
      );
    });

final taskCaptureDefaultsRepositoryProvider =
    Provider<TaskCaptureDefaultsRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return TaskCaptureDefaultsRepository(db, queue);
    });

final taskSortPreferenceRepositoryProvider =
    Provider<TaskSortPreferenceRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return TaskSortPreferenceRepository(db, queue);
    });

final weekStartPreferenceRepositoryProvider =
    Provider<WeekStartPreferenceRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return WeekStartPreferenceRepository(db, queue);
    });

/// 「星期开始于」当前档位。
///
/// FR-7：库未就绪时直接给默认档（Stream.value 立刻进 data），
/// 这样日历/时间线的读法统一是 `valueOrNull ?? default`。首值未到达或
/// 读取报错时 `valueOrNull` 为 null，退回周一，与 develop 既有行为一致；
/// AsyncError 仍带旧值时 `valueOrNull` 保留旧值，不会被兜底盖掉。
/// 「星期开始于」三态读法（FR-7）：有值用值；首值未到或读失败退回默认档（周一）。
///
/// 只用 `valueOrNull`，不用 `when(error:)` —— 后者会把"带旧值的 AsyncError"里的
/// 旧值丢掉（第 74 轮实测）。单独抽出来是因为消费面有两类：一类在 build 里能 watch
/// （日历），一类是纯参数注入（时间线，既有 17 条用例裸 pump 无 ProviderScope）。
int resolveWeekStartFirstDay(AsyncValue<int> value) =>
    value.valueOrNull ?? WeekStart.defaultFirstDay;

final weekStartProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(weekStartPreferenceRepositoryProvider);
  if (repository == null) {
    return Stream.value(WeekStart.defaultFirstDay);
  }
  return repository.watch();
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

/// 全部顶层任务流。专注关联等跨清单选择器只读使用，不直接修改 outbox。
final allTasksStreamProvider = StreamProvider<List<TodoTask>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return const Stream<List<TodoTask>>.empty();
  return repo.watchAll();
});

final taskSectionsByListProvider =
    StreamProvider.family<List<TodoTaskSection>, String>((ref, listId) {
      final repo = ref.watch(taskSectionRepositoryProvider);
      if (repo == null) return const Stream.empty();
      return repo.watchByList(listId);
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

/// 任务统计（all / inbox / today / tomorrow / upcoming），供 Sidebar 徽章计数。
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
  const TaskStats(
    this.all,
    this.inbox,
    this.today,
    this.tomorrow,
    this.upcoming,
  );
  final int all;
  final int inbox;
  final int today;
  final int tomorrow;
  final int upcoming;

  static const empty = TaskStats(0, 0, 0, 0, 0);

  static TaskStats fromTasks(List<TodoTask> tasks, {DateTime? now}) {
    var all = 0, inbox = 0, today = 0, tomorrow = 0, upcoming = 0;
    final effectiveNow = now ?? DateTime.now();
    final todayStart = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final todayEnd = todayStart.add(const Duration(days: 1));
    final tomorrowEnd = todayEnd.add(const Duration(days: 1));
    final weekEndExclusive = todayStart.add(const Duration(days: 8));
    for (final t in tasks) {
      if (t.completed || t.cancelled) continue;
      all++;
      if (t.listId == 'inbox') inbox++;
      final dueAt = t.dueAt;
      final due = dueAt == null
          ? null
          : taskWallClockDateTime(
              dueAt,
              allDay: t.allDay,
              fixedTimezone: t.fixedTimezone,
              timeZone: t.timeZone,
            );
      if (due != null) {
        if (due.isBefore(todayEnd) && !due.isBefore(todayStart)) {
          today++;
        } else if (!due.isBefore(todayEnd) && due.isBefore(tomorrowEnd)) {
          tomorrow++;
          upcoming++;
        } else if (!due.isBefore(tomorrowEnd) &&
            due.isBefore(weekEndExclusive)) {
          upcoming++;
        }
      }
    }
    return TaskStats(all, inbox, today, tomorrow, upcoming);
  }
}
