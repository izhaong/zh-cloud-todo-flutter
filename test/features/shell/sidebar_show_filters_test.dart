import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md》
/// 桌面 tab 逐字：`:29`「使用前，确认侧边栏中是否已经开启显示过滤器，开启后，标签将显示在清单下面。」
/// `:33`「如果过滤器未在侧边栏中显示，点击头像进入「设置」-「智能清单」，找到「过滤器」设置为「显示」即可。」
/// ⇒ 「过滤器」在侧栏的显隐是**用户偏好**，且开关落在「设置」-「智能清单」里。
///
/// FL Issue #336：develop 上侧栏的「筛选器」是常驻行（`sidebar.dart` 的
/// `todo-sidebar-row-filters`），设置页「智能清单」分组里只有「标签」一行 ⇒ 这个开关整面缺。
void main() {
  final filtersRow = find.byKey(const Key('todo-sidebar-row-filters'));
  final tagsRow = find.byKey(const Key('todo-sidebar-row-tags'));

  testWidgets('侧栏「筛选器」入口跟着「显示过滤器」走：默认在、关掉就没、再打开又回来', (tester) async {
    final fixture = await _pumpSidebar(tester);

    expect(filtersRow, findsOneWidget, reason: '没存过偏好时按默认「显示」，侧栏要有「筛选器」那一行');

    await _saveFilters(tester, fixture, showFilters: false);
    expect(filtersRow, findsNothing, reason: '关掉后这一行不该再画出来');
    // 「标签」入口行不受这条偏好影响：两条开关各管自己那一行（《过滤器》只讲过滤器）。
    expect(tagsRow, findsOneWidget, reason: '「显示过滤器」不能顺手把「标签」入口也收掉');

    await _saveFilters(tester, fixture, showFilters: true);
    expect(filtersRow, findsOneWidget, reason: '重新打开要立刻回来，不必重进侧栏');
  });

  testWidgets('两个开关写同一行偏好：改「过滤器」不许把「标签」的取值盖回默认', (tester) async {
    final fixture = await _pumpSidebar(tester);
    final repo = SidebarVisibilityRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    );

    await repo.save(showTags: false);
    expect(await repo.get(), false, reason: '先钉住「标签=隐藏」这条状态是真的');

    await repo.saveFilters(showFilters: false);

    expect(
      await repo.get(),
      false,
      reason: '写过滤器时把标签读成默认「显示」= 一次操作改了用户没碰的那个开关',
    );
    expect(await repo.getFilters(), false);

    await repo.save(showTags: true);
    expect(await repo.getFilters(), false, reason: '反方向也一样：写标签不许把过滤器顶回默认');
  });

  testWidgets('设置页「智能清单」分组里有「过滤器」一行，选了「隐藏」就落库', (tester) async {
    final fixture = await _pumpSettings(tester);

    expect(find.text('过滤器'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-settings-show-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐藏'));
    await tester.pumpAndSettle();

    expect(
      await SidebarVisibilityRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      ).getFilters(),
      false,
      reason: '设置页点了「隐藏」但偏好没落库 = 这一行是个假控件',
    );
  });

  testWidgets('保存偏好失败时设置页要说明原因，并把当前取值显示回原样', (tester) async {
    await _pumpSettings(
      tester,
      overridesBuilder: (database) => [
        sidebarVisibilityRepositoryProvider.overrideWith(
          (ref) => _SaveFailsRepository(database, SyncChangeQueue(database)),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('todo-settings-show-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐藏'));
    await tester.pumpAndSettle();

    expect(
      find.text('保存失败，过滤器仍为当前设置'),
      findsOneWidget,
      reason: '与同页「显示标签」那条同一措辞：写失败不能静默',
    );
  });

  testWidgets('320px + 1.3 倍字号下侧栏两种显隐都不溢出', (tester) async {
    final fixture = await _pumpSidebar(tester, textScale: 1.3, width: 320);

    expect(filtersRow, findsOneWidget);
    expect(tester.takeException(), isNull);

    await _saveFilters(tester, fixture, showFilters: false);
    expect(tester.takeException(), isNull);
    expect(filtersRow, findsNothing);
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
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Material(
          child: Sidebar(
            width: width,
            selectedSection: Section.tasks,
            selectedSmart: SmartList.inbox,
            selectedListId: null,
            onSelectSection: (_) {},
            onSelectSmart: (_) {},
            onSelectList: (_) {},
            onOpenTags: () {},
            onOpenFilters: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    ),
  );
}

Future<TodoVisualFixture> _pumpSettings(
  WidgetTester tester, {
  List<Override> Function(AppDatabase database)? overridesBuilder,
}) async {
  final fixture = await pumpTodoVisualScenario(
    tester,
    viewport: TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
    child: const SettingsRoute(),
  );
  await tester.pumpAndSettle();
  // 设置页是 `ListView` 懒建的：不先滚到那一行，`find` 与 `tap` 都拿不到它
  // （同目录 `sidebar_show_tags_settings_test.dart` 的 `_revealTile` 立过这条规矩）。
  final tile = find.byKey(const Key('todo-settings-show-filters'));
  await tester.scrollUntilVisible(
    tile,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _saveFilters(
  WidgetTester tester,
  TodoVisualFixture fixture, {
  required bool showFilters,
}) async {
  await SidebarVisibilityRepository(
    fixture.database,
    SyncChangeQueue(fixture.database),
  ).saveFilters(showFilters: showFilters);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

/// 读得到、写不进：钉「失败不许静默」这条时不能靠未登录分支（那条有别的措辞）。
class _SaveFailsRepository extends SidebarVisibilityRepository {
  _SaveFailsRepository(super.db, super.queue);

  @override
  Future<void> saveFilters({required bool showFilters}) async {
    throw StateError('本地库只读');
  }
}
