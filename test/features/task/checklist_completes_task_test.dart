import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒「多级任务」常见问题：检查事项与子任务同时存在或只有一个存在时，
/// 仅检查事项的完成会影响任务进度；检查事项全部完成后，主任务将自动完成。
void main() {
  group('检查事项全完成驱动主任务', () {
    test('勾完最后一条检查事项会把主任务标记完成并写一条 task upsert', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '撰写周报');
      final first = await repository.createChecklistItem(
        taskId: task.id,
        title: '整理数据',
      );
      final second = await repository.createChecklistItem(
        taskId: task.id,
        title: '复核数据',
      );
      await db.delete(db.todoSyncChanges).go();

      await repository.toggleChecklistItem(first.id);
      await repository.toggleChecklistItem(second.id);

      final stored = await repository.getById(task.id);
      expect(stored?.completed, isTrue, reason: '检查事项全部完成后主任务要自动完成，不能还停在未完成');
      expect(stored?.completedAt, isNotNull);

      final taskChanges = await (db.select(
        db.todoSyncChanges,
      )..where((change) => change.entityLocalId.equals(task.id))).get();
      expect(taskChanges, hasLength(1), reason: '自动完成只能写一条 task upsert');
      expect(taskChanges.single.op, SyncOps.upsert);
      final payload =
          jsonDecode(taskChanges.single.payloadJson) as Map<String, dynamic>;
      expect(payload['status'], 'DONE');
      expect(payload['completedAt'], isNotNull);
    });

    test('还有未勾完的检查事项时不动主任务，也不写主任务的 upsert', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '筹备发布会');
      await repository.createChecklistItem(taskId: task.id, title: '订场地');
      final second = await repository.createChecklistItem(
        taskId: task.id,
        title: '发邀请',
      );
      await db.delete(db.todoSyncChanges).go();

      await repository.toggleChecklistItem(second.id);

      expect((await repository.getById(task.id))?.completed, isFalse);
      expect(
        await (db.select(
          db.todoSyncChanges,
        )..where((change) => change.entityLocalId.equals(task.id))).get(),
        isEmpty,
        reason: '半完成不是完成，不能往 outbox 塞主任务的 DONE',
      );
    });

    test('取消一条检查事项不会把主任务反向改回未完成', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '复盘会议');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '整理结论',
      );
      await repository.toggleChecklistItem(item.id);
      expect((await repository.getById(task.id))?.completed, isTrue);
      await db.delete(db.todoSyncChanges).go();

      await repository.toggleChecklistItem(item.id);

      final stored = await repository.getById(task.id);
      expect(
        stored?.completed,
        isTrue,
        reason: '不回退：用户可能已经基于完成状态做了后续操作，反转比保持更危险',
      );
      expect(
        await (db.select(
          db.todoSyncChanges,
        )..where((change) => change.entityLocalId.equals(task.id))).get(),
        isEmpty,
        reason: '取消勾选只该写检查事项自己那条 outbox',
      );
    });

    test('主任务已是完成态时不重复写 upsert', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '写月报');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '汇总数据',
      );
      await repository.toggleComplete(task.id);
      await db.delete(db.todoSyncChanges).go();

      await repository.toggleChecklistItem(item.id);

      expect(
        await (db.select(
          db.todoSyncChanges,
        )..where((change) => change.entityLocalId.equals(task.id))).get(),
        isEmpty,
        reason: '已经完成的父任务不该再多一条 upsert',
      );
    });

    test('已作废的任务即使检查事项全完成也不被自动完成', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '旧需求');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '归档材料',
      );
      await repository.abandon(task.id);
      await db.delete(db.todoSyncChanges).go();

      await repository.toggleChecklistItem(item.id);

      final stored = await repository.getById(task.id);
      expect(stored?.cancelled, isTrue);
      expect(stored?.completed, isFalse, reason: '回收站里的任务不能被勾选项复活');
    });

    test('子任务全部完成不会自动完成父任务', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final parent = await repository.create(listId: 'inbox', title: '装修');
      final child = await repository.create(
        listId: 'inbox',
        title: '选瓷砖',
        parentTaskId: parent.id,
      );

      await repository.toggleComplete(child.id);

      expect((await repository.getById(child.id))?.completed, isTrue);
      expect(
        (await repository.getById(parent.id))?.completed,
        isFalse,
        reason: '嘀嗒口径：子任务的完成不影响主任务完成，只有检查事项会',
      );
    });

    test('只勾 A 任务的检查事项不会把同清单的 B 任务也完成', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final first = await repository.create(listId: 'inbox', title: '写周报');
      final second = await repository.create(listId: 'inbox', title: '写月报');
      final firstItem = await repository.createChecklistItem(
        taskId: first.id,
        title: '整理数据',
      );
      await repository.createChecklistItem(taskId: second.id, title: '整理趋势');

      await repository.toggleChecklistItem(firstItem.id);

      expect((await repository.getById(first.id))?.completed, isTrue);
      expect(
        (await repository.getById(second.id))?.completed,
        isFalse,
        reason: '未勾完的兄弟任务不能被邻居的自动完成带走',
      );
    });

    test('自动完成过之后再取消再勾满，不再重复写主任务 upsert', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final task = await repository.create(listId: 'inbox', title: '季度复盘');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '核对指标',
      );
      await repository.toggleChecklistItem(item.id);
      expect((await repository.getById(task.id))?.completed, isTrue);
      await repository.toggleChecklistItem(item.id);
      await db.delete(db.todoSyncChanges).go();

      await repository.toggleChecklistItem(item.id);

      final taskChanges = await (db.select(
        db.todoSyncChanges,
      )..where((change) => change.entityLocalId.equals(task.id))).get();
      expect(taskChanges, isEmpty, reason: '上一轮自动完成已经生效，重勾不该再排一条 DONE');
    });

    test('只读清单不替用户改父任务，也不追加 DONE 出队', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      final now = DateTime(2026, 7, 11, 9);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'shared-readonly',
              name: '共享清单',
              writable: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'ro-task',
              listId: 'shared-readonly',
              title: '共享里的任务',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.todoChecklistItems)
          .insert(
            TodoChecklistItemsCompanion.insert(
              id: 'ro-item',
              taskId: 'ro-task',
              title: '确认交付',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.delete(db.todoSyncChanges).go();

      await repository.toggleChecklistItem('ro-item');

      expect(
        (await repository.getById('ro-task'))?.completed,
        isFalse,
        reason: '只读清单里勾选项照常记录，但不该替协作者把任务判完成',
      );
      expect(
        await (db.select(
          db.todoSyncChanges,
        )..where((change) => change.entityLocalId.equals('ro-task'))).get(),
        isEmpty,
      );
    });
  });

  group('详情面板', () {
    testWidgets('勾完最后一条检查事项后主任务完成按钮变成取消勾选', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(760, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = fixture.container.read(taskRepositoryProvider)!;
      final item = await repository.createChecklistItem(
        taskId: TodoVisualFixture.metadataTaskId,
        title: '核对投放数据',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(
              body: TaskDetailPane(
                taskId: TodoVisualFixture.metadataTaskId,
                embedded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('勾选完成'), findsOneWidget);
      final checkbox = find.descendant(
        of: find.byKey(Key('checklist-item-${item.id}')),
        matching: find.byType(CheckboxListTile),
      );
      expect(checkbox, findsOneWidget);
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('取消勾选'),
        findsOneWidget,
        reason: '自动完成要经流刷新到详情头部，不能只写库不显示',
      );
      expect(
        (await repository.getById(TodoVisualFixture.metadataTaskId))?.completed,
        isTrue,
      );
    });
  });
}
