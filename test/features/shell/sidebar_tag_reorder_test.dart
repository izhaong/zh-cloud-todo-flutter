import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/088 / FL Issue #329「`:118` 长按标签即可进行拖拽，自由排序」。
///
/// 手势语义变更（相对 specs/082）：标签行的**长按从「动作表」改给了拖拽**；
/// 动作表仍在左滑与读屏自定义动作两条通道上（`sidebar_tag_pin_test.dart`）。
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

Finder _row(String tagId) => find.byKey(ValueKey('todo-sidebar-tag-$tagId'));

Future<TodoVisualFixture> _pump(WidgetTester tester) async {
  return pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
  );
}

Future<void> _revealRow(WidgetTester tester, String tagId) async {
  await tester.scrollUntilVisible(
    _row(tagId),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

/// 长按 source 行、拖到 target 行中心、松手。
Future<void> _dragTagOn(
  WidgetTester tester, {
  required String sourceTagId,
  required String targetTagId,
}) async {
  final source = _row(sourceTagId);
  final target = _row(targetTagId);
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  await _revealRow(tester, sourceTagId);
  await _revealRow(tester, targetTagId);

  final gesture = await tester.startGesture(tester.getCenter(source));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('长按「协作」拖到最上：本地顺序与 outbox 都跟着变', (tester) async {
    final fixture = await _pump(tester);
    final repo = fixture.container.read(tagRepositoryProvider)!;
    expect(
      (await repo.getAll()).map((t) => t.id).toList(),
      [
        TodoVisualFixture.focusTagId,
        TodoVisualFixture.reviewTagId,
        TodoVisualFixture.followUpTagId,
        TodoVisualFixture.collaborationTagId,
      ],
      reason: 'fixture 现序（createdAt ASC），拖拽后必须真的变',
    );
    final before =
        (await (fixture.database.select(
              fixture.database.todoSyncChanges,
            )..where((c) => c.entity.equals('tag'))).get())
            .map((c) => c.clientMutationId)
            .toSet();

    await _dragTagOn(
      tester,
      sourceTagId: TodoVisualFixture.collaborationTagId,
      targetTagId: TodoVisualFixture.focusTagId,
    );

    expect(
      (await repo.getAll()).map((t) => t.id).toList(),
      [
        TodoVisualFixture.collaborationTagId,
        TodoVisualFixture.focusTagId,
        TodoVisualFixture.reviewTagId,
        TodoVisualFixture.followUpTagId,
      ],
      reason: '嘀嗒 :118「自由排序」＝拖完顺序必须真的变',
    );
    final added =
        (await (fixture.database.select(
              fixture.database.todoSyncChanges,
            )..where((c) => c.entity.equals('tag'))).get())
            .where((c) => !before.contains(c.clientMutationId))
            .toList();
    expect(added, hasLength(4), reason: '四行位次全变 ⇒ 四条都要登记，另一台才收敛');
    expect(added.map((c) => c.op).toSet(), {'upsert'});
  });

  testWidgets('跨组拖拽被拒：把置顶标签拽到普通区，顺序与 outbox 都不动', (tester) async {
    final fixture = await _pump(tester);
    final repo = fixture.container.read(tagRepositoryProvider)!;
    await repo.setPinned(TodoVisualFixture.focusTagId, true);
    expect(
      (await repo.getAll()).map((t) => t.id).toList(),
      [
        TodoVisualFixture.focusTagId,
        TodoVisualFixture.reviewTagId,
        TodoVisualFixture.followUpTagId,
        TodoVisualFixture.collaborationTagId,
      ],
      reason: '置顶区在前（isPinned DESC 领头）',
    );
    final before =
        (await (fixture.database.select(
              fixture.database.todoSyncChanges,
            )..where((c) => c.entity.equals('tag'))).get())
            .map((c) => c.clientMutationId)
            .toSet();

    // 把普通区第一行「评审」拖过置顶行「专注」上方 —— 置顶区与普通区不换位。
    await _dragTagOn(
      tester,
      sourceTagId: TodoVisualFixture.reviewTagId,
      targetTagId: TodoVisualFixture.focusTagId,
    );

    expect(
      (await repo.getAll()).map((t) => t.id).toList(),
      [
        TodoVisualFixture.focusTagId,
        TodoVisualFixture.reviewTagId,
        TodoVisualFixture.followUpTagId,
        TodoVisualFixture.collaborationTagId,
      ],
      reason: 'isPinned DESC 领头，普通区标签不许越过置顶区',
    );
    final added =
        (await (fixture.database.select(
              fixture.database.todoSyncChanges,
            )..where((c) => c.entity.equals('tag'))).get())
            .where((c) => !before.contains(c.clientMutationId))
            .toList();
    expect(added, isEmpty, reason: '被拒的拖拽不能登记任何 outbox');
  });

  testWidgets('读屏：标签行自带「置顶」自定义动作（长按手势已改给拖拽）', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    await _revealRow(tester, TodoVisualFixture.reviewTagId);

    expect(
      tester.getSemantics(_row(TodoVisualFixture.reviewTagId)),
      matchesSemantics(
        label: '评审',
        hasTapAction: true,
        hasFocusAction: true,
        hasScrollLeftAction: true,
        hasScrollRightAction: true,
        isFocusable: true,
        customActions: <CustomSemanticsAction>[
          const CustomSemanticsAction(label: '置顶'),
        ],
      ),
      reason: '左滑对读屏不可达 ⇒ 动作表必须留一条 custom action 通道',
    );
    handle.dispose();
  });
}
