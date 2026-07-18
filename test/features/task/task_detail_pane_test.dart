import 'dart:async';

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
}) async {
  assert(taskId != null || selectedTaskId != null);
  final fixture = await TodoVisualFixture.create();
  addTearDown(fixture.dispose);

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
