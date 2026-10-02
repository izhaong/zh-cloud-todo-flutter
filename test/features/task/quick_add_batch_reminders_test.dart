import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/quick_add_batch_reminders.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 判据源《03-特色功能/05-智能识别.md》:5——快速添加识别到日期时要同时「创建日期和提醒」。
/// 单条那半由 `quick_add_nlp_reminder_test.dart` 钉住；本文件钉多行批量那半（FL Issue #410）。
void main() {
  const resolved = 1; // 「明天9点」那一批行的固定识别时刻标记
  final expectedFireAt = DateTime(2030, 5, 6, 9 + resolved, 0);

  Future<List<TodoReminder>> remindersFor(AppDatabase db, Set<String> ids) =>
      (db.select(db.todoReminders)..where((row) => row.taskId.isIn(ids))).get();

  Future<List<TodoTask>> tasksByIds(AppDatabase db, Set<String> ids) =>
      (db.select(db.todoTasks)..where((row) => row.id.isIn(ids))).get();

  Future<TodoVisualFixture> booted() async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    return fixture;
  }

  Future<List<TodoTask>> batchCreate(
    TodoVisualFixture fixture,
    String input,
  ) async {
    final repo = fixture.container.read(taskRepositoryProvider);
    expect(repo, isNotNull, reason: 'fixture 没装出可写的任务仓储');
    return repo!.createBatch(
      listId: TodoVisualFixture.inboxListId,
      input: input,
      dueAtResolver: (line) => line.endsWith('明天9点') ? expectedFireAt : null,
    );
  }

  ReminderRepository? liveReminders(ProviderContainer container) =>
      container.read(reminderRepositoryProvider);

  test('批量里识别到时间的每一行各落一条提醒，fireAt 就是识别出的那个时刻', () async {
    final fixture = await booted();
    final created = await batchCreate(fixture, '写周报 明天9点\n买牛奶\n交材料 明天9点');
    expect(created, hasLength(3));

    final message = await attachResolvedReminders(
      created: created,
      reminders: liveReminders(fixture.container),
    );

    expect(message, isNull, reason: '两条都该写成，不该回报失败');
    final ids = created.map((task) => task.id).toSet();
    final rows = await remindersFor(fixture.database, ids);
    expect(rows, hasLength(2), reason: '三行里只有两行识别到时间');
    expect(rows.map((row) => row.remindAt).toSet(), {
      expectedFireAt,
    }, reason: '提醒时刻必须就是识别出来的那个时间，不能另算');
    expect(rows.map((row) => row.taskId).toSet(), {
      created[0].id,
      created[2].id,
    }, reason: '提醒要挂在被识别的那两条任务上，不是第一行也不是全部');
  });

  test('一行都没识别到时间时不写提醒，也不给用户报错', () async {
    final fixture = await booted();
    final created = await batchCreate(fixture, '买牛奶\n买面包');

    final message = await attachResolvedReminders(
      created: created,
      reminders: liveReminders(fixture.container),
    );

    expect(message, isNull);
    final ids = created.map((task) => task.id).toSet();
    expect(await remindersFor(fixture.database, ids), isEmpty);
  });

  test('提醒仓储没就绪时报错而不是静默早退，已建任务一条不少', () async {
    final fixture = await booted();
    final created = await batchCreate(fixture, '写周报 明天9点');

    final message = await attachResolvedReminders(
      created: created,
      reminders: null,
    );

    expect(
      message,
      isNotNull,
      reason: '写成 ?.create 就是一次静默早退（#289/#292 清掉的那类缺陷）',
    );
    expect(message, contains('任务已建'));
    final ids = created.map((task) => task.id).toSet();
    expect(
      await tasksByIds(fixture.database, ids),
      hasLength(1),
      reason: '提醒不可用不得回滚已建任务',
    );
  });

  test('其中一条提醒写失败时其余照常落库，并一起报出成功数与失败数', () async {
    final fixture = await booted();
    final created = await batchCreate(fixture, '写周报 明天9点\n交材料 明天9点\n第三件事 明天9点');
    final queue = fixture.container.read(syncChangeQueueProvider);
    expect(queue, isNotNull);
    final flaky = _FlakyReminderRepository(fixture.database, queue!);

    final message = await attachResolvedReminders(
      created: created,
      reminders: flaky,
    );

    expect(message, isNotNull);
    expect(message, contains('2'), reason: '成功 2 条要说出来');
    expect(message, contains('1'), reason: '失败 1 条也要说出来');
    final ids = created.map((task) => task.id).toSet();
    expect(
      await remindersFor(fixture.database, ids),
      hasLength(2),
      reason: '一条失败不得带走其余两条',
    );
    expect(
      await tasksByIds(fixture.database, ids),
      hasLength(3),
      reason: '部分失败不得回滚任何已建任务',
    );
  });
}

/// 第 2 次 `create` 抛错，用来验「部分失败」那一档；其余写库仍走真实仓储。
class _FlakyReminderRepository extends ReminderRepository {
  _FlakyReminderRepository(super.db, super.queue);

  int _calls = 0;

  @override
  Future<TodoReminder> create({
    required String taskId,
    required DateTime fireAt,
    String anchorType = 'ABSOLUTE',
    int? offsetMinutes,
    bool persistent = false,
    int? intervalMinutes,
    String? timeZone,
    bool fixedTimezone = false,
  }) async {
    _calls += 1;
    if (_calls == 2) {
      throw StateError('故意让第 2 条提醒写不成');
    }
    return super.create(
      taskId: taskId,
      fireAt: fireAt,
      anchorType: anchorType,
      offsetMinutes: offsetMinutes,
      persistent: persistent,
      intervalMinutes: intervalMinutes,
      timeZone: timeZone,
      fixedTimezone: fixedTimezone,
    );
  }
}
