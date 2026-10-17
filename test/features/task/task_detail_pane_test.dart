import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

const _taskId = TodoVisualFixture.pinnedTaskId;
const _taskTitle = '确定今天最重要的三件事';
const _taskDescription = '先完成视觉母版，再处理交互细节。';
const _raceTaskAId = TodoVisualFixture.todayTaskId;
const _raceTaskATitle = '完成 Todo 工作区视觉评审';
const _raceTaskBId = TodoVisualFixture.secondaryTodayTaskId;
const _raceTaskBTitle = '回复设计反馈并确认下一步';

void main() {
  testWidgets('no selection keeps the desktop detail region neutral', (
    tester,
  ) async {
    await _pumpWideHome(tester);

    expect(_detailRegion, findsOneWidget);
    expect(_withinDetail(find.textContaining('选择任务')), findsOneWidget);
    expect(_withinDetail(find.byType(TextField)), findsNothing);
    _expectTodoDetailIdentity(selected: false);
  });

  testWidgets('selecting a task renders its real fields in the detail region', (
    tester,
  ) async {
    await _pumpWideHome(tester);

    await _selectFixtureTask(tester);

    expect(_withinDetail(find.text(_taskTitle)), findsOneWidget);
    expect(_withinDetail(find.text(_taskDescription)), findsOneWidget);
    expect(
      _withinDetail(find.textContaining(RegExp(r'(2026[-/]0?7[-/]11|7月11)'))),
      findsOneWidget,
    );
    expect(_withinDetail(find.text('收集箱')), findsOneWidget);
    _expectTodoDetailIdentity(selected: true);
  });

  testWidgets('时间段两个入口并排且有间距，不是上下紧贴的一整块', (tester) async {
    await _pumpWideHome(tester);
    await _selectFixtureTask(tester);

    await tester.scrollUntilVisible(
      find.text('时间段（可选）'),
      300,
      // 必须锁到详情区自己的 ListView：宽屏下第一个 Scrollable 是侧栏的，
      // 拖它到不了时间段，finder 永远解析不出来。
      scrollable: find
          .descendant(of: _detailRegion, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();

    final start = _withinDetail(find.widgetWithText(OutlinedButton, '设置开始时间'));
    final end = _withinDetail(find.widgetWithText(OutlinedButton, '设置结束时间'));
    expect(start, findsOneWidget);
    expect(end, findsOneWidget);

    final startRect = tester.getRect(start);
    final endRect = tester.getRect(end);
    // 并排：同一水平中线，且两者之间留出可见间距（原来上下堆叠、描边直接相接）。
    expect(startRect.center.dy, closeTo(endRect.center.dy, 0.5));
    expect(
      endRect.left - startRect.right,
      greaterThanOrEqualTo(8),
      reason: '两个入口之间必须有间距，不能连成一块',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏 390 下时间段两个入口仍并排、已设置的长值不溢出', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    // 把两个时刻都设上：并排后每格只有 ~170px，长值必须靠省略号收住而不是溢出。
    await (fixture.database.update(
      fixture.database.todoTasks,
    )..where((row) => row.id.equals(_taskId))).write(
      TodoTasksCompanion(
        startAt: Value(DateTime(2026, 7, 11, 9, 30)),
        endAt: Value(DateTime(2026, 7, 11, 10, 30)),
      ),
    );
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(
            body: TaskDetailPane(taskId: _taskId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('时间段（可选）'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final start = find.widgetWithIcon(
      OutlinedButton,
      Icons.play_circle_outline,
    );
    final end = find.widgetWithIcon(OutlinedButton, Icons.stop_circle_outlined);
    expect(start, findsOneWidget);
    expect(end, findsOneWidget);
    final first = tester.getRect(start);
    final second = tester.getRect(end);
    expect(first.center.dy, closeTo(second.center.dy, 0.5));
    expect(second.left - first.right, greaterThanOrEqualTo(8));
    expect(tester.takeException(), isNull, reason: '390 宽并排不能溢出');
  });

  testWidgets('closing detail clears only the selected task', (tester) async {
    await _pumpWideHome(tester);
    await _selectFixtureTask(tester);

    expect(_withinDetail(find.text(_taskTitle)), findsOneWidget);
    final closeButton = _withinDetail(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            (widget.tooltip == '关闭' || widget.tooltip == '关闭详情'),
        description: 'detail close button',
      ),
    );
    expect(closeButton, findsOneWidget);

    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(_withinDetail(find.textContaining('选择任务')), findsOneWidget);
    expect(_withinDetail(find.text(_taskTitle)), findsNothing);
    expect(find.text('收集箱'), findsWidgets);
  });

  testWidgets('deleting the selected task returns detail to no selection', (
    tester,
  ) async {
    final fixture = await _pumpWideHome(tester);
    await _selectFixtureTask(tester);

    expect(_withinDetail(find.text(_taskTitle)), findsOneWidget);
    final repository = fixture.container.read(taskRepositoryProvider);
    expect(repository, isNotNull);

    await repository!.delete(_taskId);
    await tester.pumpAndSettle();

    expect(_withinDetail(find.textContaining('选择任务')), findsOneWidget);
    expect(_withinDetail(find.text(_taskTitle)), findsNothing);
  });

  testWidgets('detail edits persist only after explicit save', (tester) async {
    final fixture = await _pumpWideHome(tester);
    await _selectFixtureTask(tester);

    final titleField = _detailTextField('标题');
    final descriptionField = _detailTextField('描述');
    expect(titleField, findsOneWidget);
    expect(descriptionField, findsOneWidget);

    const updatedTitle = '确认 Todo 详情交互验收';
    const updatedDescription = '仅在点击保存后写入本地仓库。';
    await tester.enterText(titleField, updatedTitle);
    await tester.enterText(descriptionField, updatedDescription);
    await tester.pump();

    final repository = fixture.container.read(taskRepositoryProvider)!;
    final beforeSave = await repository.getById(_taskId);
    expect(beforeSave?.title, _taskTitle);
    expect(beforeSave?.description, _taskDescription);

    final saveButton = _withinDetail(find.text('保存'));
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final afterSave = await repository.getById(_taskId);
    expect(afterSave?.title, updatedTitle);
    expect(afterSave?.description, updatedDescription);
  });

  testWidgets('detail editor exposes fixed-device semantic identifiers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpWideHome(tester);
    await _selectFixtureTask(tester);

    expect(
      find.bySemanticsIdentifier('todo_task_detail_title'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('todo_task_detail_description'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('todo_task_detail_save'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets(
    'mobile detail saves multiline content through its visible action',
    (tester) async {
      final fixture = await _pumpPagePane(tester, taskId: _taskId);
      const updatedDescription = '第一行\n第二行\n第三行\n第四行\n第五行\n第六行';

      await tester.enterText(_directTextField('描述'), updatedDescription);
      await tester.pump();

      final detailPage = find.byKey(const Key('todo_task_detail_page'));
      expect(detailPage, findsOneWidget);
      final saveAction = find.descendant(
        of: detailPage,
        matching: find.byKey(const Key('todo_task_detail_save_button')),
      );
      expect(saveAction, findsOneWidget);
      await tester.ensureVisible(saveAction);
      await tester.pumpAndSettle();
      await tester.tap(saveAction);
      await tester.pumpAndSettle();

      final task = await fixture.container
          .read(taskRepositoryProvider)!
          .getById(_taskId);
      expect(task?.description, updatedDescription);
    },
  );

  testWidgets(
    'detail long press edits a checklist item through the repository',
    (tester) async {
      final fixture = await _pumpDirectPane(tester, taskId: _taskId);
      final repository = fixture.container.read(taskRepositoryProvider)!;
      final item = await repository.createChecklistItem(
        taskId: _taskId,
        title: '整理数据',
      );
      await tester.pumpAndSettle();

      final checklistTitle = find.text('整理数据');
      await tester.ensureVisible(checklistTitle);
      await tester.pumpAndSettle();
      await tester.longPress(checklistTitle);
      await tester.pumpAndSettle();
      expect(find.text('编辑检查事项'), findsOneWidget);
      await tester.enterText(_directTextField('检查事项'), '复核数据');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final items = await (fixture.database.select(
        fixture.database.todoChecklistItems,
      )..where((entry) => entry.id.equals(item.id))).get();
      expect(items.single.title, '复核数据');
    },
  );

  testWidgets(
    'detail checklist handle performs a real drag and persists the new order',
    (tester) async {
      late _RecordingChecklistRepository repository;
      final fixture = await _pumpDirectPane(
        tester,
        taskId: _taskId,
        repositoryBuilder: (fixture) {
          repository = _RecordingChecklistRepository(fixture.database);
          return repository;
        },
      );
      final first = await repository.createChecklistItem(
        taskId: _taskId,
        title: '整理数据',
        sortOrder: 0,
      );
      final second = await repository.createChecklistItem(
        taskId: _taskId,
        title: '复核数据',
        sortOrder: 1,
      );
      await fixture.database.delete(fixture.database.todoSyncChanges).go();
      await tester.pumpAndSettle();

      await _dragChecklistItemAfter(
        tester,
        sourceItemId: first.id,
        targetItemId: second.id,
      );

      expect(repository.reorderRequests, [
        [second.id, first.id],
      ]);
      final items =
          await (fixture.database.select(fixture.database.todoChecklistItems)
                ..where((item) => item.taskId.equals(_taskId))
                ..orderBy([(item) => OrderingTerm(expression: item.sortOrder)]))
              .get();
      expect(items.map((item) => item.id), [second.id, first.id]);
      expect(
        await fixture.database.select(fixture.database.todoSyncChanges).get(),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'read-only checklist drag keeps its order and shows the repository reason',
    (tester) async {
      late _RecordingChecklistRepository repository;
      final fixture = await _pumpDirectPane(
        tester,
        taskId: _taskId,
        repositoryBuilder: (fixture) {
          repository = _RecordingChecklistRepository(
            fixture.database,
            failure: StateError('当前清单为只读，无法修改任务'),
          );
          return repository;
        },
      );
      final first = await repository.createChecklistItem(
        taskId: _taskId,
        title: '整理数据',
        sortOrder: 0,
      );
      final second = await repository.createChecklistItem(
        taskId: _taskId,
        title: '复核数据',
        sortOrder: 1,
      );
      await fixture.database.delete(fixture.database.todoSyncChanges).go();
      await tester.pumpAndSettle();

      await _dragChecklistItemAfter(
        tester,
        sourceItemId: first.id,
        targetItemId: second.id,
      );

      expect(find.text('当前清单为只读，无法修改任务'), findsOneWidget);
      final items =
          await (fixture.database.select(fixture.database.todoChecklistItems)
                ..where((item) => item.taskId.equals(_taskId))
                ..orderBy([(item) => OrderingTerm(expression: item.sortOrder)]))
              .get();
      expect(items.map((item) => item.id), [first.id, second.id]);
      expect(
        await fixture.database.select(fixture.database.todoSyncChanges).get(),
        isEmpty,
      );
    },
  );

  testWidgets('FL #603：换清单不再走 update(listId:)，而是走 moveToList', (tester) async {
    // 改前 `_save` 把 `listId` 一起交给 `update`，而仓储的 `_requireSectionInList`
    // 拿**旧清单的 sectionId** 去校验**新清单** ⇒ 带分组换清单当场抛错，
    // 用户看到的是"改不动"。修法是把换清单交给 `moveToList`（它清分组、子树跟着走、校验可写）。
    // 这条在**接缝**上钉：`update` 不许再收到 `listId`，且必须有一次 `moveToList`。
    late final _RecordingMoveRepository repository;
    await _pumpDirectPane(
      tester,
      taskId: _taskId,
      repositoryBuilder: (fixture) =>
          repository = _RecordingMoveRepository(fixture),
    );

    await tester.tap(find.byKey(const Key('task-list-$_taskId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生活').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      repository.updateListIds,
      isEmpty,
      reason: '换清单不许再借 update(listId:) —— 那条路会拿旧分组的 id 去校验新清单',
    );
    expect(repository.moves, [
      (_taskId, TodoVisualFixture.personalListId),
    ], reason: '换清单必须走 moveToList（子树、清分组、可写校验都在它身上）');
  });

  testWidgets(
    'detail moves a task to another list through the offline repository',
    (tester) async {
      final fixture = await _pumpDirectPane(tester, taskId: _taskId);
      final listPicker = find.byKey(const Key('task-list-visual-task-pinned'));

      expect(listPicker, findsOneWidget);
      await tester.tap(listPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('生活').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final task = await fixture.container
          .read(taskRepositoryProvider)!
          .getById(_taskId);
      expect(task?.listId, TodoVisualFixture.personalListId);
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(changes.last.entity, 'task');
      expect(
        changes.last.payloadJson,
        contains(TodoVisualFixture.personalListId),
      );
    },
  );

  testWidgets('late pin result from task A cannot overwrite selected task B', (
    tester,
  ) async {
    final selectedTaskId = ValueNotifier<String?>(_raceTaskAId);
    addTearDown(selectedTaskId.dispose);
    late _DelayedTogglePinRepository repository;
    var closeCount = 0;
    final unavailable = <String>[];

    await _pumpDirectPane(
      tester,
      selectedTaskId: selectedTaskId,
      onClose: () => closeCount++,
      onUnavailable: unavailable.add,
      repositoryBuilder: (fixture) {
        repository = _DelayedTogglePinRepository(fixture.database);
        return repository;
      },
    );

    expect(_directFieldValue(tester, '标题'), _raceTaskATitle);
    expect(find.byTooltip('置顶'), findsOneWidget);
    await tester.tap(find.byTooltip('置顶'));
    await tester.pump();
    expect(repository.started.isCompleted, isTrue);

    selectedTaskId.value = _raceTaskBId;
    await tester.pumpAndSettle();
    expect(_directFieldValue(tester, '标题'), _raceTaskBTitle);
    expect(find.byTooltip('置顶'), findsOneWidget);

    repository.release();
    await tester.pumpAndSettle();

    expect(_directFieldValue(tester, '标题'), _raceTaskBTitle);
    expect(find.byTooltip('置顶'), findsOneWidget);
    expect(find.byTooltip('取消置顶'), findsNothing);
    expect(closeCount, 0);
    expect(unavailable, isEmpty);
  });

  testWidgets('switching from task A to B replaces the displayed priority', (
    tester,
  ) async {
    final selectedTaskId = ValueNotifier<String?>(_raceTaskAId);
    addTearDown(selectedTaskId.dispose);
    await _pumpDirectPane(tester, selectedTaskId: selectedTaskId);

    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      2,
    );

    selectedTaskId.value = _raceTaskBId;
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      0,
    );
  });

  testWidgets('external updates refresh clean task fields and task state', (
    tester,
  ) async {
    final fixture = await _pumpDirectPane(tester, taskId: _taskId);
    final repository = fixture.container.read(taskRepositoryProvider)!;
    final externalDue = DateTime(2026, 7, 15, 14);

    await repository.update(_taskId, title: '外部同步后的任务标题', dueAt: externalDue);
    await repository.toggleComplete(_taskId);
    await tester.pumpAndSettle();

    expect(_directFieldValue(tester, '标题'), '外部同步后的任务标题');
    expect(find.textContaining('2026-07-15 14:00'), findsOneWidget);
    expect(find.byTooltip('取消勾选'), findsOneWidget);
  });

  testWidgets(
    'external updates preserve dirty title while refreshing due and completed',
    (tester) async {
      final fixture = await _pumpDirectPane(tester, taskId: _taskId);
      final repository = fixture.container.read(taskRepositoryProvider)!;
      const localDraft = '本地尚未保存的标题草稿';

      await tester.enterText(_directTextField('标题'), localDraft);
      await tester.pump();
      await repository.update(
        _taskId,
        title: '外部并发更新的标题',
        dueAt: DateTime(2026, 7, 16, 9, 30),
      );
      await repository.toggleComplete(_taskId);
      await tester.pumpAndSettle();

      expect(_directFieldValue(tester, '标题'), localDraft);
      expect(find.textContaining('2026-07-16 09:30'), findsOneWidget);
      expect(find.byTooltip('取消勾选'), findsOneWidget);

      final persisted = await repository.getById(_taskId);
      expect(persisted?.title, '外部并发更新的标题');
    },
  );

  testWidgets('missing task reports unavailable directly from the pane', (
    tester,
  ) async {
    final unavailable = <String>[];

    await _pumpDirectPane(
      tester,
      taskId: 'missing-task',
      onUnavailable: unavailable.add,
    );

    expect(unavailable, ['missing-task']);
    expect(find.text('任务不存在或已删除'), findsOneWidget);
  });

  testWidgets('deleting a directly pumped task reports unavailable once', (
    tester,
  ) async {
    final unavailable = <String>[];
    final fixture = await _pumpDirectPane(
      tester,
      taskId: _taskId,
      onUnavailable: unavailable.add,
    );

    await fixture.container.read(taskRepositoryProvider)!.delete(_taskId);
    await tester.pumpAndSettle();

    expect(unavailable, [_taskId]);
    expect(find.text('任务不存在或已删除'), findsOneWidget);
  });

  testWidgets(
    'detail shows queued attachments with a retryable delivery state',
    (tester) async {
      final fixture = await _pumpDirectPane(tester, taskId: _taskId);
      await fixture.container
          .read(taskRepositoryProvider)!
          .queueAttachment(
            taskId: _taskId,
            name: 'weekly-report.pdf',
            localPath: '/tmp/weekly-report.pdf',
            mimeType: 'application/pdf',
            size: 1024,
          );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('附件'), findsOneWidget);
      expect(find.text('weekly-report.pdf'), findsOneWidget);
      expect(find.text('等待上传'), findsOneWidget);
    },
  );

  testWidgets('mobile detail opens a local Markdown preview on demand', (
    tester,
  ) async {
    final fixture = await _pumpPagePane(tester, taskId: _taskId);
    const markdown = '## 本周目标\n\n完成 **B1 验收**';
    await fixture.container
        .read(taskRepositoryProvider)!
        .update(_taskId, description: markdown);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Markdown 预览'));
    await tester.pumpAndSettle();
    expect(find.text('本周目标'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.readOnly &&
            widget.controller.text.contains('B1 验收'),
        description: 'rendered Markdown content',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'detail subtask actions indent, outdent and detach through repository',
    (tester) async {
      final fixture = await _pumpDirectPane(
        tester,
        taskId: TodoVisualFixture.metadataTaskId,
      );
      const childId = 'visual-task-metadata-child-2';
      const previousId = 'visual-task-metadata-child-1';

      await _openSubtaskMenu(tester, childId);
      await tester.tap(find.byKey(Key('subtask-indent-$childId')));
      await tester.pumpAndSettle();
      expect(
        (await fixture.container.read(taskRepositoryProvider)!.getById(childId))
            ?.parentTaskId,
        previousId,
      );

      await _openSubtaskMenu(tester, childId);
      await tester.tap(find.byKey(Key('subtask-outdent-$childId')));
      await tester.pumpAndSettle();
      expect(
        (await fixture.container.read(taskRepositoryProvider)!.getById(childId))
            ?.parentTaskId,
        TodoVisualFixture.metadataTaskId,
      );

      await _openSubtaskMenu(tester, childId);
      await tester.tap(find.byKey(Key('subtask-detach-$childId')));
      await tester.pumpAndSettle();
      expect(
        (await fixture.container.read(taskRepositoryProvider)!.getById(childId))
            ?.parentTaskId,
        isNull,
      );
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(
        changes.where((change) => change.entityLocalId == childId),
        hasLength(3),
      );
    },
  );

  testWidgets('detail subtask drag persists sibling order and task outbox', (
    tester,
  ) async {
    final fixture = await _pumpDirectPane(
      tester,
      taskId: TodoVisualFixture.metadataTaskId,
    );
    const firstId = 'visual-task-metadata-child-1';
    const secondId = 'visual-task-metadata-child-2';
    final secondRow = find.byKey(const Key('subtask-row-$secondId'));
    await tester.scrollUntilVisible(
      secondRow,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final mouse = await _hover(tester, secondRow);
    await tester.pumpAndSettle();
    final handle = find.byKey(const Key('subtask-reorder-$secondId'));
    final firstRow = find.byKey(const Key('subtask-row-$firstId'));
    expect(handle, findsOneWidget);

    await tester.drag(
      handle,
      Offset(0, tester.getCenter(firstRow).dy - tester.getCenter(handle).dy),
    );
    await mouse.removePointer();
    await tester.pumpAndSettle();

    final children = await fixture.database.childrenOf(
      TodoVisualFixture.metadataTaskId,
    );
    expect(children.map((task) => task.id), [secondId, firstId]);
    final changes = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(changes.map((change) => change.entityLocalId), [secondId, firstId]);
  });

  testWidgets(
    'fifth-level sibling drag stays within its parent and is replayable',
    (tester) async {
      final fixture = await _pumpDirectPane(
        tester,
        taskId: TodoVisualFixture.metadataTaskId,
      );
      final repository = fixture.container.read(taskRepositoryProvider)!;
      var parentId = 'visual-task-metadata-child-1';
      for (var depth = 2; depth <= 4; depth++) {
        final task = await repository.create(
          listId: TodoVisualFixture.inboxListId,
          title: '第 $depth 层任务',
          parentTaskId: parentId,
        );
        parentId = task.id;
      }
      final first = await repository.create(
        listId: TodoVisualFixture.inboxListId,
        title: '第五层任务 A',
        parentTaskId: parentId,
      );
      final second = await repository.create(
        listId: TodoVisualFixture.inboxListId,
        title: '第五层任务 B',
        parentTaskId: parentId,
      );
      await fixture.database.delete(fixture.database.todoSyncChanges).go();
      await tester.pumpAndSettle();

      final secondRow = find.byKey(Key('subtask-row-${second.id}'));
      await tester.scrollUntilVisible(
        secondRow,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final mouse = await _hover(tester, secondRow);
      await tester.pumpAndSettle();
      final handle = find.byKey(Key('subtask-reorder-${second.id}'));
      final firstRow = find.byKey(Key('subtask-row-${first.id}'));
      await tester.drag(
        handle,
        Offset(0, tester.getCenter(firstRow).dy - tester.getCenter(handle).dy),
      );
      await mouse.removePointer();
      await tester.pumpAndSettle();

      expect(await repository.depthOf(first.id), 5);
      expect(await repository.depthOf(second.id), 5);
      expect(
        (await fixture.database.childrenOf(parentId)).map((task) => task.id),
        [second.id, first.id],
      );
      final changes = await fixture.database
          .select(fixture.database.todoSyncChanges)
          .get();
      expect(changes.map((change) => change.entityLocalId), [
        second.id,
        first.id,
      ]);
    },
  );

  testWidgets('nested subtask menu creates a child under the selected row', (
    tester,
  ) async {
    final fixture = await _pumpDirectPane(
      tester,
      taskId: TodoVisualFixture.metadataTaskId,
    );
    const parentId = 'visual-task-metadata-child-1';

    await _openSubtaskMenu(tester, parentId);
    await tester.tap(find.byKey(const Key('subtask-add-child-$parentId')));
    await tester.pumpAndSettle();
    expect(find.text('新建子任务'), findsOneWidget);
    final titleField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '标题',
    );
    await tester.enterText(titleField.last, '嵌套新增任务');
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    final created = await (fixture.database.select(
      fixture.database.todoTasks,
    )..where((row) => row.title.equals('嵌套新增任务'))).getSingle();
    expect(created.parentTaskId, parentId);
    final change = await (fixture.database.select(
      fixture.database.todoSyncChanges,
    )..where((row) => row.entityLocalId.equals(created.id))).getSingle();
    expect(change.entity, 'task');
  });

  testWidgets('read-only subtask hierarchy failure is visible and rolls back', (
    tester,
  ) async {
    final fixture = await _pumpDirectPane(
      tester,
      taskId: TodoVisualFixture.metadataTaskId,
    );
    final now = DateTime.utc(2026, 7, 30, 18);
    await fixture.database
        .into(fixture.database.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: TodoVisualFixture.inboxListId,
            name: '收集箱',
            writable: const Value(false),
            updatedAt: now,
            createdAt: now,
          ),
        );
    const childId = 'visual-task-metadata-child-2';

    await _openSubtaskMenu(tester, childId);
    await tester.tap(find.byKey(Key('subtask-indent-$childId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('当前清单为只读，无法修改任务'), findsOneWidget);
    expect(
      (await fixture.container.read(taskRepositoryProvider)!.getById(childId))
          ?.parentTaskId,
      TodoVisualFixture.metadataTaskId,
    );
    expect(
      await fixture.database.select(fixture.database.todoSyncChanges).get(),
      isEmpty,
    );
  });
}

Future<void> _openSubtaskMenu(WidgetTester tester, String taskId) async {
  final row = find.byKey(Key('subtask-row-$taskId'));
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  final mouse = await _hover(tester, row);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('subtask-more-$taskId')));
  await tester.pumpAndSettle();
  await mouse.removePointer();
}

Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(finder));
  await mouse.moveTo(tester.getCenter(finder));
  return mouse;
}

Finder get _detailRegion => find.byKey(const Key('todo-detail'));

Finder _withinDetail(Finder matching) =>
    find.descendant(of: _detailRegion, matching: matching);

Finder _detailTextField(String label) => _withinDetail(
  find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'detail $label field',
  ),
);

Future<TodoVisualFixture> _pumpWideHome(WidgetTester tester) {
  return pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const HomeShell(),
  );
}

Future<void> _selectFixtureTask(WidgetTester tester) async {
  final taskTitle = find.text(_taskTitle);
  expect(taskTitle, findsOneWidget);
  await tester.tap(taskTitle);
  await tester.pumpAndSettle();
}

Future<void> _dragChecklistItemAfter(
  WidgetTester tester, {
  required String sourceItemId,
  required String targetItemId,
}) async {
  final handle = find.byKey(Key('checklist-reorder-$sourceItemId'));
  final target = find.byKey(Key('checklist-item-$targetItemId'));
  expect(handle, findsOneWidget);
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.ensureVisible(handle);
  await tester.pumpAndSettle();
  await tester.drag(
    handle,
    Offset(0, tester.getCenter(target).dy - tester.getCenter(handle).dy),
  );
  await tester.pumpAndSettle();
}

void _expectTodoDetailIdentity({required bool selected}) {
  final key = selected ? 'todo-task-detail-pane' : 'todo-detail-no-selection';
  final label = selected ? '任务详情' : '选择任务以查看详情';
  expect(_withinDetail(find.byKey(Key(key))), findsOneWidget);
  expect(_withinDetail(find.text(label)), findsOneWidget);
}

Finder _directTextField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  description: 'direct pane $label field',
);

String _directFieldValue(WidgetTester tester, String label) {
  final field = tester.widget<TextField>(_directTextField(label));
  return field.controller!.text;
}

typedef _RepositoryBuilder = TaskRepository Function(TodoVisualFixture fixture);

Future<TodoVisualFixture> _pumpDirectPane(
  WidgetTester tester, {
  String? taskId,
  ValueNotifier<String?>? selectedTaskId,
  VoidCallback? onClose,
  ValueChanged<String>? onUnavailable,
  _RepositoryBuilder? repositoryBuilder,
  Future<void> Function(AppDatabase database)? prepare,
}) async {
  assert(taskId != null || selectedTaskId != null);
  final fixture = await TodoVisualFixture.create();
  addTearDown(fixture.dispose);
  // 种子必须在 pump 之前写：详情面板一 pump 就把这一行读进来并建好表单态。
  if (prepare != null) await prepare(fixture.database);

  tester.view.physicalSize = const Size(760, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Widget buildPane(String? currentTaskId) => TaskDetailPane(
    taskId: currentTaskId,
    embedded: true,
    onClose: onClose,
    onUnavailable: onUnavailable,
  );

  Widget pane = selectedTaskId == null
      ? buildPane(taskId)
      : ValueListenableBuilder<String?>(
          valueListenable: selectedTaskId,
          builder: (context, currentTaskId, _) => buildPane(currentTaskId),
        );
  final repository = repositoryBuilder?.call(fixture);
  if (repository != null) {
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

Future<TodoVisualFixture> _pumpPagePane(
  WidgetTester tester, {
  required String taskId,
}) async {
  final fixture = await TodoVisualFixture.create();
  addTearDown(fixture.dispose);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(body: TaskDetailPane(taskId: taskId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

class _DelayedTogglePinRepository extends TaskRepository {
  _DelayedTogglePinRepository(AppDatabase database)
    : super(database, SyncChangeQueue(database));

  final started = Completer<void>();
  final _release = Completer<void>();

  @override
  Future<TodoTask> togglePin(String taskId) async {
    if (!started.isCompleted) started.complete();
    await _release.future;
    return super.togglePin(taskId);
  }

  void release() {
    if (!_release.isCompleted) _release.complete();
  }
}

class _RecordingChecklistRepository extends TaskRepository {
  _RecordingChecklistRepository(AppDatabase database, {this.failure})
    : super(database, SyncChangeQueue(database));

  final Object? failure;
  final List<List<String>> reorderRequests = [];

  @override
  Future<void> reorderChecklistItems(
    String taskId,
    List<String> orderedItemIds,
  ) async {
    reorderRequests.add(List<String>.of(orderedItemIds));
    final error = failure;
    if (error != null) throw error;
    await super.reorderChecklistItems(taskId, orderedItemIds);
  }
}

/// 记录「换清单」走的是哪条通道（FL #603 的接缝判据）。
class _RecordingMoveRepository extends TaskRepository {
  _RecordingMoveRepository(TodoVisualFixture fixture)
    : super(fixture.database, SyncChangeQueue(fixture.database));

  /// `update` 每次收到的非空 `listId`（改前这里会有值，改后必须为空）。
  final List<String> updateListIds = [];

  /// `moveToList(taskId, targetListId)` 的调用记录。
  final List<(String, String)> moves = [];

  @override
  Future<TodoTask> update(
    String taskId, {
    String? title,
    String? description,
    int? priority,
    DateTime? startAt,
    DateTime? endAt,
    bool clearStartAt = false,
    bool clearEndAt = false,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? allDay,
    String? timeZone,
    bool? fixedTimezone,
    int? timeMode,
    String? listId,
    String? sectionId,
    bool clearSectionId = false,
    bool? isPinned,
  }) {
    if (listId != null) updateListIds.add(listId);
    return super.update(
      taskId,
      title: title,
      description: description,
      priority: priority,
      startAt: startAt,
      endAt: endAt,
      clearStartAt: clearStartAt,
      clearEndAt: clearEndAt,
      dueAt: dueAt,
      clearDueAt: clearDueAt,
      allDay: allDay,
      timeZone: timeZone,
      fixedTimezone: fixedTimezone,
      timeMode: timeMode,
      listId: listId,
      sectionId: sectionId,
      clearSectionId: clearSectionId,
      isPinned: isPinned,
    );
  }

  @override
  Future<List<TodoTask>> moveToList(String taskId, String targetListId) {
    moves.add((taskId, targetListId));
    return super.moveToList(taskId, targetListId);
  }
}
