import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/126 / FL Issue #355 / 矩阵 #18 面④：嘀嗒《01-任务/09-如何管理海量任务/01-用文件夹管理任务.md》
/// 方式一（原文挂在 `::::tab [mobile]` 下）：「拖动清单到另一清单上方，松手后，在弹窗内输入名称即可创建文件夹。」
///
/// 手柄是新增视觉，只允许出现在「悬停」或「窄视口」两种条件下：9 张黄金基线既不悬停，
/// 其移动端视口里侧栏又是收起来的，默认渲染因此必须与今天逐像素相同。
class _TestSidebar extends StatelessWidget {
  const _TestSidebar();

  @override
  Widget build(BuildContext context) {
    // 真机侧栏挂在 HomeShell 的 Scaffold 里；不给 Scaffold 的话提示语无处可放，
    // 「失败必须看得见」这条就只能在控制台里响。
    return Scaffold(
      body: Sidebar(
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

/// 手机宽度：没有悬停可用，手柄常驻，拖拽用例都走这条路。
const _phone = Size(390, 844);

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  Size viewport = _phone,
  List<Override> Function(AppDatabase database)? overridesBuilder,
}) async {
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport,
    fixtureSet: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
    child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
  );
}

Finder _row(String listId) => find.byKey(ValueKey('todo-sidebar-list-$listId'));

Finder _grip(String listId) =>
    find.byKey(ValueKey('todo-sidebar-list-drag-$listId'));

Future<void> _reveal(WidgetTester tester, String listId) =>
    tester.scrollUntilVisible(
      _row(listId),
      200,
      scrollable: find.byType(Scrollable).first,
    );

Future<void> _hoverRow(WidgetTester tester, String listId) async {
  await _reveal(tester, listId);
  final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await pointer.addPointer(location: Offset.zero);
  await pointer.moveTo(tester.getCenter(_row(listId)));
  await tester.pumpAndSettle();
}

Future<void> _dragGripTo(
  WidgetTester tester,
  String sourceListId,
  String targetListId,
) async {
  await _reveal(tester, sourceListId);
  await _reveal(tester, targetListId);
  final gesture = await tester.startGesture(
    tester.getCenter(_grip(sourceListId)),
  );
  await tester.pump();
  await gesture.moveBy(const Offset(0, 24));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(_row(targetListId)));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 弹窗关闭后的建夹与搬清单是异步的：按本仓既有做法只推进帧，
/// 不 `pumpAndSettle`（那会把 SnackBar 的退场计时也一并跑完）。
Future<void> _settleWrite(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<TodoList> _readList(TodoVisualFixture fixture, String id) async =>
    (await fixture.database.select(fixture.database.todoLists).get())
        .firstWhere((row) => row.id == id);

Future<List<TodoFolder>> _readFolders(TodoVisualFixture fixture) =>
    fixture.database.select(fixture.database.todoFolders).get();

/// 建夹成功但搬清单失败时，必须看得见失败，且不许留下「夹建了、清单没搬」的半态。
class _ThrowingListRepository extends ListRepository {
  _ThrowingListRepository(super.db, super.queue);

  @override
  Future<TodoList> moveToFolder(String listId, String? folderLocalId) {
    throw StateError('模拟搬清单失败');
  }
}

void main() {
  testWidgets('宽屏非悬停不出现拖拽手柄（黄金基线零像素改动的前提）', (tester) async {
    await _pump(tester, viewport: TodoVisualViewports.wide);
    await _reveal(tester, TodoVisualFixture.personalListId);

    expect(
      _grip(TodoVisualFixture.personalListId),
      findsNothing,
      reason: '宽屏既不悬停时必须与今天一致，否则 9 张 golden 全要重录',
    );
  });

  testWidgets('指针设备悬停清单行才出现手柄', (tester) async {
    await _pump(tester, viewport: TodoVisualViewports.wide);
    await _hoverRow(tester, TodoVisualFixture.personalListId);

    expect(
      _grip(TodoVisualFixture.personalListId),
      findsOneWidget,
      reason: '桌面端要能起拖，手柄得在悬停时出现',
    );
  });

  testWidgets('窄视口（手机宽度）清单行常驻手柄', (tester) async {
    await _pump(tester);
    await _reveal(tester, TodoVisualFixture.personalListId);

    expect(
      _grip(TodoVisualFixture.personalListId),
      findsOneWidget,
      reason: '嘀嗒方式一写在移动端 tab 下，手机上不能只有悬停这一条路',
    );
  });

  testWidgets('手柄自带读屏标签', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    await _reveal(tester, TodoVisualFixture.personalListId);

    final data = tester.getSemantics(_grip(TodoVisualFixture.personalListId));
    expect(data.label, contains('建文件夹'), reason: '拖拽本身读屏量不到，标签要说清拖它能干什么');
    handle.dispose();
  });

  testWidgets('拖 A 到 B ⇒ 弹窗命名后建夹，两条清单都进该夹', (tester) async {
    final fixture = await _pump(tester);
    await _dragGripTo(
      tester,
      TodoVisualFixture.personalListId,
      TodoVisualFixture.readingListId,
    );

    expect(
      find.byKey(const Key('sidebar-folder-merge-name')),
      findsOneWidget,
      reason: '原文是「松手后，在弹窗内输入名称」——必须弹窗而不是直接建一个匿名夹',
    );
    await tester.enterText(
      find.byKey(const Key('sidebar-folder-merge-name')),
      '阅读与思考',
    );
    await tester.tap(find.byKey(const Key('sidebar-folder-merge-confirm')));
    await _settleWrite(tester);

    final folders = await _readFolders(fixture);
    final created = folders.where((row) => row.name == '阅读与思考').toList();
    expect(created, hasLength(1), reason: '弹窗确认要真的落一条文件夹');

    final personal = await _readList(fixture, TodoVisualFixture.personalListId);
    final reading = await _readList(fixture, TodoVisualFixture.readingListId);
    expect(personal.folderLocalId, created.single.id, reason: '拖出的那条要进新夹');
    expect(
      reading.folderLocalId,
      created.single.id,
      reason: '被落上的那条也要进同一个夹，否则「用文件夹整理清单」不成立',
    );
  });

  testWidgets('取消弹窗 ⇒ 一条文件夹也不落、清单归属不动', (tester) async {
    final fixture = await _pump(tester);
    final seedFolders = await _readFolders(fixture);
    final before = await _readList(fixture, TodoVisualFixture.personalListId);
    await _dragGripTo(
      tester,
      TodoVisualFixture.personalListId,
      TodoVisualFixture.readingListId,
    );

    await tester.tap(find.byKey(const Key('sidebar-folder-merge-cancel')));
    await tester.pumpAndSettle();

    final folders = await _readFolders(fixture);
    expect(folders.length, seedFolders.length, reason: '取消不该留下半成品文件夹');
    final after = await _readList(fixture, TodoVisualFixture.personalListId);
    expect(after.folderLocalId, before.folderLocalId);
  });

  testWidgets('拖到自己那一行 ⇒ 不弹窗', (tester) async {
    await _pump(tester);
    await _dragGripTo(
      tester,
      TodoVisualFixture.personalListId,
      TodoVisualFixture.personalListId,
    );

    expect(
      find.byKey(const Key('sidebar-folder-merge-name')),
      findsNothing,
      reason: '自己拖到自己不构成「两条清单」，不该建夹',
    );
  });

  testWidgets('目标清单已在文件夹里 ⇒ 两条一起搬进新夹（口径钉）', (tester) async {
    final fixture = await _pump(tester);
    // 文件夹行是 ExpansionTile，默认收起 ⇒ 先点开，才谈得上把清单拖到它下面的清单上。
    final folderTile = find.byKey(
      const ValueKey('todo-sidebar-folder-visual-folder-projects'),
    );
    await tester.scrollUntilVisible(
      folderTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(folderTile);
    await tester.pumpAndSettle();
    final work = await _readList(fixture, TodoVisualFixture.workListId);
    expect(
      work.folderLocalId,
      'visual-folder-projects',
      reason: '种子必须真的让目标在夹内，否则这条断言恒真',
    );

    await _dragGripTo(
      tester,
      TodoVisualFixture.personalListId,
      TodoVisualFixture.workListId,
    );
    await tester.enterText(
      find.byKey(const Key('sidebar-folder-merge-name')),
      '合并到这儿',
    );
    await tester.tap(find.byKey(const Key('sidebar-folder-merge-confirm')));
    await _settleWrite(tester);

    final movedWork = await _readList(fixture, TodoVisualFixture.workListId);
    expect(
      movedWork.folderLocalId,
      isNot('visual-folder-projects'),
      reason: '口径：原文要的是「创建文件夹」并把这两条放进去，目标原夹随之让位',
    );
    final personal = await _readList(fixture, TodoVisualFixture.personalListId);
    expect(
      personal.folderLocalId,
      movedWork.folderLocalId,
      reason: '两条要落在同一个新夹里',
    );
  });

  testWidgets('搬清单失败 ⇒ 当场可见提示，且不留「夹建了、清单没搬」的半态', (tester) async {
    final fixture = await _pump(
      tester,
      overridesBuilder: (database) => [
        listRepositoryProvider.overrideWithValue(
          _ThrowingListRepository(database, SyncChangeQueue(database)),
        ),
      ],
    );
    final seedFolders = await _readFolders(fixture);
    await _dragGripTo(
      tester,
      TodoVisualFixture.personalListId,
      TodoVisualFixture.readingListId,
    );
    await tester.enterText(
      find.byKey(const Key('sidebar-folder-merge-name')),
      '失败路径',
    );
    await tester.tap(find.byKey(const Key('sidebar-folder-merge-confirm')));
    await _settleWrite(tester);

    expect(
      find.textContaining('建文件夹失败'),
      findsWidgets,
      reason: '静默早退等于用户松了手却什么都没发生',
    );
    final folders = await _readFolders(fixture);
    expect(
      folders.length,
      seedFolders.length,
      reason: '建夹与搬清单要么都成要么都不成，不能留一条空夹',
    );
    final personal = await _readList(fixture, TodoVisualFixture.personalListId);
    expect(personal.folderLocalId, isNull, reason: '失败后清单归属必须维持原样');
  });
}
