import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/home/todo_workspace.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

const _selectedTaskId = TodoVisualFixture.metadataTaskId;
const _selectedTaskTitle = '准备项目周会材料';
const _personalTaskId = 'visual-task-personal-list';
const _personalTaskTitle = '规划周末骑行路线';
const _acceptanceViewports = [
  (name: 'wide', size: TodoVisualViewports.wide),
  (name: 'compact', size: TodoVisualViewports.compact),
  (name: 'tablet', size: TodoVisualViewports.tablet),
  (name: 'mobile', size: TodoVisualViewports.mobile),
  (name: 'mobile-min', size: TodoVisualViewports.mobileMin),
];

void main() {
  testWidgets('1440 workspace exposes the four product-owned regions', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    final rail = find.byKey(const Key('todo-rail'));
    final sidebar = find.byKey(const Key('todo-sidebar'));
    final content = find.byKey(const Key('todo-content'));
    final detail = find.byKey(const Key('todo-detail'));

    expect(rail, findsOneWidget);
    expect(sidebar, findsOneWidget);
    expect(content, findsOneWidget);
    expect(detail, findsOneWidget);

    if (rail.evaluate().isEmpty ||
        sidebar.evaluate().isEmpty ||
        content.evaluate().isEmpty ||
        detail.evaluate().isEmpty) {
      return;
    }

    expect(tester.getSize(rail).width, 56);
    expect(tester.getSize(sidebar).width, 272);
    expect(tester.getSize(detail).width, 432);
    expect(tester.getSize(content).width, greaterThanOrEqualTo(520));
  });

  testWidgets('workspace exposes stable Todo product semantic keys', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    for (final key in const [
      Key('todo-rail'),
      Key('todo-sidebar'),
      Key('todo-content'),
      Key('todo-detail'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
  });

  testWidgets(
    'sync status announcement does not cover the workspace hit area',
    (tester) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: TodoVisualViewports.wide,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      final announcement = find.bySemanticsIdentifier('todo_sync_status');
      expect(announcement, findsOneWidget);
      // 播报锚点挂在 StackFit.expand 的 Stack 里：若不给松弛约束，
      // SizedBox 会被撑满整个工作区，Web 无障碍层随之铺满视口并吞掉全部点击。
      expect(
        tester.getSize(announcement),
        TodoSyncStatusAnnouncement.anchorSize,
        reason: '同步状态播报锚点必须保持最小尺寸，不能覆盖工作区命中区域',
      );
    },
  );

  for (final scenario in const [
    (name: 'wide', viewport: TodoVisualViewports.wide),
    (name: 'compact', viewport: TodoVisualViewports.compact),
  ]) {
    testWidgets('${scenario.name} 垃圾桶空态在内容区水平居中', (tester) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: scenario.viewport,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('todo-sidebar')),
          matching: find.text('垃圾桶'),
        ),
      );
      await tester.pumpAndSettle();

      final empty = find.byType(AppEmptyState);
      expect(empty, findsOneWidget);

      final content = find.byKey(const Key('todo-content'));
      expect(content, findsOneWidget);
      // 内容区被 Stack 包着，默认 StackFit.loose 会给子节点松弛约束：
      // 空态会缩成「内容宽度」贴在左边，而不是铺满内容区后居中。
      expect(
        tester.getCenter(empty).dx,
        closeTo(tester.getCenter(content).dx, 1),
        reason: '空态必须铺满内容区后居中，不能缩成内容宽度靠左显示',
      );
    });
  }

  for (final scenario in const [
    (name: 'desktop', viewport: TodoVisualViewports.wide),
    (name: 'mobile', viewport: TodoVisualViewports.mobile),
  ]) {
    testWidgets('${scenario.name} reminder entry opens the inbox', (
      tester,
    ) async {
      await pumpTodoVisualScenario(
        tester,
        viewport: scenario.viewport,
        fixtureSet: TodoVisualFixtureSet.populated,
        child: const HomeShell(),
      );

      if (scenario.name == 'mobile') {
        await tester.tap(find.byTooltip('菜单'));
        await tester.pumpAndSettle();
      }
      final sidebarSurface = scenario.name == 'mobile'
          ? find.byKey(const Key('todo-sidebar-drawer'))
          : find.byKey(const Key('todo-sidebar'));
      final reminderAction = find.byKey(
        const Key('todo-reminder-inbox-action'),
      );
      await tester.scrollUntilVisible(
        reminderAction,
        300,
        scrollable: find
            .descendant(of: sidebarSurface, matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(reminderAction);
      await tester.pumpAndSettle();

      expect(find.text('提醒收件箱'), findsOneWidget);
    });
  }

  testWidgets('no-selection detail uses the neutral Todo guidance', (
    tester,
  ) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );

    final detail = find.byKey(const Key('todo-detail'));
    expect(
      find.descendant(
        of: detail,
        matching: find.byKey(const Key('todo-detail-no-selection')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('选择任务以查看详情')),
      findsOneWidget,
    );
  });

  testWidgets('1280 compact keeps navigation fixed and opens one end drawer', (
    tester,
  ) async {
    await _pumpWorkspace(tester, TodoVisualViewports.compact);

    expect(_currentProfile(), _WorkspaceProfile.compact);
    expect(tester.getSize(find.byKey(const Key('todo-rail'))).width, 56);
    expect(tester.getSize(find.byKey(const Key('todo-sidebar'))).width, 256);
    final scaffoldWidget = _workspaceScaffold(tester);
    expect(scaffoldWidget.drawer, isNull);
    expect(scaffoldWidget.endDrawer, isA<Drawer>());
    expect(scaffoldWidget.endDrawer!.key, const Key('todo-detail-drawer'));
    expect(find.byKey(const Key('todo-detail')), findsNothing);

    await _tapTask(tester, _selectedTaskId);

    final scaffold = _workspaceScaffoldState(tester);
    expect(
      scaffold.isEndDrawerOpen,
      isTrue,
      reason: 'compact selection must open the contracted end drawer',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('todo-detail-drawer')),
        matching: find.text(_selectedTaskTitle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('1024 tablet uses sidebar and detail drawers', (tester) async {
    await _pumpWorkspace(tester, TodoVisualViewports.tablet);

    expect(_currentProfile(), _WorkspaceProfile.tablet);
    final scaffoldWidget = _workspaceScaffold(tester);
    expect(scaffoldWidget.drawer, isA<Drawer>());
    expect(scaffoldWidget.drawer!.key, const Key('todo-sidebar-drawer'));
    expect(scaffoldWidget.endDrawer, isA<Drawer>());
    expect(scaffoldWidget.endDrawer!.key, const Key('todo-detail-drawer'));
    expect(find.byKey(const Key('todo-sidebar')), findsNothing);
    expect(find.byKey(const Key('todo-detail')), findsNothing);

    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();
    var scaffold = _workspaceScaffoldState(tester);
    expect(scaffold.isDrawerOpen, isTrue);
    scaffold.closeDrawer();
    await tester.pumpAndSettle();

    await _tapTask(tester, _selectedTaskId);
    scaffold = _workspaceScaffoldState(tester);
    expect(
      scaffold.isEndDrawerOpen,
      isTrue,
      reason: 'tablet selection must open its detail overlay',
    );
  });

  testWidgets('390 mobile exposes one content column and mobile navigation', (
    tester,
  ) async {
    await _pumpWorkspace(tester, TodoVisualViewports.mobile);

    expect(_currentProfile(), _WorkspaceProfile.mobile);
    expect(find.byKey(const Key('todo-content')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('todo-content'))).width,
      TodoVisualViewports.mobile.width,
    );
    expect(find.byKey(const Key('todo-rail')), findsNothing);
    expect(find.byKey(const Key('todo-sidebar')), findsNothing);
    expect(find.byKey(const Key('todo-detail')), findsNothing);
    expect(find.byKey(const Key('todo-detail-drawer')), findsNothing);
    expect(find.byKey(const Key('todo-mobile-nav')), findsOneWidget);
    final scaffoldWidget = _workspaceScaffold(tester);
    expect(scaffoldWidget.drawer, isA<Drawer>());
    expect(scaffoldWidget.drawer!.key, const Key('todo-sidebar-drawer'));
    expect(scaffoldWidget.endDrawer, isNull);
  });

  for (final viewportCase in _acceptanceViewports) {
    testWidgets(
      '${viewportCase.name} supports long content at 1.3x without overflow',
      (tester) async {
        await pumpTodoVisualScenario(
          tester,
          viewport: viewportCase.size,
          fixtureSet: TodoVisualFixtureSet.longContent,
          child: const _TextScaledHome(textScale: 1.3),
        );

        final longTask = find.byKey(
          const Key('task-row-${TodoVisualFixture.longContentTaskId}'),
        );
        expect(longTask, findsOneWidget);
        await tester.ensureVisible(longTask);
        await tester.pumpAndSettle();
        expect(longTask.hitTestable(), findsOneWidget);

        final primaryAdd = viewportCase.size.width < 600
            ? find.byKey(const Key('todo-mobile-add'))
            : find.byKey(const Key('todo-quick-add'));
        expect(primaryAdd.hitTestable(), findsOneWidget);
        expect(
          _drainRenderingErrors(tester),
          isEmpty,
          reason:
              '${viewportCase.name} must keep long content and primary actions reachable at 1.3x',
        );
      },
    );

    testWidgets(
      '${viewportCase.name} keeps the empty no-selection state stable at 1.3x',
      (tester) async {
        await pumpTodoVisualScenario(
          tester,
          viewport: viewportCase.size,
          fixtureSet: TodoVisualFixtureSet.empty,
          child: const _TextScaledHome(textScale: 1.3),
        );

        expect(find.byKey(const Key('todo-content')), findsOneWidget);
        expect(find.text('暂无任务'), findsOneWidget);
        expect(
          find.byKey(
            const Key('task-row-${TodoVisualFixture.longContentTaskId}'),
          ),
          findsNothing,
        );
        expect(
          _drainRenderingErrors(tester),
          isEmpty,
          reason:
              '${viewportCase.name} must keep empty and no-selection states readable at 1.3x',
        );
      },
    );
  }

  testWidgets('each responsive breakpoint performs one structural transition', (
    tester,
  ) async {
    await _pumpWorkspace(tester, const Size(1367, 800));

    final cases = <_BreakpointCase>[
      const _BreakpointCase(
        widths: [1367, 1366, 1365],
        profiles: [
          _WorkspaceProfile.wide,
          _WorkspaceProfile.wide,
          _WorkspaceProfile.compact,
        ],
      ),
      const _BreakpointCase(
        widths: [1101, 1100, 1099],
        profiles: [
          _WorkspaceProfile.compact,
          _WorkspaceProfile.compact,
          _WorkspaceProfile.tablet,
        ],
      ),
      const _BreakpointCase(
        widths: [601, 600, 599],
        profiles: [
          _WorkspaceProfile.tablet,
          _WorkspaceProfile.tablet,
          _WorkspaceProfile.mobile,
        ],
      ),
    ];

    for (final breakpointCase in cases) {
      final actual = <_WorkspaceProfile>[];
      for (final width in breakpointCase.widths) {
        await _resize(tester, Size(width.toDouble(), 800));
        actual.add(_currentProfile());
        expect(find.byKey(const Key('todo-content')), findsOneWidget);
      }
      expect(actual, breakpointCase.profiles);
      expect(
        _transitionCount(actual),
        1,
        reason:
            'crossing ${breakpointCase.widths[1]} must change structure once',
      );
    }
  });

  testWidgets('resize preserves selected task and ordinary-list identity', (
    tester,
  ) async {
    await _pumpWorkspace(tester, TodoVisualViewports.wide);

    await _selectPersonalList(tester);
    expect(_contentText(_personalTaskTitle), findsOneWidget);

    await _tapTask(tester, _personalTaskId);
    expect(
      find.byKey(const Key('task-row-selected-$_personalTaskId')),
      findsOneWidget,
    );
    expect(_detailText(_personalTaskTitle), findsOneWidget);

    for (final viewport in const [
      TodoVisualViewports.compact,
      TodoVisualViewports.tablet,
      TodoVisualViewports.mobile,
      TodoVisualViewports.wide,
    ]) {
      await _resize(tester, viewport);
    }

    expect(_currentProfile(), _WorkspaceProfile.wide);
    expect(_contentText(_personalTaskTitle), findsOneWidget);
    expect(
      find.byKey(const Key('task-row-selected-$_personalTaskId')),
      findsOneWidget,
      reason: 'task selection must remain attached to its stable task ID',
    );
    expect(_detailText(_personalTaskTitle), findsOneWidget);
    await _revealPersonalList(tester);
    expect(
      find.byKey(
        const ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
      ),
      findsOneWidget,
      reason: 'resize must not reset the selected ordinary list',
    );
  });

  testWidgets('compact selection does not queue repeated drawer opens', (
    tester,
  ) async {
    await _pumpWorkspace(tester, TodoVisualViewports.compact);

    await _tapTask(tester, _selectedTaskId);
    var scaffold = _workspaceScaffoldState(tester);
    expect(scaffold.isEndDrawerOpen, isTrue);

    await _resize(tester, const Size(1279, 800));
    await _resize(tester, const Size(1280, 800));
    scaffold = _workspaceScaffoldState(tester);
    expect(scaffold.isEndDrawerOpen, isTrue);

    scaffold.closeEndDrawer();
    await tester.pumpAndSettle();
    expect(_workspaceScaffoldState(tester).isEndDrawerOpen, isFalse);

    await tester.pumpAndSettle();
    expect(
      _workspaceScaffoldState(tester).isEndDrawerOpen,
      isFalse,
      reason: 'one selection must not leave another auto-open callback queued',
    );
  });

  for (final drawerCase in const [
    (name: 'compact', viewport: TodoVisualViewports.compact),
    (name: 'tablet', viewport: TodoVisualViewports.tablet),
  ]) {
    testWidgets(
      '${drawerCase.name} user-closing detail clears task but keeps list',
      (tester) async {
        await _pumpWorkspace(tester, drawerCase.viewport);
        await _selectPersonalList(tester);
        expect(_contentText(_personalTaskTitle), findsOneWidget);

        await _tapTask(tester, _personalTaskId);
        var scaffold = _workspaceScaffoldState(tester);
        expect(scaffold.isEndDrawerOpen, isTrue);
        expect(
          find.byKey(const Key('task-row-selected-$_personalTaskId')),
          findsOneWidget,
        );

        scaffold.closeEndDrawer();
        await tester.pumpAndSettle();

        scaffold = _workspaceScaffoldState(tester);
        expect(scaffold.isEndDrawerOpen, isFalse);
        expect(
          find.byKey(const Key('task-row-selected-$_personalTaskId')),
          findsNothing,
          reason: 'closing the detail presentation must clear task selection',
        );
        expect(
          _contentText(_personalTaskTitle),
          findsOneWidget,
          reason: 'closing detail must not reset the ordinary list',
        );

        await tester.pump(const Duration(milliseconds: 300));
        expect(
          _workspaceScaffoldState(tester).isEndDrawerOpen,
          isFalse,
          reason:
              'a manually closed detail must not reopen from stale selection',
        );
      },
    );
  }
}

Future<TodoVisualFixture> _pumpWorkspace(WidgetTester tester, Size viewport) {
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const HomeShell(),
  );
}

Future<void> _resize(WidgetTester tester, Size viewport) async {
  tester.view.physicalSize = viewport;
  await tester.pumpAndSettle();
}

Future<void> _tapTask(WidgetTester tester, String taskId) async {
  final surface = find.byKey(Key('task-row-surface-$taskId'));
  expect(surface, findsOneWidget);
  await tester.ensureVisible(surface);
  await tester.tap(surface);
  await tester.pumpAndSettle();
}

Future<void> _selectPersonalList(WidgetTester tester) async {
  if (_currentProfile() == _WorkspaceProfile.tablet) {
    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();
  }

  await _revealPersonalList(tester);
  final personalList = find.byKey(
    const ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
  );
  await tester.tap(personalList);
  await tester.pump();

  final scaffold = _workspaceScaffoldState(tester);
  if (scaffold.isDrawerOpen) {
    scaffold.closeDrawer();
  }
  await tester.pumpAndSettle();
}

Future<void> _revealPersonalList(WidgetTester tester) async {
  final profile = _currentProfile();
  final sidebarSurface =
      profile == _WorkspaceProfile.tablet || profile == _WorkspaceProfile.mobile
      ? find.byKey(const Key('todo-sidebar-drawer'))
      : find.byKey(const Key('todo-sidebar'));
  final personalList = find.byKey(
    const ValueKey('todo-sidebar-list-${TodoVisualFixture.personalListId}'),
  );
  await tester.scrollUntilVisible(
    personalList,
    300,
    scrollable: find
        .descendant(of: sidebarSurface, matching: find.byType(Scrollable))
        .first,
  );
  expect(personalList, findsOneWidget);
}

ScaffoldState _workspaceScaffoldState(WidgetTester tester) {
  return tester.state<ScaffoldState>(find.byType(Scaffold).first);
}

Scaffold _workspaceScaffold(WidgetTester tester) {
  return tester.widget<Scaffold>(find.byType(Scaffold).first);
}

Finder _contentText(String text) {
  return find.descendant(
    of: find.byKey(const Key('todo-content')),
    matching: find.text(text),
  );
}

Finder _detailText(String text) {
  return find.descendant(
    of: find.byKey(const Key('todo-detail')),
    matching: find.text(text),
  );
}

_WorkspaceProfile _currentProfile() {
  final hasRail = find.byKey(const Key('todo-rail')).evaluate().isNotEmpty;
  final hasSidebar = find
      .byKey(const Key('todo-sidebar'))
      .evaluate()
      .isNotEmpty;
  final hasDetail = find.byKey(const Key('todo-detail')).evaluate().isNotEmpty;
  final hasMobileNav = find
      .byKey(const Key('todo-mobile-nav'))
      .evaluate()
      .isNotEmpty;

  if (hasRail && hasSidebar && hasDetail && !hasMobileNav) {
    return _WorkspaceProfile.wide;
  }
  if (hasRail && hasSidebar && !hasDetail && !hasMobileNav) {
    return _WorkspaceProfile.compact;
  }
  if (hasRail && !hasSidebar && !hasDetail && !hasMobileNav) {
    return _WorkspaceProfile.tablet;
  }
  if (!hasRail && !hasSidebar && !hasDetail && hasMobileNav) {
    return _WorkspaceProfile.mobile;
  }
  throw TestFailure('workspace exposes an ambiguous responsive structure');
}

int _transitionCount(List<_WorkspaceProfile> profiles) {
  var transitions = 0;
  for (var index = 1; index < profiles.length; index++) {
    if (profiles[index] != profiles[index - 1]) transitions++;
  }
  return transitions;
}

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

enum _WorkspaceProfile { wide, compact, tablet, mobile }

class _BreakpointCase {
  const _BreakpointCase({required this.widths, required this.profiles});

  final List<int> widths;
  final List<_WorkspaceProfile> profiles;
}
