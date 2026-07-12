import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

const _taskTitle = '确定今天最重要的三件事';
const _taskDescription = '先完成视觉母版，再处理交互细节。';
const _longTaskTitle =
    '整理 Todo 在网页、手机与桌面端的高保真交互验收反馈，并与设计和研发确认不会影响既有离线同步能力的下一轮修改范围';
const _lastTaskId = 'visual-task-completed';

void main() {
  testWidgets('390 mobile shows one task column and one mobile add entry', (
    tester,
  ) async {
    await _pumpMobile(
      tester,
      viewport: TodoVisualViewports.mobile,
      fixtureSet: TodoVisualFixtureSet.populated,
    );

    expect(find.byKey(const Key('todo-content')), findsOneWidget);
    expect(find.byKey(const Key('todo-mobile-nav')), findsOneWidget);
    expect(find.byKey(const Key('todo-rail')), findsNothing);
    expect(find.byKey(const Key('todo-sidebar')), findsNothing);
    expect(find.byKey(const Key('todo-detail')), findsNothing);
    expect(find.byType(QuickAddBar), findsNothing);

    final mobileAdd = find.byKey(const Key('todo-mobile-add'));
    expect(mobileAdd, findsOneWidget);
    expect(mobileAdd.hitTestable(), findsOneWidget);
  });

  testWidgets('mobile add submits one task to the current inbox', (
    tester,
  ) async {
    final fixture = await _pumpMobile(
      tester,
      viewport: TodoVisualViewports.mobile,
      fixtureSet: TodoVisualFixtureSet.populated,
    );
    const title = '移动端快速添加验收任务';

    await tester.tap(find.byKey(const Key('todo-mobile-add')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('todo-mobile-add-field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(field, findsNothing);
    expect(find.text(title), findsOneWidget);
    final tasks = await fixture.database
        .select(fixture.database.todoTasks)
        .get();
    final created = tasks.singleWhere((task) => task.title == title);
    expect(created.listId, TodoVisualFixture.inboxListId);
  });

  testWidgets(
    '360 mobile quick add exposes date priority and tag overrides without overflow',
    (tester) async {
      await _pumpMobile(
        tester,
        viewport: TodoVisualViewports.mobileMin,
        fixtureSet: TodoVisualFixtureSet.populated,
      );

      await tester.tap(find.byKey(const Key('todo-mobile-add')));
      await tester.pumpAndSettle();

      expect(find.text('日期'), findsOneWidget);
      expect(find.text('无优先级'), findsOneWidget);
      expect(find.text('标签'), findsOneWidget);
      expect(
        _drainRenderingErrors(tester),
        isEmpty,
        reason: 'mobile quick add fields must remain usable at 360px width',
      );
    },
  );

  testWidgets('mobile sidebar selection closes the drawer after navigation', (
    tester,
  ) async {
    await _pumpMobile(
      tester,
      viewport: TodoVisualViewports.mobile,
      fixtureSet: TodoVisualFixtureSet.populated,
    );

    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();
    expect(_workspaceScaffoldState(tester).isDrawerOpen, isTrue);
    await tester.tap(find.byKey(const Key('todo-sidebar-row-today')));
    await tester.pumpAndSettle();

    expect(_workspaceScaffoldState(tester).isDrawerOpen, isFalse);
    expect(_workspaceHeaderText('今天'), findsOneWidget);
  });

  testWidgets(
    '390 task tap opens a full-screen detail without desktop regions',
    (tester) async {
      await _pumpMobile(
        tester,
        viewport: TodoVisualViewports.mobile,
        fixtureSet: TodoVisualFixtureSet.populated,
      );

      await tester.tap(find.text(_taskTitle));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailPage), findsOneWidget);
      expect(find.byType(TaskDetailPane), findsOneWidget);
      expect(find.text(_taskDescription), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('todo-mobile-nav')), findsNothing);
      expect(find.byKey(const Key('todo-rail')), findsNothing);
      expect(find.byKey(const Key('todo-sidebar')), findsNothing);
      expect(find.byKey(const Key('todo-detail')), findsNothing);

      final detailScaffold = find.descendant(
        of: find.byType(TaskDetailPage),
        matching: find.byType(Scaffold),
      );
      expect(detailScaffold, findsOneWidget);
      expect(tester.getSize(detailScaffold), TodoVisualViewports.mobile);
    },
  );

  testWidgets('mobile back returns to the same selected smart list', (
    tester,
  ) async {
    await _pumpMobile(
      tester,
      viewport: TodoVisualViewports.mobile,
      fixtureSet: TodoVisualFixtureSet.populated,
    );
    await _selectTodayFromDrawer(tester);

    expect(_workspaceHeaderText('今天'), findsOneWidget);
    await tester.tap(find.text(_taskTitle));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailPage), findsNothing);
    expect(find.byKey(const Key('todo-mobile-nav')), findsOneWidget);
    expect(_workspaceHeaderText('今天'), findsOneWidget);
    expect(find.text(_taskTitle), findsOneWidget);
  });

  testWidgets('360 long content at 1.3 text scale has no rendering overflow', (
    tester,
  ) async {
    await _pumpMobile(
      tester,
      viewport: TodoVisualViewports.mobileMin,
      fixtureSet: TodoVisualFixtureSet.longContent,
      textScale: 1.3,
    );

    expect(find.text(_longTaskTitle), findsOneWidget);
    expect(find.textContaining('需要跨团队协作确认'), findsOneWidget);

    final longTaskRow = find.byKey(
      const Key('task-row-${TodoVisualFixture.longContentTaskId}'),
    );
    expect(longTaskRow, findsOneWidget);
    await tester.ensureVisible(longTaskRow);
    await tester.pumpAndSettle();
    expect(longTaskRow.hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: longTaskRow, matching: find.byType(AppCheckbox)),
      findsOneWidget,
    );

    final renderingErrors = _drainRenderingErrors(tester);
    expect(
      renderingErrors,
      isEmpty,
      reason: '360×800 at 1.3 text scale must not overflow or throw',
    );
  });

  testWidgets(
    '360 full-screen detail at 1.3 keeps task actions reachable without overflow',
    (tester) async {
      await _pumpMobile(
        tester,
        viewport: TodoVisualViewports.mobileMin,
        fixtureSet: TodoVisualFixtureSet.longContent,
        textScale: 1.3,
      );

      final longTask = find.byKey(
        const Key('task-row-surface-${TodoVisualFixture.longContentTaskId}'),
      );
      await tester.ensureVisible(longTask);
      await tester.tap(longTask);
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailPage), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byTooltip('勾选完成'), findsOneWidget);
      final more = find.byTooltip('更多任务操作');
      expect(more, findsOneWidget);
      expect(more.hitTestable(), findsOneWidget);

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('置顶'), findsOneWidget);
      expect(find.text('移至收件箱'), findsOneWidget);
      expect(find.text('协作'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      expect(
        _drainRenderingErrors(tester),
        isEmpty,
        reason: 'mobile detail controls must not overflow at 1.3 text scale',
      );
    },
  );

  for (final viewport in const [
    TodoVisualViewports.mobile,
    TodoVisualViewports.mobileMin,
  ]) {
    testWidgets(
      '${viewport.width.toInt()} mobile FAB does not cover the final task row',
      (tester) async {
        await _pumpMobile(
          tester,
          viewport: viewport,
          fixtureSet: TodoVisualFixtureSet.populated,
        );

        final lastTask = find.byKey(const Key('task-row-surface-$_lastTaskId'));
        await tester.scrollUntilVisible(
          lastTask,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final mobileAdd = find.byKey(const Key('todo-mobile-add'));
        expect(mobileAdd, findsOneWidget);
        expect(lastTask, findsOneWidget);
        final addRect = tester.getRect(mobileAdd);
        final lastTaskRect = tester.getRect(lastTask);
        expect(
          addRect.overlaps(lastTaskRect),
          isFalse,
          reason: 'the mobile add control must not obscure the final task row',
        );
        expect(lastTask.hitTestable(), findsOneWidget);

        await tester.tap(lastTask);
        await tester.pumpAndSettle();
        expect(
          find.byType(TaskDetailPage),
          findsOneWidget,
          reason: 'the final task row must remain selectable',
        );
      },
    );
  }
}

Future<TodoVisualFixture> _pumpMobile(
  WidgetTester tester, {
  required Size viewport,
  required TodoVisualFixtureSet fixtureSet,
  double textScale = 1,
}) {
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport,
    fixtureSet: fixtureSet,
    child: _TextScaledHome(textScale: textScale),
  );
}

Future<void> _selectTodayFromDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('菜单'));
  await tester.pumpAndSettle();
  final todayRow = find.byKey(const Key('todo-sidebar-row-today'));
  expect(todayRow, findsOneWidget);
  await tester.tap(todayRow);
  await tester.pump();
  await tester.tapAt(const Offset(380, 300));
  await tester.pumpAndSettle();
}

ScaffoldState _workspaceScaffoldState(WidgetTester tester) {
  return tester.state<ScaffoldState>(find.byType(Scaffold).first);
}

Finder _workspaceHeaderText(String text) => find.descendant(
  of: find.byKey(const Key('todo-task-workspace-header')),
  matching: find.text(text),
);

List<Object> _drainRenderingErrors(WidgetTester tester) {
  final errors = <Object>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    errors.add(error!);
  }
  return errors;
}

class _TextScaledHome extends StatelessWidget {
  const _TextScaledHome({required this.textScale});

  final double textScale;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale));
    return MediaQuery(data: media, child: const HomeShell());
  }
}
