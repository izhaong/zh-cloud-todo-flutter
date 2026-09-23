import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

import '../../support/todo_visual_fixture.dart';

const _metadataTaskId = TodoVisualFixture.metadataTaskId;
const _childTaskId = 'visual-task-metadata-child-1';
const _metadataTitle = '准备项目周会材料';

/// 嘀嗒《多级任务》：任务详情「...」→「关联主任务」；已关联任务可点 ✖️ 取消关联；
/// 子任务详情里点标题上方的主任务标题跳主任务详情。
void main() {
  Future<TodoVisualFixture> pumpPane(
    WidgetTester tester, {
    required String taskId,
    Size size = const Size(760, 900),
    TaskRepository Function(AppDatabase db, SyncChangeQueue queue)? repoBuilder,
  }) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget pane = TaskDetailPane(taskId: taskId, embedded: true);
    if (repoBuilder != null) {
      final repository = repoBuilder(
        fixture.database,
        SyncChangeQueue(fixture.database),
      );
      pane = ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
        child: pane,
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: Scaffold(body: pane),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<TodoTask> taskOf(AppDatabase db, String id) =>
      (db.select(db.todoTasks)..where((row) => row.id.equals(id))).getSingle();

  Future<void> openParentSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关联主任务'));
    await tester.pumpAndSettle();
  }

  group('关联主任务', () {
    testWidgets('从无父任务的任务发起关联：写入 parentTaskId 并入队 task upsert', (tester) async {
      final fixture = await pumpPane(
        tester,
        taskId: TodoVisualFixture.pinnedTaskId,
      );

      await openParentSheet(tester);
      expect(
        find.byKey(const ValueKey('task-parent-sheet')),
        findsOneWidget,
        reason: '弹层要有自己的锚点，否则 320px 自检无处可查',
      );
      await tester.tap(
        find.byKey(const ValueKey('task-parent-candidate-$_metadataTaskId')),
      );
      await tester.pumpAndSettle();

      expect(
        (await taskOf(
          fixture.database,
          TodoVisualFixture.pinnedTaskId,
        )).parentTaskId,
        _metadataTaskId,
        reason: '关联主任务要真的落库，不能只在弹层里闪一下',
      );
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(
        changes.where(
          (change) => change.entityLocalId == TodoVisualFixture.pinnedTaskId,
        ),
        isNotEmpty,
        reason: '离线改动必须进 outbox，否则另一端同步不到',
      );
    });

    testWidgets('候选列表排除自己与自己的后代，避免造出环', (tester) async {
      await pumpPane(tester, taskId: _metadataTaskId);

      await openParentSheet(tester);

      expect(
        find.byKey(const ValueKey('task-parent-candidate-$_metadataTaskId')),
        findsNothing,
        reason: '自己不能当自己的主任务',
      );
      expect(
        find.byKey(
          const ValueKey('task-parent-candidate-visual-task-metadata-child-1'),
        ),
        findsNothing,
        reason: '把自己的子任务设成主任务会成环',
      );
      expect(
        find.byKey(
          const ValueKey('task-parent-candidate-visual-task-metadata-child-2'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey(
            'task-parent-candidate-${TodoVisualFixture.pinnedTaskId}',
          ),
        ),
        findsOneWidget,
        reason: '同清单的无关任务才是候选',
      );
    });

    testWidgets('已关联时弹层显示当前主任务并可取消关联', (tester) async {
      final fixture = await pumpPane(tester, taskId: _childTaskId);

      await openParentSheet(tester);
      expect(
        find.text('当前主任务：$_metadataTitle'),
        findsOneWidget,
        reason: '嘀嗒在关联页里显示已关联的主任务并提供 ✖️ 取消',
      );

      await tester.tap(find.byKey(const Key('task-parent-unlink')));
      await tester.pumpAndSettle();

      expect(
        (await taskOf(fixture.database, _childTaskId)).parentTaskId,
        isNull,
      );
    });

    testWidgets('子任务详情上方显示主任务行，点击打开主任务详情', (tester) async {
      await pumpPane(tester, taskId: _childTaskId);

      await tester.tap(find.byKey(const Key('task-detail-parent-row')));
      await tester.pumpAndSettle();

      expect(
        find.text('整理进度、风险和下一阶段计划。'),
        findsOneWidget,
        reason: '跳转要真的落到主任务详情，而不是只列个标题',
      );
    });

    testWidgets('只读清单里关联失败：给提示、原数据保持、面板还在', (tester) async {
      final fixture = await pumpPane(tester, taskId: _childTaskId);
      final stamp = DateTime(2026, 7, 30, 18);
      await fixture.database
          .into(fixture.database.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: TodoVisualFixture.inboxListId,
              name: '收集箱',
              writable: const Value(false),
              createdAt: stamp,
              updatedAt: stamp,
            ),
          );
      await tester.pumpAndSettle();

      await openParentSheet(tester);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'task-parent-candidate-${TodoVisualFixture.pinnedTaskId}',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('只读'),
        findsOneWidget,
        reason: '失败要说出来，不能静默回到原状态',
      );
      expect(
        (await taskOf(fixture.database, _childTaskId)).parentTaskId,
        _metadataTaskId,
        reason: '失败不能把已加载的层级改掉',
      );
      expect(find.text('汇总已完成事项'), findsOneWidget);
    });

    testWidgets('面板卸载后回包不砸 setState', (tester) async {
      _SlowReparentRepository? slow;
      await pumpPane(
        tester,
        taskId: _childTaskId,
        repoBuilder: (db, queue) => slow = _SlowReparentRepository(db, queue),
      );

      await openParentSheet(tester);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'task-parent-candidate-${TodoVisualFixture.pinnedTaskId}',
          ),
        ),
      );
      await tester.pump();
      expect(slow!.pending, isTrue, reason: '先把 reparent 悬住，再卸载面板');

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      slow!.release();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px + 1.3 倍字体：弹层自己继承档位且不溢出', (tester) async {
      await pumpPane(
        tester,
        taskId: TodoVisualFixture.pinnedTaskId,
        size: const Size(320, 620),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      // 存量欠债（本轮不动、另开 Issue）：嵌入态详情操作头 `_buildEmbedded` 的
      // Row 在 320px + 1.3 倍下已溢出 36px。先吃掉这条既有异常，
      // 才能把「弹层自身零溢出」与它分开证明。
      expect(
        '${tester.takeException()}',
        contains('RenderFlex overflowed'),
        reason: '既有溢出要留在账上，不能被本轮当成自己的通过',
      );

      await openParentSheet(tester);
      final sheetContext = tester.element(
        find.byKey(const ValueKey('task-parent-sheet')),
      );
      expect(
        MediaQuery.textScalerOf(sheetContext).scale(10).round(),
        13,
        reason: '弹层走 rootNavigator，档位必须在它自己的 context 上验',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '「关联主任务」弹层在 320px + 1.3 倍下不得再有新溢出',
      );
    });

    testWidgets('读屏能单独找到关联入口、取消按钮与主任务行', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpPane(tester, taskId: _childTaskId);

        expect(
          // 注意：raw 字符串里的 `$_metadataTitle` 不会被插值，这里必须用普通字符串。
          find.bySemanticsLabel(RegExp('^主任务：$_metadataTitle\$')),
          findsOneWidget,
          reason: '主任务行要作为独立节点被念出来，不能并进标题',
        );

        await tester.tap(find.byTooltip('更多任务操作'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp(r'^关联主任务$')), findsOneWidget);

        await tester.tap(find.text('关联主任务'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp(r'^取消关联$')), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });
  });
}

/// 把 reparent 卡在 awaited 状态，用来验「回包晚于面板卸载」不砸已销毁的 State。
class _SlowReparentRepository extends TaskRepository {
  _SlowReparentRepository(super.db, super.queue);

  final Completer<void> _gate = Completer<void>();

  bool get pending => !_gate.isCompleted;

  void release() => _gate.complete();

  @override
  Future<void> reparent(String taskId, String? newParentId) async {
    await _gate.future;
    await super.reparent(taskId, newParentId);
  }
}
