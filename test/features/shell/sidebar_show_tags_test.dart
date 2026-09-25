import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md》:10/:23
/// 「使用前，确认侧边栏中是否已经开启显示标签」⇒ 关掉后标签条目不再出现在侧栏。
void main() {
  Finder focusTag() =>
      find.byKey(const Key('todo-sidebar-tag-visual-tag-focus'));

  testWidgets('侧栏标签条目跟着「显示标签」走：默认在、关掉就没、再打开又回来', (tester) async {
    final fixture = await _pumpSidebar(tester);

    await tester.scrollUntilVisible(
      focusTag(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(focusTag(), findsOneWidget, reason: '默认「显示」时侧栏要能看到标签条目');

    await _save(tester, fixture, showTags: false);
    expect(focusTag(), findsNothing, reason: '关掉后不该再有标签条目');
    // spec.md 取舍 1：只收条目，不收「标签」那一行入口，否则没有回头路。
    expect(
      find.byKey(const Key('todo-sidebar-row-tags')),
      findsOneWidget,
      reason: '「标签」入口行不随偏好收起',
    );
    expect(find.text('专注'), findsNothing);
    expect(find.text('评审'), findsNothing);

    await _save(tester, fixture, showTags: true);
    await tester.scrollUntilVisible(
      focusTag(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(focusTag(), findsOneWidget, reason: '重新打开要立刻回来，不必重进侧栏');
  });

  testWidgets('偏好读不到时侧栏按默认「显示」处理，不清空标签区', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (database) => [
        sidebarShowTagsProvider.overrideWith(
          (ref) => throw StateError('故意让偏好读失败'),
        ),
      ],
      child: const Align(
        alignment: Alignment.topLeft,
        child: _TestSidebar(width: 300),
      ),
    );

    await tester.scrollUntilVisible(
      focusTag(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(focusTag(), findsOneWidget);
  });

  testWidgets('320px + 1.3 倍字号下「显示」与「隐藏」两种侧栏都不溢出', (tester) async {
    final fixture = await _pumpSidebar(tester, textScale: 1.3, width: 320);

    expect(tester.takeException(), isNull, reason: '默认态在 320px + 1.3 倍字号下溢出');

    await _save(tester, fixture, showTags: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '切到「隐藏」后侧栏重排溢出');
  });
}

Future<TodoVisualFixture> _pumpSidebar(
  WidgetTester tester, {
  double textScale = 1,
  double width = 300,
}) {
  return pumpTodoVisualScenario(
    tester,
    viewport: width >= 400 ? TodoVisualViewports.wide : const Size(320, 900),
    fixtureSet: TodoVisualFixtureSet.populated,
    child: Align(
      alignment: Alignment.topLeft,
      child: _TextScale(
        scale: textScale,
        child: _TestSidebar(width: width),
      ),
    ),
  );
}

Future<void> _save(
  WidgetTester tester,
  TodoVisualFixture fixture, {
  required bool showTags,
}) async {
  await SidebarVisibilityRepository(
    fixture.database,
    SyncChangeQueue(fixture.database),
  ).save(showTags: showTags);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
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
  const _TestSidebar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Sidebar(
        width: width,
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

void _noopVoid() {}
void _noopSection(Section _) {}
void _noopSmart(SmartList _) {}
void _noopList(String? _) {}
