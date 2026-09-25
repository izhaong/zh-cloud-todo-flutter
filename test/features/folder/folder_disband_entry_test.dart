import 'dart:async';

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

  testWidgets('解散请求挂起时再点一次「解散」：只发一次', (tester) async {
    // 探针 PC 逼出来的写法：原先是"同帧连点两下 + 假仓库立刻返回"，
    // 但第一次点击后弹层已经开始关闭、第二下打在退出动画里的按钮上没触发 handler
    // ⇒ 把 `_busy` 闸门整块摘掉，10 条仍全绿（= 这条用例当时什么都没钉）。
    // 正解：让 delete 挂起（Completer 门控），第一次点击停在 await 里，
    // 框还开着、按钮还可命中，第二下才真的走到 handler。
    late _GatedFolderRepository gated;
    await pumpSidebar(
      tester,
      overridesBuilder: (database) {
        gated = _GatedFolderRepository(database, SyncChangeQueue(database));
        return [folderRepositoryProvider.overrideWith((ref) => gated)];
      },
    );
    await expandAndLongPressFolder(tester);

    await tester.tap(find.text('解散'));
    await tester.pump();
    expect(gated.pending.length, 1, reason: '前提：第一次点击确实发出去了，且此刻还挂着');

    await tester.tap(find.text('解散'));
    await tester.pump();
    expect(gated.pending.length, 1, reason: '第二次点击不该绕过 _busy 再发一次解散');

    for (final c in gated.pending) {
      c.complete();
    }
    await tester.pumpAndSettle();
    expect(gated.pending.length, 1);
    expect(
      find.byKey(const ValueKey('todo-sidebar-folder-$projectsFolderId')),
      findsNothing,
      reason: '闸门不能把唯一那次真的解散也吞掉',
    );
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

  testWidgets('仓库在点确认时已不可用：框不关、给可见提示、一个字都不写', (tester) async {
    // 第 68 轮同一个坑的自查：spec 的失败分支有两类（仓库为 null / delete 抛错），
    // 只测抛错那类时 null 分支是 0 覆盖。
    // 可达路径：侧栏渲染时仓库还在，用户长按后再点确认 ⇒ 期间库被销毁（退出登录），
    // `ref.read(folderRepositoryProvider)` 就回 null。
    // 文件夹行仍然要出现：所以候选流用另一个仓库实例喂，只把**对话框读的那个**换成 null。
    final fixture = await pumpSidebar(
      tester,
      overridesBuilder: (database) => [
        folderRepositoryProvider.overrideWith((ref) => null),
        foldersStreamProvider.overrideWith(
          (ref) =>
              FolderRepository(database, SyncChangeQueue(database)).watchAll(),
        ),
      ],
    );
    final rowsBefore = await syncRows(fixture);

    await expandAndLongPressFolder(tester);
    await tester.tap(find.text('解散'));
    await tester.pumpAndSettle();

    expect(
      find.text('本地数据库尚未就绪，文件夹没有解散'),
      findsOneWidget,
      reason: '这一支原先是静默 return，用户以为解散好了',
    );
    expect(find.text('取消'), findsOneWidget, reason: '提示要看得见就得让框留着');
    expect(
      await folderById(fixture.database, projectsFolderId),
      isNotNull,
      reason: '这条路径一个字都不该写',
    );
    expect(await syncRows(fixture), rowsBefore);
  });

  testWidgets('仓库后来就绪：提示清掉、重试真的解散（失败不能把框卡死）', (tester) async {
    // 上一条钉"null 分支要给提示"，这条钉它的另一半：那个分支必须把 _busy 放回去。
    // 少了 `_busy = false`，框会永远停在禁用态 ⇒ 用户只能取消重来。
    var ready = false;
    final fixture = await pumpSidebar(
      tester,
      overridesBuilder: (database) => [
        folderRepositoryProvider.overrideWith(
          (ref) => ready
              ? FolderRepository(database, SyncChangeQueue(database))
              : null,
        ),
        foldersStreamProvider.overrideWith(
          (ref) =>
              FolderRepository(database, SyncChangeQueue(database)).watchAll(),
        ),
      ],
    );

    await expandAndLongPressFolder(tester);
    await tester.tap(find.text('解散'));
    await tester.pumpAndSettle();
    expect(find.text('本地数据库尚未就绪，文件夹没有解散'), findsOneWidget);

    ready = true;
    fixture.container.invalidate(folderRepositoryProvider);
    await tester.tap(find.text('解散'));
    await tester.pumpAndSettle();

    expect(find.text('本地数据库尚未就绪，文件夹没有解散'), findsNothing, reason: '重试必须清掉上一条提示');
    expect(
      await folderById(fixture.database, projectsFolderId),
      isNull,
      reason: '_busy 没复位的话这一次点击会被闸门吞掉，文件夹就永远解不散',
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

/// delete 挂起直到测试放行：让"第二次点击落在还开着的框上"成为可能。
class _GatedFolderRepository extends FolderRepository {
  _GatedFolderRepository(super.db, super.queue);

  final List<Completer<void>> pending = <Completer<void>>[];

  @override
  Future<void> delete(String folderId) {
    final c = Completer<void>();
    pending.add(c);
    // 放行之后才真的走仓库 ⇒ 最后那句"侧栏那一行没了"才有意义
    return c.future.then((_) => super.delete(folderId));
  }
}
