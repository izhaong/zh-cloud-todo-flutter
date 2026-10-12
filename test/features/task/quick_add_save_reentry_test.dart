import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// FL Issue #391：`TaskQuickAddSheet._save()` 没有 in-flight 闸门。
///
/// specs/063（Issue #388）把「识别到时间 ⇒ 顺带建提醒」接进来之后，一次保存从
/// 1 个 `await` 变成 2 个 ⇒ 重入窗口被拉长。同一个文件的模板路径 `_addFromTemplate`
/// **是**有 `_applyingTemplate` 闸门的，所以这不是"本仓一贯如此"，是这条路径漏了。
void main() {
  Future<List<TodoTask>> tasksNamed(AppDatabase db, String title) =>
      (db.select(db.todoTasks)..where((row) => row.title.equals(title))).get();

  testWidgets('保存请求在飞时再点第二次，不该建出第二遍任务', (tester) async {
    late _GatedTaskRepository gated;
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (db) {
        gated = _GatedTaskRepository(db, SyncChangeQueue(db));
        return [taskRepositoryProvider.overrideWithValue(gated)];
      },
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskQuickAddSheet(listId: TodoVisualFixture.inboxListId),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '买牛奶');
    await tester.tap(find.text('保存'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    // 第一笔必须真的已经进到 create，否则下面那个「只调一次」是在测空气。
    expect(gated.createCalls, 1, reason: '闸门还没进 in-flight 状态就断言重入，等于没测');

    await tester.tap(find.text('保存'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      gated.createCalls,
      1,
      reason: '连点两次「保存」不该变成两次 TaskRepository.create',
    );

    gated.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(TaskQuickAddSheet), findsNothing);
    expect(await tasksNamed(fixture.database, '买牛奶'), hasLength(1));
    expect(gated.createCalls, 1);
  });

  /// 闸门本身的新风险：`_saving` 若不在 finally 里复位，一次失败就把「保存」永久锁死。
  /// 这一条测的是"加闸门"这个动作拉长出来的缺陷，不是原有缺陷。
  testWidgets('一次保存失败之后，再点「保存」还能重试', (tester) async {
    late _FailOnceTaskRepository failing;
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (db) {
        failing = _FailOnceTaskRepository(db, SyncChangeQueue(db));
        return [taskRepositoryProvider.overrideWithValue(failing)];
      },
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskQuickAddSheet(listId: TodoVisualFixture.inboxListId),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '买牛奶');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(failing.createCalls, 1);
    expect(
      find.text('保存任务失败，请稍后重试'),
      findsOneWidget,
      reason: '失败提示要留在弹窗可见区（#289 立的规矩），否则第二次点击无从判断',
    );
    expect(find.byType(TaskQuickAddSheet), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(failing.createCalls, 2, reason: '闸门没在 finally 复位 ⇒ 第二次点击被吞掉，按钮永久锁死');
    expect(await tasksNamed(fixture.database, '买牛奶'), hasLength(1));
  });
}

/// 让 `create` 停在闸门上，制造"请求在飞"的真实窗口（不是靠不调 pump 假装）。
class _GatedTaskRepository extends TaskRepository {
  _GatedTaskRepository(super.db, super.queue);

  final Completer<void> gate = Completer<void>();
  int createCalls = 0;

  @override
  Future<TodoTask> create({
    required String listId,
    required String title,
    String? sectionId,
    String? description,
    int priority = 0,
    DateTime? startAt,
    int? timeMode,
    DateTime? endAt,
    DateTime? dueAt,
    bool allDay = false,
    String? timeZone,
    bool fixedTimezone = false,
    String? parentTaskId,
    bool isPinned = false,
  }) async {
    createCalls++;
    await gate.future;
    return super.create(
      listId: listId,
      title: title,
      sectionId: sectionId,
      description: description,
      priority: priority,
      startAt: startAt,
      endAt: endAt,
      dueAt: dueAt,
      allDay: allDay,
      timeZone: timeZone,
      fixedTimezone: fixedTimezone,
      parentTaskId: parentTaskId,
      isPinned: isPinned,
    );
  }
}

/// 第一笔抛错、第二笔走真实实现。抛的不是 `StateError`：`_saveOnce` 对 `StateError`
/// 用的是错误自己的 message，这里要钉的是通用兜底那句『保存任务失败，请稍后重试』。
class _FailOnceTaskRepository extends TaskRepository {
  _FailOnceTaskRepository(super.db, super.queue);

  int createCalls = 0;

  @override
  Future<TodoTask> create({
    required String listId,
    required String title,
    String? sectionId,
    String? description,
    int priority = 0,
    DateTime? startAt,
    int? timeMode,
    DateTime? endAt,
    DateTime? dueAt,
    bool allDay = false,
    String? timeZone,
    bool fixedTimezone = false,
    String? parentTaskId,
    bool isPinned = false,
  }) async {
    createCalls++;
    if (createCalls == 1) throw Exception('网络不可用');
    return super.create(
      listId: listId,
      title: title,
      sectionId: sectionId,
      description: description,
      priority: priority,
      startAt: startAt,
      endAt: endAt,
      dueAt: dueAt,
      allDay: allDay,
      timeZone: timeZone,
      fixedTimezone: fixedTimezone,
      parentTaskId: parentTaskId,
      isPinned: isPinned,
    );
  }
}
