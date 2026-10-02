import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/time/task_time_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/074（FL Issue #373）：嘀嗒《01-任务/07-固定时间与固定时区》把「固定时区」与
/// 「固定时间」分成两档；提醒侧原先只有一个布尔位，两档在提醒上分不开。
const _taskId = TodoVisualFixture.pinnedTaskId;

class _FailingReminderRepository extends ReminderRepository {
  _FailingReminderRepository(AppDatabase db) : super(db, SyncChangeQueue(db));

  @override
  Future<TodoReminder> update({
    required String id,
    required DateTime fireAt,
    required String anchorType,
    int? offsetMinutes,
    required bool persistent,
    int? intervalMinutes,
    String? timeZone,
    required bool fixedTimezone,
    TaskTimeMode? timeMode,
  }) async {
    throw StateError('后端 503，提醒没存上');
  }
}

Future<AppDatabase> _dbWithTask() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final now = DateTime.utc(2026, 7, 15, 9);
  await db
      .into(db.todoLists)
      .insert(
        TodoListsCompanion.insert(
          id: 'list-1',
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
          id: 'task-1',
          listId: 'list-1',
          title: '固定时间的提醒',
          updatedAt: now,
          createdAt: now,
        ),
      );
  return db;
}

Future<Map<String, dynamic>> _lastReminderPayload(AppDatabase db) async {
  final rows = await (db.select(
    db.todoSyncChanges,
  )..where((c) => c.entity.equals(SyncEntities.reminder))).get();
  return jsonDecode(rows.last.payloadJson) as Map<String, dynamic>;
}

Future<TodoReminder> _create(
  AppDatabase db, {
  TaskTimeMode? timeMode,
  bool fixedTimezone = false,
}) => ReminderRepository(db, SyncChangeQueue(db)).create(
  taskId: 'task-1',
  fireAt: DateTime.utc(2026, 7, 15, 10),
  fixedTimezone: fixedTimezone,
  timeMode: timeMode,
);

void main() {
  test('选「固定时间」时档位落进 Drift，派生位跟着为 true，出站 payload 带档位', () async {
    final db = await _dbWithTask();
    final row = await _create(db, timeMode: TaskTimeMode.fixedTime);
    expect(row.timeMode, TaskTimeMode.fixedTime.wire);
    expect(row.fixedTimezone, isTrue);
    expect(
      (await _lastReminderPayload(db))['timeMode'],
      TaskTimeMode.fixedTime.wire,
      reason: '出站不带档位 = 服务端只能按历史布尔位猜',
    );
  });

  test('只带旧布尔位时回填成「固定时间」，两档固定都让旧读法看到 true', () async {
    final db = await _dbWithTask();
    expect(
      (await _create(db, fixedTimezone: true)).timeMode,
      TaskTimeMode.fixedTime.wire,
    );
    final both = await _create(db, timeMode: TaskTimeMode.fixedTimezone);
    expect(both.timeMode, TaskTimeMode.fixedTimezone.wire);
    expect(both.fixedTimezone, isTrue);
    final none = await _create(db);
    expect(none.timeMode, TaskTimeMode.floating.wire);
    expect(none.fixedTimezone, isFalse);
  });

  testWidgets('两档各有可选中节点，选「固定时间」保存后写进 Drift', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _openReminderEditor(tester, fixture);

    expect(find.byKey(const Key('task-reminder-time-mode-1')), findsOneWidget);
    expect(find.byKey(const Key('task-reminder-time-mode-2')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('task-reminder-time-mode-2')),
        matching: find.text('不论所处时区如何变化，任务的时间都会保持一致'),
      ),
      findsOneWidget,
      reason: '措辞照抄嘀嗒，自创同义词就判红',
    );

    await tester.tap(find.byKey(const Key('task-reminder-time-mode-2')));
    await tester.pumpAndSettle();
    await _fillTimezone(tester);
    await _tapEditorSave(tester);
    await tester.pumpAndSettle();

    final stored = await fixture.database
        .select(fixture.database.todoReminders)
        .get();
    expect(stored, isNotEmpty);
    expect(
      stored.any((r) => r.timeMode == TaskTimeMode.fixedTime.wire),
      isTrue,
      reason: '界面选了档、库里还是旧布尔位 = 只改了控件没改数据',
    );
  });

  testWidgets('选「固定时区」落的是档位 1，不是旧布尔位反推的 2', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _openReminderEditor(tester, fixture);
    await tester.tap(find.byKey(const Key('task-reminder-time-mode-1')));
    await tester.pumpAndSettle();
    await _fillTimezone(tester);
    await _tapEditorSave(tester);

    final stored = await fixture.database
        .select(fixture.database.todoReminders)
        .get();
    expect(
      stored.any((r) => r.timeMode == TaskTimeMode.fixedTimezone.wire),
      isTrue,
      reason: '界面选了「固定时区」，写库却按旧布尔位反推成「固定时间」= 档位丢了',
    );
  });

  testWidgets('选中态要落在带 key 的那个读屏节点上，屏幕阅读器念得出当前档', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _openReminderEditor(tester, fixture);
    final handle = tester.ensureSemantics();

    SemanticsNode node(int wire) =>
        tester.getSemantics(find.byKey(Key('task-reminder-time-mode-$wire')));

    expect(node(1).flagsCollection.isSelected, Tristate.isFalse);
    expect(node(2).flagsCollection.isSelected, Tristate.isFalse);

    await _fillTimezone(tester);
    await tester.tap(find.byKey(const Key('task-reminder-time-mode-2')));
    await tester.pumpAndSettle();

    expect(
      node(2).flagsCollection.isSelected,
      Tristate.isTrue,
      reason: 'FL Issue #444：点选了「固定时间」但读屏仍说不选中，屏幕阅读器用户看不见自己的选择',
    );
    expect(
      node(1).flagsCollection.isSelected,
      Tristate.isFalse,
      reason: '两档同时选中就不是单选',
    );
    expect(
      node(2).label,
      '固定时间\n不论所处时区如何变化，任务的时间都会保持一致',
      reason: '选中态必须和这一档自己的标题加嘀嗒副标题在同一个节点上，分家就念不成一句',
    );
    handle.dispose();
  });

  testWidgets('320px + 1.3 倍字号下两档都在视口内且点得动', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openReminderEditor(tester, fixture, textScale: 1.3);

    for (final wire in const [1, 2]) {
      final finder = find.byKey(Key('task-reminder-time-mode-$wire'));
      expect(finder, findsOneWidget);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(640));
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '窄屏点不动这一档等于没有这一档');
    }
  });

  testWidgets('更新失败时给出可见原因，且库里没有半写的档位', (tester) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (db) => [
        reminderRepositoryProvider.overrideWithValue(
          _FailingReminderRepository(db),
        ),
      ],
    );
    addTearDown(fixture.dispose);
    await _openReminderEditor(tester, fixture);
    await tester.tap(find.byKey(const Key('task-reminder-time-mode-1')));
    await tester.pumpAndSettle();
    await _fillTimezone(tester);
    await _tapEditorSave(tester);

    expect(
      find.textContaining('提醒更新失败'),
      findsOneWidget,
      reason: '失败只打进 console 用户看不见（原因文案由 _reminderErrorMessage 归一化）',
    );
    final stored = await fixture.database
        .select(fixture.database.todoReminders)
        .get();
    expect(
      stored.any((r) => r.timeMode == TaskTimeMode.fixedTimezone.wire),
      isFalse,
      reason: '报了错 yet 档位落库 = 半写状态',
    );
  });
}

Future<void> _openReminderEditor(
  WidgetTester tester,
  TodoVisualFixture fixture, {
  double textScale = 1.0,
}) async {
  final repository = ReminderRepository(
    fixture.database,
    SyncChangeQueue(fixture.database),
  );
  final reminder = await repository.create(
    taskId: _taskId,
    fireAt: DateTime(2026, 7, 11, 9, 10),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(
            body: TaskDetailPane(taskId: _taskId, embedded: true),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('task-schedule-options')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('task-reminders')),
    160,
    scrollable: find.byType(Scrollable).last,
  );
  final edit = find.byKey(ValueKey('task-reminder-edit-${reminder.id}'));
  await tester.ensureVisible(edit);
  await tester.pumpAndSettle();
  await tester.tap(edit);
  await tester.pumpAndSettle();
  expect(find.text('编辑提醒'), findsOneWidget, reason: '编辑器没打开的话，下面所有断言都是恒真的');
}

/// 「固定时区 / 固定时间」两档都要求 IANA 值非空（既有校验「固定时区不能为空」），
/// 不填就永远走不到写库那一步，判的就不是档位了。
Future<void> _fillTimezone(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('task-reminder-timezone')),
    'Asia/Shanghai',
  );
  await tester.pumpAndSettle();
}

/// 详情面自身也有一个「保存」，不限定到提醒编辑器自己的那颗就会撞成歧义 finder。
Future<void> _tapEditorSave(WidgetTester tester) async {
  final save = find.byKey(const Key('task-reminder-save'));
  expect(save, findsOneWidget, reason: '编辑器自己的保存按钮不在，说明弹窗没打开');
  await tester.tap(save);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
