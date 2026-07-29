import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_page.dart';

import '../support/todo_visual_fixture.dart';
import '../support/todo_visual_test_harness.dart';

enum TodoWorkspaceGoldenScenario {
  widePopulated,
  wideSelected,
  wideEmpty,
  wideLongContent,
  compactSelected,
  tabletList,
  mobileList,
  mobileDetail,
  mobileMinLong,
}

class TodoWorkspaceGoldenCase {
  const TodoWorkspaceGoldenCase({
    required this.scenario,
    required this.id,
    required this.viewport,
    required this.fixtureSet,
    this.selectedTaskId,
  });

  final TodoWorkspaceGoldenScenario scenario;
  final String id;
  final Size viewport;
  final TodoVisualFixtureSet fixtureSet;
  final String? selectedTaskId;
}

const todoWorkspaceGoldenCases = <TodoWorkspaceGoldenCase>[
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.widePopulated,
    id: 'wide-populated',
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.wideSelected,
    id: 'wide-selected',
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    selectedTaskId: TodoVisualFixture.pinnedTaskId,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.wideEmpty,
    id: 'wide-empty',
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.empty,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.wideLongContent,
    id: 'wide-long-content',
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.longContent,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.compactSelected,
    id: 'compact-selected',
    viewport: TodoVisualViewports.compact,
    fixtureSet: TodoVisualFixtureSet.populated,
    selectedTaskId: TodoVisualFixture.pinnedTaskId,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.tabletList,
    id: 'tablet-list',
    viewport: TodoVisualViewports.tablet,
    fixtureSet: TodoVisualFixtureSet.populated,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.mobileList,
    id: 'mobile-list',
    viewport: TodoVisualViewports.mobile,
    fixtureSet: TodoVisualFixtureSet.populated,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.mobileDetail,
    id: 'mobile-detail',
    viewport: TodoVisualViewports.mobile,
    fixtureSet: TodoVisualFixtureSet.populated,
    selectedTaskId: TodoVisualFixture.pinnedTaskId,
  ),
  TodoWorkspaceGoldenCase(
    scenario: TodoWorkspaceGoldenScenario.mobileMinLong,
    id: 'mobile-min-long',
    viewport: TodoVisualViewports.mobileMin,
    fixtureSet: TodoVisualFixtureSet.longContent,
  ),
];

void main() {
  final activeScenarios = TodoWorkspaceGoldenScenario.values.toSet();

  for (final goldenCase in todoWorkspaceGoldenCases.where(
    (candidate) => activeScenarios.contains(candidate.scenario),
  )) {
    testWidgets('${goldenCase.id} follows the workspace visual contract', (
      tester,
    ) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: goldenCase.viewport,
        fixtureSet: goldenCase.fixtureSet,
        child: const HomeShell(),
      );

      final selectedTaskId = goldenCase.selectedTaskId;
      if (selectedTaskId != null) {
        await _selectTaskAndSettle(tester, selectedTaskId);
      }

      _assertScenarioStructure(tester, goldenCase);
      expect(find.textContaining('加载失败'), findsNothing);

      await expectLater(
        _goldenTarget(goldenCase.scenario),
        matchesGoldenFile(todoGoldenPath(goldenCase.id)),
      );
    }, tags: const ['golden']);
  }
}

Future<void> _selectTaskAndSettle(
  WidgetTester tester,
  String selectedTaskId,
) async {
  final taskSurface = find.byKey(Key('task-row-surface-$selectedTaskId'));
  expect(taskSurface, findsOneWidget);
  await tester.ensureVisible(taskSurface);
  await tester.tap(taskSurface);
  await tester.pump();
  await tester.pumpAndSettle();
}

void _assertScenarioStructure(
  WidgetTester tester,
  TodoWorkspaceGoldenCase goldenCase,
) {
  switch (goldenCase.scenario) {
    case TodoWorkspaceGoldenScenario.widePopulated:
    case TodoWorkspaceGoldenScenario.wideEmpty:
    case TodoWorkspaceGoldenScenario.wideLongContent:
      _expectWideRegions();
      _expectDesktopAdd();
    case TodoWorkspaceGoldenScenario.wideSelected:
      _expectWideRegions();
      expect(
        find.byKey(
          const Key('task-row-selected-${TodoVisualFixture.pinnedTaskId}'),
        ),
        findsOneWidget,
      );
      expect(_withinDetail(find.text(_selectedTaskTitle)), findsOneWidget);
      expect(
        _withinDetail(find.text(_selectedTaskDescription)),
        findsOneWidget,
      );
      _expectDesktopAdd();
    case TodoWorkspaceGoldenScenario.compactSelected:
      expect(find.byKey(const Key('todo-rail')), findsOneWidget);
      expect(find.byKey(const Key('todo-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('todo-content')), findsOneWidget);
      expect(find.byKey(const Key('todo-detail')), findsNothing);
      expect(find.byKey(const Key('todo-mobile-nav')), findsNothing);
      final scaffoldState = tester.state<ScaffoldState>(
        find.byType(Scaffold).first,
      );
      expect(scaffoldState.isEndDrawerOpen, isTrue);
      expect(find.byKey(const Key('todo-detail-drawer')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('todo-detail-drawer')),
          matching: find.text(_selectedTaskTitle),
        ),
        findsOneWidget,
      );
      _expectDesktopAdd();
    case TodoWorkspaceGoldenScenario.tabletList:
      expect(find.byKey(const Key('todo-rail')), findsOneWidget);
      expect(find.byKey(const Key('todo-sidebar')), findsNothing);
      expect(find.byKey(const Key('todo-content')), findsOneWidget);
      expect(find.byKey(const Key('todo-detail')), findsNothing);
      expect(find.byKey(const Key('todo-mobile-nav')), findsNothing);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isA<Drawer>());
      expect(scaffold.drawer!.key, const Key('todo-sidebar-drawer'));
      expect(scaffold.endDrawer, isA<Drawer>());
      expect(scaffold.endDrawer!.key, const Key('todo-detail-drawer'));
      _expectDesktopAdd();
    case TodoWorkspaceGoldenScenario.mobileList:
    case TodoWorkspaceGoldenScenario.mobileMinLong:
      _expectMobileListRegions(tester);
      _expectMobileAdd();
      if (goldenCase.scenario == TodoWorkspaceGoldenScenario.mobileMinLong) {
        expect(
          find.byKey(
            const Key('task-row-${TodoVisualFixture.longContentTaskId}'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('需要跨团队协作确认'), findsOneWidget);
      }
    case TodoWorkspaceGoldenScenario.mobileDetail:
      expect(find.byType(TaskDetailPage), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text(_selectedTaskDescription), findsOneWidget);
      expect(find.byKey(const Key('todo-rail')), findsNothing);
      expect(find.byKey(const Key('todo-sidebar')), findsNothing);
      expect(find.byKey(const Key('todo-content')), findsNothing);
      expect(find.byKey(const Key('todo-detail')), findsNothing);
      expect(find.byKey(const Key('todo-mobile-nav')), findsNothing);
      expect(find.byType(QuickAddBar), findsNothing);
      expect(find.byKey(const Key('todo-mobile-add')), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
  }
}

void _expectWideRegions() {
  expect(find.byKey(const Key('todo-rail')), findsOneWidget);
  expect(find.byKey(const Key('todo-sidebar')), findsOneWidget);
  expect(find.byKey(const Key('todo-content')), findsOneWidget);
  expect(find.byKey(const Key('todo-detail')), findsOneWidget);
  expect(find.byKey(const Key('todo-mobile-nav')), findsNothing);
}

void _expectMobileListRegions(WidgetTester tester) {
  expect(find.byKey(const Key('todo-content')), findsOneWidget);
  expect(find.byKey(const Key('todo-mobile-nav')), findsOneWidget);
  expect(find.byKey(const Key('todo-rail')), findsNothing);
  expect(find.byKey(const Key('todo-sidebar')), findsNothing);
  expect(find.byKey(const Key('todo-detail')), findsNothing);
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  expect(scaffold.drawer, isA<Drawer>());
  expect(scaffold.drawer!.key, const Key('todo-sidebar-drawer'));
  expect(scaffold.endDrawer, isNull);
}

void _expectDesktopAdd() {
  expect(find.byType(QuickAddBar), findsOneWidget);
  expect(find.byType(MobileQuickAddButton), findsNothing);
  expect(find.byKey(const Key('todo-mobile-add')), findsNothing);
  expect(find.byType(FloatingActionButton), findsNothing);
}

void _expectMobileAdd() {
  expect(find.byType(QuickAddBar), findsNothing);
  expect(find.byType(MobileQuickAddButton), findsOneWidget);
  expect(find.byKey(const Key('todo-mobile-add')), findsOneWidget);
  expect(find.byType(FloatingActionButton), findsOneWidget);
}

Finder _withinDetail(Finder matching) => find.descendant(
  of: find.byKey(const Key('todo-detail')),
  matching: matching,
);

Finder _goldenTarget(TodoWorkspaceGoldenScenario scenario) {
  if (scenario == TodoWorkspaceGoldenScenario.mobileDetail) {
    return find.byType(TaskDetailPage);
  }
  return find.byKey(todoVisualRootKey);
}

const _selectedTaskTitle = '确定今天最重要的三件事';
const _selectedTaskDescription = '先完成视觉母版，再处理交互细节。';
