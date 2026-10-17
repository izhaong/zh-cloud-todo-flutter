import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/home/todo_workspace.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

void main() {
  testWidgets('Sidebar uses the Todo product header and keeps navigation', (
    tester,
  ) async {
    await _pumpSidebar(tester);

    expect(find.text('任务清单'), findsOneWidget);
    expect(find.text('智能清单'), findsOneWidget);
    expect(find.text('收集箱'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('明天'), findsOneWidget);
    expect(find.text('最近七天'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('垃圾桶'), findsOneWidget);
    expect(find.text('浏览'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('过滤器'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('新建清单'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('清单'), findsOneWidget);
    expect(find.text('新建清单'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('设置'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('番茄'), findsOneWidget);
    expect(find.text('习惯'), findsOneWidget);
    expect(find.text('倒数日'), findsOneWidget);
  });

  testWidgets('Sidebar navigation rows use the fixed 40px density', (
    tester,
  ) async {
    await _pumpSidebar(tester);

    final inboxRow = find.byKey(const Key('todo-sidebar-row-inbox'));
    expect(inboxRow, findsOneWidget);
    expect(tester.getSize(inboxRow).height, 40);
  });

  testWidgets('Sidebar new-list entry opens an actionable editor', (
    tester,
  ) async {
    final fixture = await _pumpSidebar(tester);
    const listName = '侧栏创建清单';
    final initialChanges = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();

    await tester.scrollUntilVisible(
      find.text('新建清单'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('新建清单'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '清单名'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '清单名'), listName);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存'), findsNothing);
    expect(find.text(listName), findsOneWidget);
    final lists = await fixture.database
        .select(fixture.database.todoLists)
        .get();
    final createdList = lists.singleWhere((list) => list.name == listName);
    final changes = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(changes, hasLength(initialChanges.length + 1));
    expect(
      changes.where(
        (change) =>
            change.entity == 'list' &&
            change.op == 'upsert' &&
            change.entityLocalId == createdList.id,
      ),
      hasLength(1),
    );
  });

  testWidgets(
    'Sidebar long-content list stays one 40px line with ellipsis at 1.3x text',
    (tester) async {
      const longListName = '跨团队协作与长期规划清单名称用于验证单行截断策略';
      final fixture = await _pumpSidebar(
        tester,
        fixtureSet: TodoVisualFixtureSet.longContent,
        textScale: 1.3,
      );
      await fixture.container
          .read(listRepositoryProvider)!
          .rename(TodoVisualFixture.readingListId, longListName);
      await tester.pumpAndSettle();

      final row = find.byKey(
        const ValueKey('todo-sidebar-list-${TodoVisualFixture.readingListId}'),
      );
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(row, findsOneWidget);
      expect(tester.takeException(), isNull, reason: '长清单名不应导致布局溢出');
      expect(tester.getSize(row).height, 40);
      final label = tester.widget<Text>(find.text(longListName));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
    },
  );

  group('keyboard focus outline contract (TodoRail → Sidebar)', () {
    testWidgets('TodoRail keyboard focus has a non-color outline', (
      tester,
    ) async {
      await _pumpRail(tester);

      final railItem = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '任务',
      );
      expect(railItem, findsOneWidget);
      await _focusByKeyboard(tester, railItem);

      expect(
        _visibleOutlineSides(tester, railItem),
        isNotEmpty,
        reason: 'TodoRail 键盘焦点需要独立 outline，不能只改背景色',
      );
    });

    testWidgets('Sidebar keyboard focus has a non-color outline', (
      tester,
    ) async {
      await _pumpSidebar(tester);

      final inboxRow = find.byKey(const Key('todo-sidebar-row-inbox'));
      expect(inboxRow, findsOneWidget);
      await _focusByKeyboard(tester, inboxRow);

      expect(
        _visibleOutlineSides(tester, inboxRow),
        isNotEmpty,
        reason: 'Sidebar 键盘焦点需要独立 outline，不能只改背景色',
      );
    });
  });

  testWidgets('TodoRail sync entry invokes the supplied sync action', (
    tester,
  ) async {
    var syncRequests = 0;
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: TodoRail(
            section: Section.tasks,
            onSelect: _noopSection,
            onSync: () => syncRequests++,
            onOpenReminders: _noop,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('同步'));

    expect(syncRequests, 1);
  });

  testWidgets('sync status is exposed as a live accessibility announcement', (
    tester,
  ) async {
    const status = '同步完成：推送 2 项，拉取 3 项';
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: TodoSyncStatusAnnouncement(status: status)),
      ),
    );

    expect(find.bySemanticsLabel(status), findsOneWidget);
  });
}

Future<TodoVisualFixture> _pumpSidebar(
  WidgetTester tester, {
  TodoVisualFixtureSet fixtureSet = TodoVisualFixtureSet.populated,
  double textScale = 1,
}) {
  return pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: fixtureSet,
    child: Align(
      alignment: Alignment.topLeft,
      child: _TextScale(scale: textScale, child: const _TestSidebar()),
    ),
  );
}

Future<void> _pumpRail(WidgetTester tester) async {
  await pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const Material(
      child: Align(
        alignment: Alignment.topLeft,
        child: TodoRail(
          section: Section.tasks,
          onSelect: _noopSection,
          onSync: _noop,
          onOpenReminders: _noop,
        ),
      ),
    ),
  );
}

void _noop() {}

Future<void> _focusByKeyboard(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 30; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) continue;
    final focusedElement = find.byElementPredicate(
      (element) => identical(element, focusContext),
    );
    if (find
        .ancestor(of: focusedElement, matching: target)
        .evaluate()
        .isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
  }
  fail('未能通过 Tab 键将焦点移到目标控件');
}

List<BorderSide> _visibleOutlineSides(WidgetTester tester, Finder root) {
  final sides = <BorderSide>[];
  final decoratedWidgets = find.descendant(
    of: root,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is AnimatedContainer ||
          widget is Container ||
          widget is DecoratedBox ||
          widget is Material,
    ),
  );

  for (final element in decoratedWidgets.evaluate()) {
    final widget = element.widget;
    BoxDecoration? decoration;
    if (widget is AnimatedContainer) {
      decoration = widget.decoration as BoxDecoration?;
    } else if (widget is Container) {
      decoration = widget.decoration as BoxDecoration?;
    } else if (widget is DecoratedBox) {
      decoration = widget.decoration as BoxDecoration?;
    }
    final border = decoration?.border;
    if (border is Border) {
      sides.addAll([border.top, border.right, border.bottom, border.left]);
    }

    if (widget is Material && widget.shape is RoundedRectangleBorder) {
      sides.add((widget.shape! as RoundedRectangleBorder).side);
    }
  }
  return sides
      .where((side) => side.style != BorderStyle.none && side.width > 0)
      .toList();
}

class _TextScale extends StatelessWidget {
  const _TextScale({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }
}

class _TestSidebar extends StatelessWidget {
  const _TestSidebar();

  @override
  Widget build(BuildContext context) {
    return const Material(
      child: Sidebar(
        selectedSection: Section.tasks,
        selectedSmart: SmartList.inbox,
        selectedListId: null,
        onSelectSection: _noopSection,
        onSelectSmart: _noopSmart,
        onSelectList: _noopList,
        onOpenTags: _noopVoid,
        onOpenFilters: _noopVoid,
        onOpenSettings: _noopVoid,
        onOpenPomodoro: _noopVoid,
        onOpenHabit: _noopVoid,
        onOpenCountdown: _noopVoid,
      ),
    );
  }
}

void _noopSection(Section _) {}
void _noopSmart(SmartList _) {}
void _noopList(String? _) {}
void _noopVoid() {}
