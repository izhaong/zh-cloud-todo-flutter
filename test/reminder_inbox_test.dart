import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/pomodoro/pomodoro_page.dart';
import 'package:zh_cloud_todo_flutter/features/reminder/reminder_inbox_page.dart'
    show ReminderInboxPage, groupByTask, InboxEntry;
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_inbox_repository.dart';

class _FakeReminderInboxRepository extends ReminderInboxRepository {
  _FakeReminderInboxRepository(this.items)
    : super(ReminderActionApi(ApiClient(dio: Dio())));

  final List<ReminderInboxItem> items;

  @override
  Future<List<ReminderInboxItem>> list() async => items;
}

void main() {
  group('ReminderActionApi.normalize', () {
    test('收件箱读取统一数组信封', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 0,
                'data': [
                  {'reminderDispatchId': 8, 'reminderId': 9, 'taskId': 60},
                ],
              },
            ),
          ),
        ),
      );

      final items = await ReminderActionApi(ApiClient(dio: dio)).inbox();

      expect(items, hasLength(1));
      expect(items.single.id, 8);
      expect(items.single.reminderId, 9);
    });

    test('解析纯数组', () {
      final raw = [
        {
          'id': 1,
          'taskId': 10,
          'taskTitle': 'A',
          'remindAt': '2026-07-07T10:00:00',
        },
        {'id': 2, 'taskId': 10, 'title': 'B', 'remindAt': 1700000000000},
      ];
      final items = ReminderActionApi.normalize(raw);
      expect(items, hasLength(2));
      expect(items.first.id, 1);
      expect(items.first.taskTitle, 'A');
      expect(items[1].taskTitle, 'B');
    });

    test('解析统一信封 {code,data:[…]}', () {
      final body = {
        'code': 0,
        'msg': 'ok',
        'data': [
          {'id': 3, 'taskId': 20, 'taskTitle': 'C'},
        ],
      };
      final items = ReminderActionApi.normalize(body);
      expect(items, hasLength(1));
      expect(items.first.id, 3);
      expect(items.first.taskId, 20);
    });

    test('保留派发 ID 与提醒规则 ID', () {
      final items = ReminderActionApi.normalize([
        {
          'reminderDispatchId': 71,
          'reminderId': 72,
          'taskId': 20,
          'taskTitle': '提醒动作',
          'fireAt': '2026-07-13T09:00:00',
        },
      ]);

      expect(items.single.id, 71);
      expect(items.single.reminderId, 72);
    });

    test('服务端 SENT 派发仍是收件箱中的待处理提醒', () {
      final items = ReminderActionApi.normalize([
        {
          'reminderDispatchId': 81,
          'reminderId': 82,
          'taskId': 20,
          'status': 'SENT',
        },
      ]);

      expect(items.single.pending, isTrue);
    });

    test('解析信封 {code,data:{list:[…]}}', () {
      final body = {
        'code': 0,
        'data': {
          'list': [
            {'id': 4, 'taskId': 30, 'taskTitle': 'D'},
          ],
        },
      };
      final items = ReminderActionApi.normalize(body);
      expect(items, hasLength(1));
      expect(items.first.taskTitle, 'D');
    });

    test('解析兜底 {list:[…]} / {items:[…]}', () {
      final a = ReminderActionApi.normalize({
        'list': [
          {'id': 5, 'taskId': 40, 'taskTitle': 'E'},
        ],
      });
      expect(a, hasLength(1));
      final b = ReminderActionApi.normalize({
        'items': [
          {'id': 6, 'taskId': 50, 'taskTitle': 'F'},
        ],
      });
      expect(b, hasLength(1));
    });

    test('空 / 非法输入返回空列表', () {
      expect(ReminderActionApi.normalize(null), isEmpty);
      expect(ReminderActionApi.normalize({}), isEmpty);
      expect(ReminderActionApi.normalize({'code': 0, 'data': null}), isEmpty);
    });

    test('默认 status 为 PENDING，pending 为 true', () {
      final items = ReminderActionApi.normalize([
        {'id': 7, 'taskId': 60, 'taskTitle': 'G'},
      ]);
      expect(items.first.status, 'PENDING');
      expect(items.first.pending, isTrue);
    });
  });

  group('groupByTask', () {
    test('按 taskId 分组并按首个 remindAt 升序', () {
      final now = DateTime.now();
      final entries = [
        InboxEntry(
          ReminderInboxItem(
            id: 1,
            taskId: 2,
            taskTitle: 'T2',
            remindAt: now.add(const Duration(hours: 2)),
          ),
        ),
        InboxEntry(
          ReminderInboxItem(
            id: 2,
            taskId: 1,
            taskTitle: 'T1',
            remindAt: now.add(const Duration(hours: 1)),
          ),
        ),
        InboxEntry(
          ReminderInboxItem(
            id: 3,
            taskId: 2,
            taskTitle: 'T2',
            remindAt: now.add(const Duration(hours: 3)),
          ),
        ),
      ];
      final groups = groupByTask(entries);
      expect(groups, hasLength(2));
      expect(groups.first.taskId, 1); // 更早的排前面
      expect(groups[1].taskId, 2);
      expect(groups[1].reminders, hasLength(2));
    });
  });

  testWidgets('延后提醒入 outbox 后提示等待同步', (tester) async {
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderInboxRepositoryProvider.overrideWithValue(
          _FakeReminderInboxRepository([
            ReminderInboxItem(
              id: 71,
              reminderId: 72,
              taskId: 12,
              taskTitle: '稍后处理',
              remindAt: DateTime(2026, 7, 16, 9),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReminderInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('延后 10 分钟'));
    await tester.pumpAndSettle();

    expect(find.text('提醒操作已加入同步队列'), findsOneWidget);
    final changes = await database.select(database.todoSyncChanges).get();
    expect(changes, hasLength(1));
    expect(changes.single.entity, 'reminder_dispatch_action');
  });

  testWidgets('完成提醒入队后以本地状态覆盖未刷新的远端待处理项', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderInboxRepositoryProvider.overrideWithValue(
          _FakeReminderInboxRepository([
            ReminderInboxItem(
              id: 91,
              reminderId: 92,
              taskId: 12,
              taskTitle: '提交周报',
              remindAt: DateTime(2026, 7, 16, 9),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReminderInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待处理 1'), findsOneWidget);
    await tester.tap(find.byTooltip('完成'));
    await tester.pumpAndSettle();

    expect(find.text('操作等待同步'), findsOneWidget);
    expect(find.text('待处理 1'), findsNothing);
    expect(find.byTooltip('完成'), findsNothing);
    expect(find.byTooltip('忽略'), findsNothing);
    expect(find.text('全部完成'), findsNothing);
    expect(find.text('全部忽略'), findsNothing);

    final changes = await database.select(database.todoSyncChanges).get();
    expect(changes, hasLength(1));
    final payload =
        jsonDecode(changes.single.payloadJson) as Map<String, dynamic>;
    expect(changes.single.entityServerId, 91);
    expect(payload['reminderDispatchId'], 91);
    expect(payload['action'], 'complete');
  });

  testWidgets('提醒动作重试中时展示尝试次数且不允许重复操作', (tester) async {
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderInboxRepositoryProvider.overrideWithValue(
          _FakeReminderInboxRepository([
            ReminderInboxItem(
              id: 101,
              reminderId: 102,
              taskId: 12,
              taskTitle: '同步重试',
              remindAt: DateTime(2026, 7, 16, 9),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(reminderDispatchActionRepositoryProvider)!
        .dismiss(reminderDispatchId: 101);
    await database
        .update(database.todoSyncChanges)
        .write(
          const TodoSyncChangesCompanion(
            status: Value('retryable'),
            attemptCount: Value(2),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReminderInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('操作同步失败，等待重试（已尝试 2 次）'), findsOneWidget);
    expect(find.byTooltip('完成'), findsNothing);
    expect(find.byTooltip('忽略'), findsNothing);
  });

  testWidgets('全部忽略为同组每条提醒入队并立即清空待处理计数', (tester) async {
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderInboxRepositoryProvider.overrideWithValue(
          _FakeReminderInboxRepository([
            ReminderInboxItem(
              id: 111,
              reminderId: 112,
              taskId: 12,
              taskTitle: '批量处理',
              remindAt: DateTime(2026, 7, 16, 9),
            ),
            ReminderInboxItem(
              id: 113,
              reminderId: 114,
              taskId: 12,
              taskTitle: '批量处理',
              remindAt: DateTime(2026, 7, 16, 9, 10),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReminderInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待处理 2'), findsOneWidget);
    await tester.tap(find.text('全部忽略'));
    await tester.pumpAndSettle();

    expect(find.text('操作等待同步'), findsNWidgets(2));
    expect(find.text('待处理 2'), findsNothing);
    expect(find.text('全部完成'), findsNothing);
    expect(find.text('全部忽略'), findsNothing);
    final changes = await database.select(database.todoSyncChanges).get();
    expect(changes, hasLength(2));
    expect(changes.map((change) => change.entityServerId), [111, 113]);
    expect(
      changes.map(
        (change) =>
            (jsonDecode(change.payloadJson) as Map<String, dynamic>)['action'],
      ),
      ['dismiss', 'dismiss'],
    );
  });

  testWidgets('开始专注入 outbox 并进入关联任务专注页', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        reminderInboxRepositoryProvider.overrideWithValue(
          _FakeReminderInboxRepository([
            ReminderInboxItem(
              id: 81,
              reminderId: 82,
              taskId: 12,
              taskTitle: '开始写周报',
              remindAt: DateTime(2026, 7, 16, 9),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReminderInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('开始专注'));
    await tester.pumpAndSettle();

    expect(find.text('番茄专注'), findsOneWidget);
    expect(tester.widget<PomodoroPage>(find.byType(PomodoroPage)).taskId, 12);
    final changes = await database.select(database.todoSyncChanges).get();
    expect(changes, hasLength(1));
    final payload =
        jsonDecode(changes.single.payloadJson) as Map<String, dynamic>;
    expect(payload['reminderDispatchId'], 81);
    expect(payload['action'], 'start_focus');
  });
}
