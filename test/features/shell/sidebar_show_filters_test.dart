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

    // 四件套 ③「失败保留已加载数据」：措辞说了不算，界面这一行的取值必须真的没动。
    expect(
      find.descendant(
        of: find.byKey(const Key('todo-settings-show-filters')),
        matching: find.text('显示'),
      ),
      findsOneWidget,
      reason: '写失败后这一行显示的还得是原取值「显示」，不是点中的「隐藏」也不是「…」',
    );
    expect(
      find.text('读取偏好失败，显示的是上次读到的值'),
      findsNothing,
      reason: '写失败不等于读失败：不该冒出「读到的还是上次的值」这条只有读侧才该出现的提示',
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

  testWidgets('设置页 320px + 1.3 倍字号：环境真的落到这一行的 context 上且不溢出', (tester) async {
    const tileKey = Key('todo-settings-show-filters');
    await _pumpSettings(tester, textScale: 1.3, width: 320);

    // 这两条是防「参数没接线就白测一遍宽屏」：字号与视口都要从被测节点自己的上下文读回来。
    expect(
      MediaQuery.of(tester.element(find.byKey(tileKey))).textScaler.scale(14),
      closeTo(18.2, 0.001),
      reason: '「1.3 倍字号」必须真的作用在设置页这一行的 context 上',
    );
    expect(
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      320,
      reason: '「320px」必须真的送到 harness 的视口，否则测的是 1440 宽屏',
    );

    expect(find.byKey(tileKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「过滤器」这一行的读屏名字带标题和当前取值，改档后要跟着换', (tester) async {
    const tileKey = Key('todo-settings-show-filters');
    final handle = tester.ensureSemantics();
    await _pumpSettings(tester);

    // 同页「显示标签」那一行的取值也是「显示/隐藏」，判据必须切进带 key 的那一行，
    // 否则会被旁侧那一行满足（同目录 sidebar_show_tags_settings_test.dart:207 的合并 label 口径）。
    String labelOfValue(String value) => tester
        .getSemantics(
          find.descendant(of: find.byKey(tileKey), matching: find.text(value)),
        )
        .label;

    var label = labelOfValue('显示');
    expect(label, contains('过滤器'), reason: '读屏要念得出这一行管的是什么');
    expect(
      label,
      contains('显示'),
      reason: '偏好当前值用文字放在 trailing：读屏念到的是「过滤器 … 显示」',
    );

    await _pickFilterOption(tester, showFilters: false);

    label = labelOfValue('隐藏');
    expect(label, contains('过滤器'));
    expect(label, contains('隐藏'), reason: '改档后取值要进label，不能停在旧值');
    expect(
      label,
      isNot(contains('显示')),
      reason: '副标题「控制过滤器条目是否出现在侧栏」不含「显示」，念到它就说明取值没换过来',
    );

    handle.dispose();
  });

  testWidgets('存的是点中的那个字面值，不是从当前值取反', (tester) async {
    const tileKey = Key('todo-settings-show-filters');
    late _RecordingRepository recorder;
    final fixture = await _pumpSettings(
      tester,
      overridesBuilder: (database) {
        recorder = _RecordingRepository(database, SyncChangeQueue(database));
        return [
          sidebarVisibilityRepositoryProvider.overrideWith((ref) => recorder),
        ];
      },
    );

    // 默认「显示」⇒ 点「显示」这一档。取反实现会写 false，这一条就是它的红测。
    await tester.tap(find.byKey(tileKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('todo-settings-show-filters-option-true')),
    );
    await tester.pumpAndSettle();
    expect(recorder.picked, [true], reason: '点中的是「显示」，写库就必须是 true；取反会写成 false');

    await tester.tap(find.byKey(tileKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('todo-settings-show-filters-option-false')),
    );
    await tester.pumpAndSettle();
    expect(recorder.picked, [true, false], reason: '两档各写各的字面值，与当前值无关');
    expect(
      await SidebarVisibilityRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      ).getFilters(),
      false,
      reason: '记录用的仓储照常落库，别把这条用例退化成纯 mock 断言',
    );
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
  double textScale = 1,
  double width = 480,
}) async {
  final fixture = await pumpTodoVisualScenario(
    tester,
    viewport: width >= 400 ? TodoVisualViewports.wide : const Size(320, 900),
    fixtureSet: TodoVisualFixtureSet.populated,
    overridesBuilder: overridesBuilder,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: const SettingsRoute(),
    ),
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

/// 记下面向界面发起的每一次 `saveFilters` 的实参，同时照常落库。
class _RecordingRepository extends SidebarVisibilityRepository {
  _RecordingRepository(super.db, super.queue);

  final List<bool> picked = <bool>[];

  @override
  Future<void> saveFilters({required bool showFilters}) async {
    picked.add(showFilters);
    await super.saveFilters(showFilters: showFilters);
  }
}

/// 走界面的完整链路：点这一行 ⇒ 弹出「显示/隐藏」两档 ⇒ 点其中一档。
Future<void> _pickFilterOption(
  WidgetTester tester, {
  required bool showFilters,
}) async {
  await tester.tap(find.byKey(const Key('todo-settings-show-filters')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(Key('todo-settings-show-filters-option-$showFilters')),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}
