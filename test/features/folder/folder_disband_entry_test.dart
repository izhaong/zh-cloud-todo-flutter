import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/folder/folder_page.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/folder_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/01-用文件夹管理任务.md》
/// `:28`「# 解散文件夹」/:30`「在移动端可通过左滑、长按的方式，解散文件夹。」
/// 术语是「解散」，不是"删除"。
const projectsFolderId = 'visual-folder-projects';
const childFolderId = 'r69-child-folder';

void main() {
  Future<TodoVisualFixture> pumpSidebar(
    WidgetTester tester, {
    Size viewport = TodoVisualViewports.wide,
    double textScale = 1,
    List<Override> Function(AppDatabase database)? overridesBuilder,
  }) {
    if (textScale != 1) {
      // 对话框是 root Navigator 上的路由：包在 home 子树里的 MediaQuery 到不了它。
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    return pumpTodoVisualScenario(
      tester,
      viewport: viewport,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: overridesBuilder,
      child: const Align(
        alignment: Alignment.topLeft,
        child: Material(child: _TestSidebar()),
      ),
    );
  }

  Future<void> expandAndLongPressFolder(WidgetTester tester) async {
    final row = find.byKey(
      const ValueKey('todo-sidebar-folder-$projectsFolderId'),
    );
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(row); // 展开：文件夹默认收起，其下清单要可见才算真的能用
    await tester.pumpAndSettle();
    // 展开后 row 的矩形含其下清单行 ⇒ 按 center 会长按到清单行上。
    // 长按点取头部那一行的左侧，才是"长按文件夹行"。
    final rect = tester.getRect(row);
    await tester.longPressAt(rect.topLeft + const Offset(40, 14));
    await tester.pumpAndSettle();
  }

  Future<void> seedChildFolder(TodoVisualFixture fixture) async {
    final now = DateTime(2026, 7, 11, 8);
    // 直接写库、不走仓库 ⇒ 不会往 outbox 里掺入"用例前提"的记录，
    // 后面那句"解散产生了 N 条同步记录"才是真断言。
    await fixture.database
        .into(fixture.database.todoFolders)
        .insert(
          TodoFoldersCompanion.insert(
            id: childFolderId,
            parentId: const Value(projectsFolderId),
            name: '子夹',
            updatedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<TodoFolder?> folderById(AppDatabase db, String id) {
    return (db.select(
      db.todoFolders,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<TodoList?> listById(AppDatabase db, String id) {
    return (db.select(
      db.todoLists,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<int> syncRows(TodoVisualFixture fixture) async {
    return (await fixture.database
            .select(fixture.database.todoSyncChanges)
            .get())
        .length;
  }

  testWidgets('侧栏长按文件夹行 ⇒ 「解散文件夹」确认框，用词照抄嘀嗒', (tester) async {
    await pumpSidebar(tester);
    await expandAndLongPressFolder(tester);

    expect(
      find.text('解散文件夹'),
      findsOneWidget,
      reason: 'FR-1：`:30` 的移动端手势要真的能点到解散',
    );
    expect(find.text('项目'), findsWidgets, reason: '确认框要说清解散的是哪一个');
    expect(find.text('删除'), findsNothing, reason: '嘀嗒 `:28` 的词是「解散」，不是"删除"');
    expect(find.text('解散'), findsOneWidget);
  });

  testWidgets('确认解散 ⇒ 文件夹没了、其下清单回顶层、子文件夹提升为顶层，且留下同步记录', (tester) async {
    final fixture = await pumpSidebar(tester);
    await seedChildFolder(fixture);
    await tester.pumpAndSettle();

    final before = await syncRows(fixture);
    await expandAndLongPressFolder(tester);
    await tester.tap(find.text('解散'));
    await tester.pumpAndSettle();

    expect(await folderById(fixture.database, projectsFolderId), isNull);
    final child = await folderById(fixture.database, childFolderId);
    expect(child, isNotNull, reason: '解散不是连子文件夹一起销毁');
    expect(child!.parentId, isNull, reason: '直接子文件夹提升为顶层');
    final work = await listById(fixture.database, TodoVisualFixture.workListId);
    expect(work!.folderLocalId, isNull);
    expect(work.folderId, isNull, reason: '服务端整数归属也要清空');
    expect(
      await syncRows(fixture),
      greaterThan(before),
      reason: '解散与提升都要出 outbox，否则另一台设备组织关系不一致',
    );
    expect(
      find.byKey(const ValueKey('todo-sidebar-folder-$projectsFolderId')),
      findsNothing,
      reason: '界面上那一行也要跟着消失',
    );
  });

  testWidgets('取消 ⇒ 一个字都不写', (tester) async {
    final fixture = await pumpSidebar(tester);
    await seedChildFolder(fixture);
    await tester.pumpAndSettle();
    final before = await syncRows(fixture);

    await expandAndLongPressFolder(tester);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('解散文件夹'), findsNothing);
    expect(await folderById(fixture.database, projectsFolderId), isNotNull);
    final work = await listById(fixture.database, TodoVisualFixture.workListId);
    expect(work!.folderLocalId, projectsFolderId);
    expect(await syncRows(fixture), before, reason: '取消不产生任何写入');
  });

  testWidgets('连点两次「解散」只解散一次', (tester) async {
    late _SpyFolderRepository spy;
    await pumpSidebar(
      tester,
      overridesBuilder: (database) {
        spy = _SpyFolderRepository(database, SyncChangeQueue(database));
        return [folderRepositoryProvider.overrideWith((ref) => spy)];
      },
    );
    await expandAndLongPressFolder(tester);

    final button = find.text('解散');
    // 同一帧内两次点击：中间不 pump，禁用态只在下一次 build 才生效 ⇒
    // 少一个同步闸门就会真的调两次 delete。
    await tester.tap(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(spy.deleteCalls, 1, reason: '重复解散会二次清空归属并多打 outbox');
  });

  testWidgets('解散失败：框不关、文件夹还在、错误写在框里，重试能成', (tester) async {
    late _FlakyFolderRepository flaky;
    final fixture = await pumpSidebar(
      tester,
      overridesBuilder: (database) {
        flaky = _FlakyFolderRepository(database, SyncChangeQueue(database));
        return [folderRepositoryProvider.overrideWith((ref) => flaky)];
      },
    );

    await expandAndLongPressFolder(tester);
    await tester.tap(find.text('解散'));
    await tester.pumpAndSettle();

    expect(find.text('解散失败，请重试'), findsOneWidget, reason: '静默失败等于告诉用户"解散好了"');
    expect(
      await folderById(fixture.database, projectsFolderId),
      isNotNull,
      reason: '失败不能留下半个删除',
    );
    expect(find.text('取消'), findsOneWidget, reason: '框还开着才谈得上重试');

    await tester.tap(find.text('解散'));
    await tester.pumpAndSettle();
    expect(find.text('解散失败，请重试'), findsNothing);
    expect(
      await folderById(fixture.database, projectsFolderId),
      isNull,
      reason: '重试这一次要真的走通',
    );
  });

  testWidgets('读屏念得出「解散文件夹」，且念的是被解散的那一个', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSidebar(tester);
    await expandAndLongPressFolder(tester);

    // 实测：AlertDialog 的 title 与 content 是**两个**语义节点（不合并），
    // 所以"标题+内容"要分别断言，不能写 `bySemanticsLabel('解散文件夹.*项目')`
    // 那种跨节点的正则（那样恒 0 命中，第 68 轮同一个坑）。
    expect(
      find.bySemanticsLabel(RegExp(r'^解散文件夹$')),
      findsOneWidget,
      reason: '动作名要被念出来，而不是只画一个加粗标题',
    );
    expect(
      find.bySemanticsLabel(RegExp('确认解散"项目"')),
      findsOneWidget,
      reason: '还要念出解散的是哪一个',
    );
    expect(
      find.bySemanticsLabel(RegExp('确认解散"生活"')),
      findsNothing,
      reason: '正向对照：别把侧栏里另一个清单/文件夹的名字混进来',
    );

    handle.dispose();
  });

  testWidgets('320px + 1.3 倍字号：确认框排得下且按钮可命中', (tester) async {
    await pumpSidebar(tester, viewport: const Size(320, 700), textScale: 1.3);
    await expandAndLongPressFolder(tester);

    expect(tester.takeException(), isNull, reason: '确认框在 320px + 1.3 下溢出');
    expect(find.text('解散').hitTestable(), findsOneWidget);
    expect(find.text('取消').hitTestable(), findsOneWidget);
  });

  testWidgets('文件夹展开后，其下清单行长按还是清单动作（手势不串味）', (tester) async {
    await pumpSidebar(tester);
    await expandAndLongPressFolder(tester);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final listRow = find.byKey(
      const ValueKey('todo-sidebar-list-${TodoVisualFixture.workListId}'),
    );
    expect(listRow, findsOneWidget, reason: '文件夹已展开，清单行在树上');
    await tester.longPress(listRow);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-list-action-edit')), findsOneWidget);
    expect(find.text('解散文件夹'), findsNothing);
  });

  testWidgets('可达性：真 HomeShell 里长按文件夹行就出确认框（不靠 FolderPage）', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const HomeShell(),
    );
    await expandAndLongPressFolder(tester);

    expect(find.text('解散文件夹'), findsOneWidget);
  });

  testWidgets('FolderPage 的那个按钮走同一个确认框、同一个词（不留两份口径）', (tester) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: const Material(child: FolderPage()),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('folder-row-$projectsFolderId')),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('解散文件夹'),
      findsOneWidget,
      reason: 'FR-3：`:28` 的用词，且与侧栏共用同一个确认口径',
    );
    expect(find.text('删除'), findsNothing);
  });
}

/// 只记调用次数，不碰数据库：钉"同帧连点只发一次"。
class _SpyFolderRepository extends FolderRepository {
  _SpyFolderRepository(super.db, super.queue);

  int deleteCalls = 0;

  @override
  Future<void> delete(String folderId) async {
    deleteCalls++;
  }
}

/// 第一次失败、第二次成功：钉"失败可重试"这条路径。
class _FlakyFolderRepository extends FolderRepository {
  _FlakyFolderRepository(super.db, super.queue);

  int _attempts = 0;

  @override
  Future<void> delete(String folderId) async {
    _attempts++;
    if (_attempts == 1) throw StateError('文件夹服务不可用');
    await super.delete(folderId);
  }
}

class _TestSidebar extends StatelessWidget {
  const _TestSidebar();

  @override
  Widget build(BuildContext context) {
    return const Sidebar(
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
    );
  }
}

void _noopSection(Section _) {}
void _noopSmart(SmartList _) {}
void _noopList(String? _) {}
void _noopVoid() {}
