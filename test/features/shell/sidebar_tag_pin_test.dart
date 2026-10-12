import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/082 / FL Issue #329 面 ⑥ 的「置顶」半面：侧栏标签左滑唤出「置顶」。
///
/// 嘀嗒《04-用标签管理任务》`:79`「在侧边栏左滑某个标签，会出现「置顶」、「编辑」和「删除」3个选项。」
/// 本端动作表只放「置顶」这一项：「编辑」「删除」在点标签行即到的一层
/// （`home_shell.dart` 的 `onSelectTag: (tagId) => _openTags(initialTagId: tagId)`），
/// 放两个只会跳转的磁贴就是「菜单里有、点了不做事」的假档。
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

/// 置顶写失败要当场可见，且不能把已加载的标签冲掉。
class _ThrowingTagRepository extends TagRepository {
  _ThrowingTagRepository(super.db, super.queue);

  @override
  Future<TodoTag> setPinned(String tagId, bool pinned) {
    throw StateError('模拟标签置顶写失败');
  }
}

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  Size? viewport,
  double textScale = 1,
  bool failPin = false,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport ?? TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    overridesBuilder: failPin
        ? (AppDatabase db) => [
            tagRepositoryProvider.overrideWithValue(
              _ThrowingTagRepository(db, SyncChangeQueue(db)),
            ),
          ]
        : null,
    child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
  );
}

Finder _row(String tagId) => find.byKey(ValueKey('todo-sidebar-tag-$tagId'));

Future<void> _revealRow(WidgetTester tester, String tagId) async {
  final row = _row(tagId);
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _swipeOpenActions(WidgetTester tester, String tagId) async {
  await _revealRow(tester, tagId);
  await tester.fling(_row(tagId), const Offset(-220, 0), 900);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('左滑标签行唤出动作表，里有「置顶」', (tester) async {
    await _pump(tester);
    await _swipeOpenActions(tester, TodoVisualFixture.reviewTagId);

    expect(
      find.byKey(const Key('sidebar-tag-action-pin')),
      findsOneWidget,
      reason: '嘀嗒把「置顶」放在标签左滑的动作里，入口必须真的可点',
    );
    expect(find.text('置顶'), findsWidgets);
  });

  /// 长按手势已被标签分节的 ReorderableListView 拖拽占用（specs/088），
  /// 动作表给读屏留 `CustomSemanticsAction` 通道；动作表本体的行为由左滑用例覆盖。
  testWidgets('读屏自定义动作「置顶」挂在标签行上（长按已改给拖拽）', (tester) async {
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
      reason: '失去长按入口后，读屏通道必须仍能到达动作表',
    );
    handle.dispose();
  });

  testWidgets('点「置顶」：落库并把该标签排到最前', (tester) async {
    final fixture = await _pump(tester);
    final repo = fixture.container.read(tagRepositoryProvider)!;
    await _swipeOpenActions(tester, TodoVisualFixture.collaborationTagId);
    await tester.tap(find.byKey(const Key('sidebar-tag-action-pin')));
    await tester.pumpAndSettle();

    final stored = await repo.getAll();
    final target = stored.firstWhere(
      (t) => t.id == TodoVisualFixture.collaborationTagId,
    );
    expect(target.isPinned, true, reason: '置顶要写进本地列');
    expect(
      stored.first.id,
      TodoVisualFixture.collaborationTagId,
      reason: '置顶行必须排最前，否则用户看不出任何效果',
    );
  });

  testWidgets('再点一次「取消置顶」写回 false（置顶是可逆的）', (tester) async {
    final fixture = await _pump(tester);
    final repo = fixture.container.read(tagRepositoryProvider)!;
    await _swipeOpenActions(tester, TodoVisualFixture.reviewTagId);
    await tester.tap(find.byKey(const Key('sidebar-tag-action-pin')));
    await tester.pumpAndSettle();
    expect(
      (await repo.getAll())
          .firstWhere((t) => t.id == TodoVisualFixture.reviewTagId)
          .isPinned,
      true,
    );

    await _swipeOpenActions(tester, TodoVisualFixture.reviewTagId);
    expect(find.text('取消置顶'), findsOneWidget, reason: '已置顶时磁贴文案要反过来');
    await tester.tap(find.byKey(const Key('sidebar-tag-action-pin')));
    await tester.pumpAndSettle();

    final after = await repo.getAll();
    expect(
      after.firstWhere((t) => t.id == TodoVisualFixture.reviewTagId).isPinned,
      false,
      reason: '取消置顶要写回本地列',
    );
    expect(
      after.first.id == TodoVisualFixture.reviewTagId,
      false,
      reason: '取消后不该还占着第一格',
    );
  });

  testWidgets('置顶失败：当场可见提示，已加载标签不丢', (tester) async {
    final fixture = await _pump(tester, failPin: true);
    final before = await fixture.container
        .read(tagRepositoryProvider)!
        .getAll();
    await _swipeOpenActions(tester, TodoVisualFixture.reviewTagId);
    await tester.tap(find.byKey(const Key('sidebar-tag-action-pin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('sidebar-tag-pin-error')),
      findsOneWidget,
      reason: '失败必须当场可见，不能只留在控制台',
    );
    expect(find.textContaining('置顶失败'), findsOneWidget);
    final after = await fixture.container.read(tagRepositoryProvider)!.getAll();
    expect(after.map((t) => t.id).toSet(), before.map((t) => t.id).toSet());
    expect(
      after.firstWhere((t) => t.id == TodoVisualFixture.reviewTagId).isPinned,
      false,
      reason: '失败不能把本地置顶位改脏',
    );
  });

  testWidgets('320px 宽 + 1.3 倍字号：左滑动作表可点且不溢出', (tester) async {
    await _pump(tester, viewport: const Size(320, 700), textScale: 1.3);
    await _swipeOpenActions(tester, TodoVisualFixture.reviewTagId);

    final tile = find.byKey(const Key('sidebar-tag-action-pin'));
    expect(tile, findsOneWidget);
    final box = tester.renderObject<RenderBox>(tile);
    expect(box.size.width, lessThanOrEqualTo(320), reason: '窄屏不得溢出可视宽');
    expect(tester.takeException(), isNull, reason: '1.3 倍字号下不该抛溢出');
  });

  testWidgets('动作表里的「置顶」有可被读屏念出的名字', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    await _swipeOpenActions(tester, TodoVisualFixture.reviewTagId);

    final semantics = tester.getSemantics(
      find.byKey(const Key('sidebar-tag-action-pin')),
    );
    expect(semantics.label, contains('置顶'));
    handle.dispose();
  });

  testWidgets('左滑露出的次层背景自己带名字（不靠文案常驻也读得出）', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    await _revealRow(tester, TodoVisualFixture.reviewTagId);
    await tester.drag(
      _row(TodoVisualFixture.reviewTagId),
      const Offset(-120, 0),
    );
    await tester.pump();

    final swipe = tester.getSemantics(
      find.byKey(const ValueKey('todo-sidebar-tag-swipe-actions')),
    );
    expect(swipe.label, contains('置顶'));
    handle.dispose();
  });
}
