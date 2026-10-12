import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/notification/local_notification_service.dart';
import 'package:zh_cloud_todo_flutter/core/notification/reminder_notification_poller.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_inbox_repository.dart';

void main() {
  test(
    'poll shows each pending due dispatch once through the inbox repository',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 29, 12);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-local',
              serverId: const Value(101),
              name: '收集箱',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-local',
              serverId: const Value(201),
              listId: 'list-local',
              title: '本地任务标题',
              updatedAt: now,
              createdAt: now,
            ),
          );
      final notifications = _RecordingNotificationService();
      final stateStore = _MemoryReminderNotificationStateStore();
      final poller = ReminderNotificationPoller(
        repository: _FakeReminderInboxRepository([
          ReminderInboxItem(
            id: 301,
            taskId: 201,
            taskTitle: '服务端旧标题',
            remindAt: now.subtract(const Duration(minutes: 1)),
          ),
          ReminderInboxItem(
            id: 302,
            taskId: 202,
            taskTitle: '未来提醒',
            remindAt: now.add(const Duration(minutes: 1)),
          ),
          ReminderInboxItem(
            id: 303,
            taskId: 203,
            taskTitle: '已忽略提醒',
            remindAt: now.subtract(const Duration(minutes: 1)),
            status: 'DISMISSED',
          ),
        ]),
        database: db,
        notifications: notifications,
        stateStore: stateStore,
        notificationScope: 'tenant_user',
        now: () => now,
      );

      expect(await poller.poll(), 1);
      final restartedPoller = ReminderNotificationPoller(
        repository: _FakeReminderInboxRepository([
          ReminderInboxItem(
            id: 301,
            taskId: 201,
            taskTitle: '服务端旧标题',
            remindAt: now.subtract(const Duration(minutes: 1)),
          ),
        ]),
        database: db,
        notifications: notifications,
        stateStore: stateStore,
        notificationScope: 'tenant_user',
        now: () => now,
      );
      expect(await restartedPoller.poll(), 0);
      expect(notifications.shown, [
        (
          id: 301,
          title: '本地任务标题',
          body: '到期提醒',
          payload:
              'reminder:301:tenant_user:'
              '${now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch}:'
              '201',
        ),
      ]);
    },
  );

  test(
    'poll persistently schedules, reschedules and cancels future dispatch',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 29, 12);
      final repository = _FakeReminderInboxRepository([
        ReminderInboxItem(
          id: 401,
          taskId: 204,
          taskTitle: '未来任务',
          remindAt: now.add(const Duration(minutes: 5)),
        ),
      ]);
      final notifications = _RecordingNotificationService();
      final stateStore = _MemoryReminderNotificationStateStore();
      final poller = ReminderNotificationPoller(
        repository: repository,
        database: db,
        notifications: notifications,
        stateStore: stateStore,
        notificationScope: 'tenant_user',
        now: () => now,
      );

      expect(await poller.poll(), 0);
      expect(await poller.poll(), 0);
      expect(notifications.scheduled, hasLength(1));
      expect(notifications.scheduled.single.id, 401);

      repository.items = [
        ReminderInboxItem(
          id: 401,
          taskId: 204,
          taskTitle: '未来任务',
          remindAt: now.add(const Duration(minutes: 10)),
        ),
      ];
      await poller.poll();
      expect(notifications.scheduled, hasLength(2));
      expect(
        notifications.scheduled.last.fireAt,
        now.add(const Duration(minutes: 10)),
      );

      repository.items = [
        ReminderInboxItem(
          id: 401,
          taskId: 204,
          taskTitle: '未来任务',
          remindAt: now.add(const Duration(minutes: 10)),
          status: 'DISMISSED',
        ),
      ];
      await poller.poll();
      expect(notifications.cancelled, [401]);
    },
  );

  test('restart keeps an unchanged future dispatch idempotent', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 29, 12);
    final repository = _FakeReminderInboxRepository([
      ReminderInboxItem(
        id: 451,
        taskId: 205,
        taskTitle: '未来任务',
        remindAt: now.add(const Duration(minutes: 5)),
      ),
    ]);
    final notifications = _RecordingNotificationService();
    final stateStore = _MemoryReminderNotificationStateStore();

    await ReminderNotificationPoller(
      repository: repository,
      database: db,
      notifications: notifications,
      stateStore: stateStore,
      notificationScope: 'tenant_user',
      now: () => now,
    ).poll();
    await ReminderNotificationPoller(
      repository: repository,
      database: db,
      notifications: notifications,
      stateStore: stateStore,
      notificationScope: 'tenant_user',
      now: () => now,
    ).poll();

    expect(notifications.scheduled, hasLength(1));
  });

  test('poll cancels stale persisted reminder after app restart', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final notifications = _RecordingNotificationService();
    final stateStore = _MemoryReminderNotificationStateStore();
    notifications.systemSchedules[501] = DateTime.utc(2026, 7, 29, 12, 5);
    final poller = ReminderNotificationPoller(
      repository: _FakeReminderInboxRepository([]),
      database: db,
      notifications: notifications,
      stateStore: stateStore,
      notificationScope: 'tenant_user',
      now: () => DateTime.utc(2026, 7, 29, 12),
    );

    expect(await poller.poll(), 0);
    expect(notifications.cancelled, [501]);
  });

  test('failed system scheduling is retried by the next poll', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 29, 12);
    final notifications = _RecordingNotificationService()
      ..scheduleSucceeds = false;
    final poller = ReminderNotificationPoller(
      repository: _FakeReminderInboxRepository([
        ReminderInboxItem(
          id: 551,
          taskId: 207,
          taskTitle: '重试提醒',
          remindAt: now.add(const Duration(minutes: 5)),
        ),
      ]),
      database: db,
      notifications: notifications,
      stateStore: _MemoryReminderNotificationStateStore(),
      notificationScope: 'tenant_user',
      now: () => now,
    );

    expect(await poller.poll(), 0);
    notifications.scheduleSucceeds = true;
    expect(await poller.poll(), 0);
    expect(notifications.scheduleAttempts, 2);
    expect(notifications.scheduled, hasLength(1));
  });

  test('failed state persistence is retried by the next poll', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 29, 12);
    final stateStore = _MemoryReminderNotificationStateStore()
      ..writeSucceeds = false;
    final poller = ReminderNotificationPoller(
      repository: _FakeReminderInboxRepository([
        ReminderInboxItem(
          id: 575,
          taskId: 208,
          taskTitle: '落盘重试',
          remindAt: now.add(const Duration(minutes: 5)),
        ),
      ]),
      database: db,
      notifications: _RecordingNotificationService(),
      stateStore: stateStore,
      notificationScope: 'tenant_user',
      now: () => now,
    );

    await poller.poll();
    await poller.poll();
    expect(stateStore.writeAttempts, 2);
  });

  test('concurrent polls share one in-flight operation', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 29, 12);
    final blocker = Completer<void>();
    final repository = _FakeReminderInboxRepository([
      ReminderInboxItem(
        id: 601,
        taskId: 206,
        taskTitle: '并发提醒',
        remindAt: now.add(const Duration(minutes: 5)),
      ),
    ])..blocker = blocker;
    final notifications = _RecordingNotificationService();
    final poller = ReminderNotificationPoller(
      repository: repository,
      database: db,
      notifications: notifications,
      stateStore: _MemoryReminderNotificationStateStore(),
      notificationScope: 'tenant_user',
      now: () => now,
    );

    final first = poller.poll();
    final second = poller.poll();
    await Future<void>.delayed(Duration.zero);
    expect(repository.listCalls, 1);
    blocker.complete();
    expect(await Future.wait([first, second]), [0, 0]);
    expect(notifications.scheduled, hasLength(1));
  });
  test('投递通知的通道调用不返回时 poll 有界返回，且不被 in-flight 永久占住', () async {
    // iOS 模拟器实测（10-04 04:57Z，空夹具、真后端）：提醒派发已在第 27 轮命中，
    // 但 poll() 60 秒不返回，旅程一路挂到预算耗尽。修法见 _bounded：
    // 每次系统调用设上限，拿不到就按「系统里没有」处理，下一轮再查。
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 29, 12);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-local',
            serverId: const Value(101),
            name: '收集箱',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-local',
            serverId: const Value(201),
            listId: 'list-local',
            title: '本地任务标题',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final poller = ReminderNotificationPoller(
      repository: _FakeReminderInboxRepository([
        ReminderInboxItem(
          id: 301,
          taskId: 201,
          taskTitle: '到期提醒',
          remindAt: now.subtract(const Duration(minutes: 1)),
        ),
      ]),
      database: db,
      notifications: _HangingScheduleNotificationService(),
      stateStore: _MemoryReminderNotificationStateStore(),
      notificationScope: 'tenant_user',
      now: () => now,
    );

    // 上限是每次调用 10 秒，所以这里给 30 秒的外层判据：
    // 修复前 poll() 永不返回（-1），修复后约 10 秒就有一条可读结果。
    final first = await poller.poll().timeout(
      const Duration(seconds: 30),
      onTimeout: () => -1,
    );
    expect(
      first,
      greaterThanOrEqualTo(0),
      reason: '系统排期查询卡住时 poll 必须有界返回，不能把提醒链路挂死',
    );
    final second = await poller.poll().timeout(
      const Duration(seconds: 30),
      onTimeout: () => -1,
    );
    expect(
      second,
      greaterThanOrEqualTo(0),
      reason: '第一轮卡住后，第二轮不能被 _pollInFlight 永久占住',
    );
  });

  test('固定时间档按设备当地钟点调度，同一触发只排一次', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // 上海 2026-07-15 07:00 = UTC 2026-07-14 23:00；7 月中旬无 DST 切换。
    // now 取两条候选触发的最坏下界之前：设备偏移可到 ±14h，换区前后的触发
    // 瞬间（当地 07:00 与 19:00）都必须落在未来，poller 才会走持久调度分支。
    final remindAt = DateTime.utc(2026, 7, 14, 23, 0);
    final now = DateTime.utc(2026, 7, 13);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-local',
            serverId: const Value(101),
            name: '晨跑',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-fixed',
            serverId: const Value(209),
            listId: 'list-local',
            title: '晨跑',
            updatedAt: now,
            createdAt: now,
            timeMode: const Value(2),
            timeZone: const Value('Asia/Shanghai'),
          ),
        );
    final notifications = _RecordingNotificationService();
    final poller = ReminderNotificationPoller(
      repository: _FakeReminderInboxRepository([
        ReminderInboxItem(
          id: 701,
          taskId: 209,
          taskTitle: '晨跑',
          remindAt: remindAt,
        ),
      ]),
      database: db,
      notifications: notifications,
      stateStore: _MemoryReminderNotificationStateStore(),
      notificationScope: 'tenant_user',
      now: () => now,
    );

    expect(await poller.poll(), 0);
    expect(notifications.scheduled, hasLength(1));
    final localWall = notifications.scheduled.single.fireAt.toLocal();
    expect(localWall.hour, 7, reason: '嘀嗒 :64 出差也要当地时间 7 点提醒');
    expect(localWall.minute, 0);
    expect(localWall.day, 15);
    expect(localWall.month, 7);
    expect(localWall.year, 2026);

    await poller.poll();
    expect(notifications.scheduled, hasLength(1), reason: '同一触发瞬间不重排');
  });

  test('锚点区变化后触发瞬间重排（模拟用户换区）', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final remindAt = DateTime.utc(2026, 7, 14, 23, 0);
    // 同上：两条触发（换区前当地 07:00、换区后当地 19:00）都要落在未来。
    final now = DateTime.utc(2026, 7, 13);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-local',
            serverId: const Value(101),
            name: '晨跑',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-fixed',
            serverId: const Value(209),
            listId: 'list-local',
            title: '晨跑',
            updatedAt: now,
            createdAt: now,
            timeMode: const Value(2),
            timeZone: const Value('Asia/Shanghai'),
          ),
        );
    final repository = _FakeReminderInboxRepository([
      ReminderInboxItem(
        id: 702,
        taskId: 209,
        taskTitle: '晨跑',
        remindAt: remindAt,
      ),
    ]);
    final notifications = _RecordingNotificationService();
    final poller = ReminderNotificationPoller(
      repository: repository,
      database: db,
      notifications: notifications,
      stateStore: _MemoryReminderNotificationStateStore(),
      notificationScope: 'tenant_user',
      now: () => now,
    );

    expect(await poller.poll(), 0);
    final first = notifications.scheduled.single.fireAt;

    await (db.update(db.todoTasks)..where((row) => row.serverId.equals(209)))
        .write(const TodoTasksCompanion(timeZone: Value('America/New_York')));
    await poller.poll();

    expect(notifications.scheduled, hasLength(2));
    expect(
      notifications.scheduled.last.fireAt.isAtSameMomentAs(first),
      isFalse,
      reason: '锚点区变了 ⇒ 锚点区读数变了 ⇒ 触发瞬间必须重排',
    );
  });
}

class _HangingScheduleNotificationService extends LocalNotificationService {
  @override
  Future<Map<int, DateTime>> pendingReminderSchedules(String scope) async =>
      const <int, DateTime>{};

  @override
  Future<Set<int>> activeReminderIds(String scope) async => const <int>{};

  @override
  Future<bool> cancel(int id, {String? tag}) async => true;

  @override
  Future<bool> show({
    required int id,
    required String title,
    String? body,
    String? payload,
    String? tag,
  }) => Completer<bool>().future;
}

class _FakeReminderInboxRepository extends ReminderInboxRepository {
  _FakeReminderInboxRepository(this.items)
    : super(ReminderActionApi(ApiClient()));

  List<ReminderInboxItem> items;
  Completer<void>? blocker;
  int listCalls = 0;

  @override
  Future<List<ReminderInboxItem>> list() async {
    listCalls++;
    await blocker?.future;
    return items;
  }
}

class _MemoryReminderNotificationStateStore
    implements ReminderNotificationStateStore {
  Map<int, DateTime> state = {};
  bool writeSucceeds = true;
  int writeAttempts = 0;

  @override
  Future<Map<int, DateTime>> read() async => Map.of(state);

  @override
  Future<bool> write(Map<int, DateTime> value) async {
    writeAttempts++;
    if (!writeSucceeds) return false;
    state = Map.of(value);
    return true;
  }
}

class _RecordingNotificationService extends LocalNotificationService {
  final shown = <({int id, String title, String? body, String? payload})>[];
  final scheduled =
      <
        ({int id, String title, String? body, DateTime fireAt, String? payload})
      >[];
  final cancelled = <int>[];
  bool scheduleSucceeds = true;
  int scheduleAttempts = 0;
  final systemSchedules = <int, DateTime>{};
  final systemActiveIds = <int>{};

  @override
  Future<Map<int, DateTime>> pendingReminderSchedules(String scope) async =>
      Map.of(systemSchedules);

  @override
  Future<Set<int>> activeReminderIds(String scope) async =>
      Set.of(systemActiveIds);

  @override
  Future<bool> show({
    required int id,
    required String title,
    String? body,
    String? payload,
    String? tag,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
    return true;
  }

  @override
  Future<bool> schedule({
    required int id,
    required String title,
    String? body,
    required DateTime fireAt,
    String? payload,
    String? tag,
  }) async {
    scheduleAttempts++;
    if (!scheduleSucceeds) return false;
    scheduled.add((
      id: id,
      title: title,
      body: body,
      fireAt: fireAt,
      payload: payload,
    ));
    return true;
  }

  @override
  Future<bool> cancel(int id, {String? tag}) async {
    cancelled.add(id);
    systemSchedules.remove(id);
    systemActiveIds.remove(id);
    return true;
  }
}
