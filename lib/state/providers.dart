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
import '../core/task/task_swipe_preferences.dart';
import '../core/time/task_time_formatter.dart';
import '../core/time/task_time_mode.dart';
import '../core/time/week_start.dart';
import '../features/shell/sidebar_hierarchy.dart';
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
import 'repositories/task_grouping_preference_repository.dart';
import 'repositories/task_sort_preference_repository.dart';
import 'repositories/task_swipe_preference_repository.dart';
import 'repositories/sidebar_visibility_repository.dart';
import 'repositories/calendar_info_preference_repository.dart';
import 'repositories/task_view_action_repository.dart';
import 'repositories/timezone_preference_repository.dart';
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
      Future.microtask(
        () => ref.read(sessionProvider.notifier).expireSession(),
      );
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

/// 侧栏「显示过滤器」偏好流（嘀嗒《…05-过滤器：随心所欲筛选你想看的任务.md》:29/:33）。
///
/// 三态口径与上面那条完全一致，差别只在这一档读的是 `showFilters` 键。
final sidebarShowFiltersProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(sidebarVisibilityRepositoryProvider);
  if (repo == null) {
    return Stream.value(SidebarVisibilityRepository.defaultShowFilters);
  }
  return repo.watchFilters();
});

/// 「设置 > 功能模块」某一档是否开启（specs/107 / FL #574）。
///
/// 读法与 `sidebarShowFiltersProvider` 同一条：仓储没就绪按默认「开」，消费侧
/// `valueOrNull ?? default` 兜底 ⇒ 默认像素与今天一致，不动黄金基线。
final featureModuleProvider = StreamProvider.family<bool, TodoFeatureModule>((
  ref,
  module,
) {
  final repo = ref.watch(sidebarVisibilityRepositoryProvider);
  if (repo == null) {
    return Stream.value(SidebarVisibilityRepository.defaultFeatureEnabled);
  }
  return repo.watchFeature(module);
});

/// 改键覆盖表（specs/109 / FL #579 面③，嘀嗒《08-桌面快捷键.md》:26「可以修改」）。
///
/// 键 = 动作枚举名，值 = 组合键规范串；仓储没就绪或没改过 ⇒ 空表 ⇒
/// 全部走 `todo_shortcut_registry.dart` 里的默认键位，默认行为与今天一致。
/// 兜底口径与 `featureModuleProvider` 同一套（`valueOrNull ?? 默认`），
/// 因为这里"没读到"与"没改过"本来就是同一个意思：都用默认键位。
final shortcutOverridesProvider = StreamProvider<Map<String, String>>((ref) {
  final repo = ref.watch(sidebarVisibilityRepositoryProvider);
  if (repo == null) {
    return Stream.value(const <String, String>{});
  }
  return repo.watchShortcuts();
});

/// 智能清单三态流（specs/103）。缺键 = 「显示」，消费侧兜底；
/// 导航行口径与 showFilters 一致：晚一帧不出现比整列跳格可取。
final sidebarSmartListStatesProvider =
    StreamProvider<Map<String, SmartListVisibility>>((ref) {
      final repo = ref.watch(sidebarVisibilityRepositoryProvider);
      if (repo == null) {
        return Stream.value(const <String, SmartListVisibility>{});
      }
      return repo.watchSmartListStates();
    });

final tagRepositoryProvider = Provider<TagRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TagRepository(db, queue);
});

/// 任务-标签索引。筛选条件带标签时，列表与预览都靠它求值；
/// 流出错时 `valueOrNull` 仍留着上一份好数据（不因为读失败就把已加载的任务清空）。
final taskTagIndexProvider = StreamProvider<Map<String, Set<String>>>((ref) {
  final repo = ref.watch(tagRepositoryProvider);
  if (repo == null) return Stream.value(const <String, Set<String>>{});
  return repo.watchTagIndex();
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

final taskGroupingPreferenceRepositoryProvider =
    Provider<TaskGroupingPreferenceRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return TaskGroupingPreferenceRepository(db, queue);
    });

/// 「设置 → 日期与时间 → 时区」总开关的仓储（specs/055 / FL #368）。
final timezonePreferenceRepositoryProvider =
    Provider<TimezonePreferenceRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return TimezonePreferenceRepository(db, queue);
    });

/// 当前时区能力的开关状态。无库（未登录/未就绪）时按「开」处理，
/// 与仓储自己的"无记录即开"同一口径，避免离线首屏把既有能力藏掉。
final timezoneEnabledProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(timezonePreferenceRepositoryProvider);
  if (repo == null) return Stream.value(true);
  return repo.watch();
});

final calendarInfoPreferenceRepositoryProvider =
    Provider<CalendarInfoPreferenceRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return CalendarInfoPreferenceRepository(db, queue);
    });

/// 一年节假日/调休表（`GET /todo/calendar/holidays`；specs/125）。
final calendarHolidaysProvider = FutureProvider.autoDispose
    .family<List<CalendarHoliday>, int>((ref, year) async {
      final api = ref.watch(todoApiProvider).calendarInfo;
      return api.holidays(year: year);
    });

/// 一段日期区间的农历表（按天打 `/lunar-date`，调用方按月缓存）。
final calendarLunarMonthProvider = FutureProvider.autoDispose
    .family<Map<DateTime, CalendarLunarDate>, DateTime>((
      ref,
      firstOfMonth,
    ) async {
      final api = ref.watch(todoApiProvider).calendarInfo;
      final daysInMonth = DateTime(
        firstOfMonth.year,
        firstOfMonth.month + 1,
        0,
      ).day;
      final result = <DateTime, CalendarLunarDate>{};
      for (var day = 1; day <= daysInMonth; day++) {
        final date = DateTime(firstOfMonth.year, firstOfMonth.month, day);
        final lunar = await api.lunarDate(date);
        if (lunar != null) result[date] = lunar;
      }
      return result;
    });

final calendarInfoFlagsProvider = StreamProvider.autoDispose<CalendarInfoFlags>(
  (ref) =>
      ref.watch(calendarInfoPreferenceRepositoryProvider)?.watch() ??
      const Stream<CalendarInfoFlags>.empty(),
);

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

/// 「设置 → 滑动操作」自定义配置的仓储（FL #601，矩阵 #14 面⑦）。
final taskSwipePreferenceRepositoryProvider =
    Provider<TaskSwipePreferenceRepository?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final queue = ref.watch(syncChangeQueueProvider);
      if (db == null || queue == null) return null;
      return TaskSwipePreferenceRepository(db, queue);
    });

/// 当前滑动档位。无库（未登录/未就绪）时给原文默认档，
/// 与 `weekStartProvider` 同一口径：首屏不等库，读失败时 `valueOrNull` 兜默认。
final taskSwipePreferencesProvider = StreamProvider<TaskSwipePreferences>((
  ref,
) {
  final repository = ref.watch(taskSwipePreferenceRepositoryProvider);
  if (repository == null) {
    return Stream.value(TaskSwipePreferences.defaults);
  }
  return repository.watch();
});

/// 滑动档位的读法：首值未到或读失败退回默认档，与 `resolveWeekStartFirstDay` 同形。
TaskSwipePreferences resolveTaskSwipePreferences(
  AsyncValue<TaskSwipePreferences> value,
) => value.valueOrNull ?? TaskSwipePreferences.defaults;

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

/// 同一张清单里**所有子级任务**（任意层级）。清单页的顶层流仍是 [tasksByListProvider]，
/// 这条只用来把子任务铺成行（嘀嗒《…06-多级任务.md》:78/:86 的展开/收起）。
/// 分成两条流而不是"一条流里再筛"：筛选、计数、看板/时间线那些面的既有口径都是
/// 「顶层任务 = 列表项」，把子级混进那条流会顺带改掉它们的语义。
final subtasksByListProvider = StreamProvider.family<List<TodoTask>, String>((
  ref,
  listId,
) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchSubtasksByList(listId);
});

/// 跨清单的全部子级任务：智能清单（「今天」「全部」……）的数据源是 [allTasksStreamProvider]
/// （只看顶层），树要在那一面也成立就得配一条同形状的子级流。
final allSubtasksStreamProvider = StreamProvider<List<TodoTask>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return const Stream<List<TodoTask>>.empty();
  return repo.watchAllSubtasks();
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

/// 清单 → 「它所在文件夹以及全部祖先」的索引，供「文件夹」筛选条件求值（FL Issue #333，
/// 口径与 zh-cloud-service Issue #344 同轮对齐：选父文件夹＝选它整棵子树）。
/// 用 `folderLocalId`（本地主键）而不是 `folderId`（服务端 id）：离线建的文件夹还没有
/// 服务端 id，用后者这类文件夹根本筛不了；也与 `TaskFilter.listId` 的本地口径一致。
/// 任一来源流还没发值时返回 null，让调用方去等 —— 只按直属算的那张图会把父文件夹条件
/// 读成「零命中」，正是本轮要修的静默少给，所以不能拿它当"已就位"。
final listFolderIndexProvider = Provider<Map<String, Set<String>>?>((ref) {
  final lists = ref.watch(listsStreamProvider).valueOrNull;
  if (lists == null) return null;
  final folders = ref.watch(foldersStreamProvider).valueOrNull;
  if (folders == null) return null;
  final parentOf = {for (final folder in folders) folder.id: folder.parentId};
  return {
    for (final list in lists)
      if (list.folderLocalId != null)
        list.id: folderAndAncestors(list.folderLocalId!, parentOf),
  };
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

/// 文件夹本地主键 → 服务端 id，供「已保存过滤器」写 `folderIds`（FL Issue #527）。
///
/// **还没发值时返回 null**，不给空表：空表会被读成「这个文件夹没有服务端 id」，
/// 用户看到的点名就成了假话（真正的原因是索引还没就绪，稍后再保存就好）。
final folderServerIdIndexProvider = Provider<Map<String, int>?>((ref) {
  final folders = ref.watch(foldersStreamProvider).valueOrNull;
  if (folders == null) return null;
  return {
    for (final folder in folders)
      if (folder.serverId != null) folder.id: folder.serverId!,
  };
});

/// 同一个索引的反向：服务端 id → 本地主键，供套用已保存过滤器时还原 `folderId`。
/// 同样在索引未就绪时返回 null，调用方据此判「本机暂不支持套用」而不是套成不限文件夹。
final folderLocalIdByServerIdProvider = Provider<Map<int, String>?>((ref) {
  final index = ref.watch(folderServerIdIndexProvider);
  if (index == null) return null;
  return {for (final e in index.entries) e.value: e.key};
});

/// 标签列表 stream。
final tagsStreamProvider = StreamProvider<List<TodoTag>>((ref) {
  final repo = ref.watch(tagRepositoryProvider);
  if (repo == null) return const Stream<List<TodoTag>>.empty();
  return repo.watchAll();
});

/// 任务统计（all / inbox / today / tomorrow / upcoming / assignToMe），供 Sidebar 徽章计数。
/// 完全基于本地 Drift watchAll()，离线可用。
/// 「在智能清单中显示」关掉的清单（specs/105）不参与任何一档计数，
/// 与智能清单页面的排除闸门同一口径。
final taskStatsProvider = StreamProvider<TaskStats>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return Stream.value(TaskStats.empty);
  final now = ref.watch(currentDateTimeProvider)();
  final currentUserId = ref.watch(sessionProvider)?.userId;
  final hiddenListIds = ref.watch(listsStreamProvider).valueOrNull == null
      ? const <String>{}
      : {
          for (final list in ref.watch(listsStreamProvider).valueOrNull!)
            if (!list.showInSmartList) list.id,
        };
  return repo.watchAll().map((tasks) {
    final visible = hiddenListIds.isEmpty
        ? tasks
        : tasks.where((t) => !hiddenListIds.contains(t.listId)).toList();
    return TaskStats.fromTasks(
      visible,
      now: now,
      assigneeUserId: currentUserId,
    );
  });
});

/// 轻量任务计数集合（Sidebar 徽章用）。
/// - all: 全部顶层未完成任务
/// - inbox: listId == kInboxListId 的未完成任务
/// - today: 截止日 = 今天 的未完成任务
/// - upcoming: 截止日在 (今天, +7天] 的未完成任务
/// - assignToMe: 指派给当前用户的未完成任务（嘀嗒《02-用清单管理任务》:21）
class TaskStats {
  const TaskStats(
    this.all,
    this.inbox,
    this.today,
    this.tomorrow,
    this.upcoming,
    this.assignToMe,
  );
  final int all;
  final int inbox;
  final int today;
  final int tomorrow;
  final int upcoming;
  final int assignToMe;

  static const empty = TaskStats(0, 0, 0, 0, 0, 0);

  static TaskStats fromTasks(
    List<TodoTask> tasks, {
    DateTime? now,
    int? assigneeUserId,
  }) {
    var all = 0, inbox = 0, today = 0, tomorrow = 0, upcoming = 0;
    var assignToMe = 0;
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
      // 没会话（assigneeUserId == null）时这一档恒 0：绝不把"未指派"当成"给我"。
      if (assigneeUserId != null && t.assigneeUserId == assigneeUserId) {
        assignToMe++;
      }
      final dueAt = t.dueAt;
      final due = dueAt == null
          ? null
          : taskWallClockDateTime(
              dueAt,
              allDay: t.allDay,
              mode: TaskTimeMode.fromWire(t.timeMode),
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
    return TaskStats(all, inbox, today, tomorrow, upcoming, assignToMe);
  }
}
