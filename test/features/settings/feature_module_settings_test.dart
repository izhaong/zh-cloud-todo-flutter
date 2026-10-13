import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/107 / FL #574：嘀嗒《03-四象限/01-如何使用四象限》:24「前往「设置」>「功能模块」，
/// 开启「四象限」功能」、《03-常见问题》:802 的「番茄专注」、《07-搜索任务》:12 的「搜索」。
///
/// 判据的着力点不是"页面上有一行字"，而是**关掉之后那个入口真的没了**：
/// 每个负向都配一条同视口的正向对照，先证入口本来是可点的。
void main() {
  Future<SidebarVisibilityRepository> repoOf(TodoVisualFixture fixture) async =>
      SidebarVisibilityRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      );

  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<TodoVisualFixture> pumpSettings(WidgetTester tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    // specs/129 后「日期与时间」组多了「显示习惯打卡」一行，四象限弹层的
    // 选项键被推到 1400px 视口之外 ⇒ 抬高视口（内容多一行）。
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(theme: themed(), home: const SettingsRoute()),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<TodoVisualFixture> pumpPage(
    WidgetTester tester, {
    Size viewport = TodoVisualViewports.wide,
    Widget child = const HomeShell(),
  }) async {
    return pumpTodoVisualScenario(
      tester,
      viewport: viewport,
      fixtureSet: TodoVisualFixtureSet.populated,
      child: child,
    );
  }

  group('仓储', () {
    test('三档默认都是「开」，写其中一档不许把另两档与标签/过滤器顶回默认', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SidebarVisibilityRepository(db, SyncChangeQueue(db));

      for (final module in TodoFeatureModule.values) {
        expect(
          await repo.getFeature(module),
          isTrue,
          reason: '${module.name} 没存过偏好时要等于今天的行为（常驻可达）',
        );
      }

      await repo.save(showTags: false);
      await repo.saveFeature(
        module: TodoFeatureModule.quadrant,
        enabled: false,
      );

      expect(await repo.getFeature(TodoFeatureModule.quadrant), isFalse);
      expect(
        await repo.getFeature(TodoFeatureModule.pomodoro),
        isTrue,
        reason: '写四象限那一档不能顺手把番茄专注顶回或改掉',
      );
      expect(await repo.get(), false, reason: '同一行偏好里的「显示标签」取值也不许被顶回默认');

      await repo.saveFeature(module: TodoFeatureModule.search, enabled: false);
      expect(
        await repo.getFeature(TodoFeatureModule.quadrant),
        isFalse,
        reason: '反方向也一样：写搜索不许把已关的四象限顶回开启',
      );
    });

    test('写一档要出一条 viewPreference outbox，payload 带 module.<枚举名> 键', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final repo = SidebarVisibilityRepository(db, queue);

      await repo.saveFeature(
        module: TodoFeatureModule.pomodoro,
        enabled: false,
      );

      final rows = await db.select(db.todoSyncChanges).get();
      expect(rows, hasLength(1), reason: '一次改档只该出一条 outbox');
      final payload =
          jsonDecode(rows.single.payloadJson) as Map<String, dynamic>;
      final flattened = jsonEncode(payload);
      expect(
        flattened,
        contains('module.pomodoro'),
        reason: '跨端要认得这个键，$payload',
      );
      expect(flattened, contains('false'));
    });
  });

  group('设置页', () {
    testWidgets('「功能模块」分区三档都在，默认显示「开启」', (tester) async {
      await pumpSettings(tester);

      for (final (module, label) in const [
        (TodoFeatureModule.quadrant, '四象限'),
        (TodoFeatureModule.pomodoro, '番茄专注'),
        (TodoFeatureModule.search, '搜索'),
      ]) {
        final tile = find.byKey(Key('todo-settings-module-${module.name}'));
        expect(tile, findsOneWidget, reason: '缺 $label 这一档');
        expect(
          find.descendant(of: tile, matching: find.text('开启')),
          findsOneWidget,
          reason: '$label 没存过偏好要显示默认「开启」',
        );
      }
      // 看板不是功能模块（《02-看板视图》:14），不许混进这张表。
      expect(find.text('看板'), findsNothing);
    });

    testWidgets('点四象限那档选「关闭」⇒ 落库并把当前值显示回「关闭」', (tester) async {
      final fixture = await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('todo-settings-module-quadrant')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('todo-settings-module-quadrant-option-false')),
      );
      await tester.pumpAndSettle();

      expect(
        await (await repoOf(fixture)).getFeature(TodoFeatureModule.quadrant),
        isFalse,
        reason: '点了「关闭」但偏好没落库 = 这一行是假控件',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('todo-settings-module-quadrant')),
          matching: find.text('关闭'),
        ),
        findsOneWidget,
      );
    });
  });

  group('关掉之后入口要真的消失', () {
    testWidgets('四象限：档位菜单里没有该档；开着时在同一条测试里先证出现过', (tester) async {
      final fixture = await pumpPage(
        tester,
        child: const TasksByListPage(
          initialListId: TodoVisualFixture.workListId,
          hideAppBar: true,
        ),
      );

      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      expect(find.text('四象限'), findsOneWidget, reason: '正对照：默认档位里就该有「四象限」');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await (await repoOf(
        fixture,
      )).saveFeature(module: TodoFeatureModule.quadrant, enabled: false);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      expect(find.text('四象限'), findsNothing, reason: '嘀嗒 :24 的开关关掉后不该还能进象限');
      expect(find.text('列表'), findsWidgets, reason: '菜单本身还得开着，否则负向断言是空转');
    });

    testWidgets('番茄专注：dock 里那枚按钮消失，习惯与倒数日不受影响', (tester) async {
      final fixture = await pumpPage(tester);

      expect(
        find.byTooltip('番茄专注'),
        findsOneWidget,
        reason: '正对照：默认侧栏 dock 里有番茄',
      );

      await (await repoOf(
        fixture,
      )).saveFeature(module: TodoFeatureModule.pomodoro, enabled: false);
      await tester.pumpAndSettle();

      expect(find.byTooltip('番茄专注'), findsNothing);
      expect(
        find.byTooltip('习惯打卡'),
        findsOneWidget,
        reason: '源页没把习惯列为可关的功能模块，关掉番茄不许顺手收掉它',
      );
    });

    testWidgets('搜索：AppBar 那枚搜索入口消失（移动视口，正对照在前）', (tester) async {
      final fixture = await pumpPage(
        tester,
        viewport: TodoVisualViewports.mobile,
      );

      expect(find.byTooltip('搜索'), findsOneWidget, reason: '正对照：默认壳层顶部就有搜索入口');

      await (await repoOf(
        fixture,
      )).saveFeature(module: TodoFeatureModule.search, enabled: false);
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('搜索'),
        findsNothing,
        reason: '嘀嗒 :12 说的是"启用后才能进入搜索页面" ⇒ 关掉就该没有入口',
      );
    });
  });
}
