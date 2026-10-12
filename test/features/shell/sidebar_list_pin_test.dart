import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/081 / FL Issue #341：侧栏清单「置顶」入口。
///
/// 嘀嗒《02-用清单管理任务》「在侧边栏左滑某个清单，会出现「置顶」、「编辑」和「删除」3个选项。
/// 点击中间「编辑」图标，即可进入清单编辑页面。」
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

/// 置顶写失败要当场可见，且不能把已加载的清单冲掉。
class _ThrowingListRepository extends ListRepository {
  _ThrowingListRepository(super.db, super.queue);

  @override
  Future<TodoList> setPinned(String listId, bool pinned) {
    throw StateError('模拟置顶写失败');
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
            listRepositoryProvider.overrideWithValue(
              _ThrowingListRepository(db, SyncChangeQueue(db)),
            ),
          ]
        : null,
    child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
  );
}

Finder _row(String listId) => find.byKey(ValueKey('todo-sidebar-list-$listId'));

Future<void> _revealRow(WidgetTester tester, String listId) async {
  final row = _row(listId);
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _swipeOpenActions(WidgetTester tester, String listId) async {
  await _revealRow(tester, listId);
  await tester.fling(_row(listId), const Offset(-220, 0), 900);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('左滑清单行唤出动作表，里有「置顶」', (tester) async {
    await _pump(tester);
    await _swipeOpenActions(tester, TodoVisualFixture.personalListId);

    expect(
      find.byKey(const Key('sidebar-list-action-pin')),
      findsOneWidget,
      reason: '嘀嗒把「置顶」放在清单左滑的动作里，入口必须真的可点',
    );
    expect(find.text('置顶'), findsWidgets);
  });

  testWidgets('长按仍给出同一动作表（既有入口不倒退）', (tester) async {
    await _pump(tester);
    await _revealRow(tester, TodoVisualFixture.personalListId);
    await tester.longPress(_row(TodoVisualFixture.personalListId));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-list-action-pin')), findsOneWidget);
  });

  testWidgets('点「置顶」：落库并把该清单排到最前', (tester) async {
    final fixture = await _pump(tester);
    final repo = fixture.container.read(listRepositoryProvider)!;
    await _swipeOpenActions(tester, TodoVisualFixture.readingListId);
    await tester.tap(find.byKey(const Key('sidebar-list-action-pin')));
    await tester.pumpAndSettle();

    final stored = await repo.getAll();
    final target = stored.firstWhere(
      (l) => l.id == TodoVisualFixture.readingListId,
    );
    expect(target.isPinned, true, reason: '置顶要写进本地列');
    expect(
      stored.first.id,
      TodoVisualFixture.readingListId,
      reason: '置顶行必须排最前，否则用户看不出任何效果',
    );
  });

  testWidgets('置顶失败：当场可见提示，已加载清单不丢', (tester) async {
    final fixture = await _pump(tester, failPin: true);
    final before = await fixture.container
        .read(listRepositoryProvider)!
        .getAll();
    await _swipeOpenActions(tester, TodoVisualFixture.personalListId);
    await tester.tap(find.byKey(const Key('sidebar-list-action-pin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('sidebar-list-pin-error')),
      findsOneWidget,
      reason: '失败必须当场可见，不能只留在控制台',
    );
    expect(find.textContaining('置顶失败'), findsOneWidget);
    final after = await fixture.container
        .read(listRepositoryProvider)!
        .getAll();
    expect(after.map((l) => l.id).toSet(), before.map((l) => l.id).toSet());
  });

  testWidgets('320px 宽 + 1.3 倍字号：左滑动作表可点且不溢出', (tester) async {
    await _pump(tester, viewport: const Size(320, 700), textScale: 1.3);
    await _swipeOpenActions(tester, TodoVisualFixture.personalListId);

    final tile = find.byKey(const Key('sidebar-list-action-pin'));
    expect(tile, findsOneWidget);
    final box = tester.renderObject<RenderBox>(tile);
    expect(box.size.width, lessThanOrEqualTo(320), reason: '窄屏不得溢出可视宽');
    expect(tester.takeException(), isNull, reason: '1.3 倍字号下不该抛溢出');
  });

  testWidgets('动作表里的「置顶」有可被读屏念出的名字', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    await _swipeOpenActions(tester, TodoVisualFixture.personalListId);

    final semantics = tester.getSemantics(
      find.byKey(const Key('sidebar-list-action-pin')),
    );
    expect(semantics.label, contains('置顶'));
    handle.dispose();
  });
}
