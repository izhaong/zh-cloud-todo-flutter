import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/090 / FL Issue #329 面 ⑥ 的最后一半：桌面右键标签行。
///
/// 嘀嗒《04-用标签管理任务》`:94`「右键单击某个标签，会出现「置顶」「编辑」和
/// 「删除」等选项，点击「编辑」选项，即可进入「标签编辑」页面。」本端右键弹出
/// 位置菜单，三项都是真动作：置顶就地切换、编辑打开与 TagPage 同一份编辑对话框、
/// 删除走既有确认框。`:79` 的左滑动作表同样补齐「编辑」「删除」（specs/082 的
/// 「只放置顶」裁定基于「放进去只会跳转」——函数共享后两项就地可完成，裁定随之更新）。
class _TestSidebar extends StatelessWidget {
  const _TestSidebar();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Material(
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

Future<void> _pump(WidgetTester tester, {bool failPin = false}) async {
  await pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
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

Future<void> _rightClickRow(WidgetTester tester, String tagId) async {
  await tester.scrollUntilVisible(
    _row(tagId),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  final mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await mouse.addPointer();
  await mouse.moveTo(tester.getCenter(_row(tagId)));
  await tester.pump();
  await mouse.down(tester.getCenter(_row(tagId)));
  await mouse.up();
  await tester.pump();
  // 同一用例里可能右键多次：先摘掉这只指针，下一次 addPointer 才合法。
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

Future<void> _swipeOpenActions(WidgetTester tester, String tagId) async {
  await tester.scrollUntilVisible(
    _row(tagId),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.fling(_row(tagId), const Offset(-220, 0), 900);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('右键标签行弹出「置顶」「编辑」「删除」三项菜单', (tester) async {
    await _pump(tester);
    await _rightClickRow(tester, TodoVisualFixture.reviewTagId);

    expect(
      find.byKey(const Key('sidebar-tag-menu-pin')),
      findsOneWidget,
      reason: '嘀嗒 :94 右键菜单第一项「置顶」',
    );
    expect(
      find.byKey(const Key('sidebar-tag-menu-edit')),
      findsOneWidget,
      reason: '嘀嗒 :94 右键菜单第二项「编辑」',
    );
    expect(
      find.byKey(const Key('sidebar-tag-menu-delete')),
      findsOneWidget,
      reason: '嘀嗒 :94 右键菜单第三项「删除」',
    );
  });

  testWidgets('菜单「编辑」打开编辑标签对话框，改名保存后侧栏行更新', (tester) async {
    await _pump(tester);
    await _rightClickRow(tester, TodoVisualFixture.reviewTagId);
    await tester.tap(find.byKey(const Key('sidebar-tag-menu-edit')));
    await tester.pumpAndSettle();

    expect(find.text('编辑标签'), findsOneWidget);
    expect(
      find.byKey(const Key('tag-parent-picker')),
      findsOneWidget,
      reason: '右键编辑与 TagPage 是同一份编辑面（名称/颜色/父标签）',
    );
    await tester.enterText(find.byType(TextField).first, '评审改');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('评审改'), findsWidgets, reason: '改名要落到侧栏行');
    expect(find.text('评审'), findsNothing, reason: '旧名不应残留');
  });

  testWidgets('菜单「删除」走确认框：取消行还在，确认后行消失', (tester) async {
    await _pump(tester);
    await _rightClickRow(tester, TodoVisualFixture.reviewTagId);
    await tester.tap(find.byKey(const Key('sidebar-tag-menu-delete')));
    await tester.pumpAndSettle();

    expect(find.text('删除标签'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(_row(TodoVisualFixture.reviewTagId), findsOneWidget);

    await _rightClickRow(tester, TodoVisualFixture.reviewTagId);
    await tester.tap(find.byKey(const Key('sidebar-tag-menu-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(
      _row(TodoVisualFixture.reviewTagId),
      findsNothing,
      reason: '确认删除后标签行要从侧栏消失',
    );
  });

  testWidgets('菜单「置顶」失败时错误可见且标签行还在', (tester) async {
    await _pump(tester, failPin: true);
    await _rightClickRow(tester, TodoVisualFixture.reviewTagId);
    await tester.tap(find.byKey(const Key('sidebar-tag-menu-pin')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('置顶失败'),
      findsOneWidget,
      reason: '失败不能吞进谁也没看见的地方',
    );
    expect(_row(TodoVisualFixture.reviewTagId), findsOneWidget);
  });

  testWidgets('左滑动作表含「编辑」「删除」，与右键同一套动作', (tester) async {
    await _pump(tester);
    await _swipeOpenActions(tester, TodoVisualFixture.reviewTagId);

    expect(find.byKey(const Key('sidebar-tag-action-pin')), findsOneWidget);
    expect(
      find.byKey(const Key('sidebar-tag-action-edit')),
      findsOneWidget,
      reason: '嘀嗒 :79 左滑三选项里的「编辑」',
    );
    expect(
      find.byKey(const Key('sidebar-tag-action-delete')),
      findsOneWidget,
      reason: '嘀嗒 :79 左滑三选项里的「删除」',
    );
  });
}
