import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/achievement/achievement_page.dart';
import 'package:zh_cloud_todo_flutter/features/efficiency/efficiency_hub_page.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

void main() {
  testWidgets('设置页有「成就与勋章」入口，一次点击直达真成就墙', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('成就与勋章'), findsOneWidget);
    final tileTitles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(
      tileTitles,
      containsAllInOrder(['账户安全', '成就与勋章', '退出登录']),
      reason: '入口必须留在「账号」分组内，被搬到「任务」分组时这条要红',
    );

    await tester.tap(find.text('成就与勋章'));
    await tester.pumpAndSettle();

    expect(find.byType(AchievementPage), findsOneWidget);
    expect(find.text('250 成就值'), findsOneWidget);
    expect(find.text('已获得 · 1'), findsOneWidget);
    expect(find.text('未解锁 · 1'), findsOneWidget);
    expect(
      find.byType(EfficiencyHubPage),
      findsNothing,
      reason: '入口须直达成就页，不绕道未被采用的「效率工具」聚合页',
    );
  });

  testWidgets('成就墙拉取失败时入口链路保留可重试，重试后显示数据', (tester) async {
    var attempts = 0;
    await _pumpSettings(
      tester,
      wallOverride: achievementWallProvider.overrideWith((ref) {
        attempts++;
        if (attempts == 1) throw Exception('故意失败：只为钉住失败态');
        return _wall();
      }),
    );

    await tester.tap(find.text('成就与勋章'));
    await tester.pumpAndSettle();

    expect(find.text('成就数据加载失败'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('achievement-wall-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('250 成就值'), findsOneWidget);
  });

  testWidgets('320px 宽 + 1.3 倍字体下成就入口仍可达且不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpSettings(tester);

    final entry = find.text('成就与勋章');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '窄屏 + 大字体下若溢出，RenderFlex 会在这里抛出',
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(AchievementPage), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(AchievementPage)),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '档位没真正生效时这条断言就会失败，避免大字体用例空转',
    );
  });

  testWidgets('成就入口的读屏标签里名称在前、更新口径在后', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpSettings(tester);

      // 实测 `ListTile` 把 title+subtitle 合成一个节点（label 名称打头、口径在后），故只能钉成「同节点内都在」。
      final label = tester
          .getSemantics(find.byIcon(Icons.emoji_events_outlined))
          .label
          .toString();
      expect(label, startsWith('成就与勋章'));
      expect(label, contains('每天凌晨'));
      expect(
        find.bySemanticsLabel(RegExp('^成就与勋章')),
        findsOneWidget,
        reason: '入口若只剩图标（没有可读名称）时这条要红',
      );
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  Override? wallOverride,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wallOverride ??
            achievementWallProvider.overrideWith((ref) async => _wall()),
      ],
      child: const MaterialApp(home: SettingsRoute()),
    ),
  );
  await tester.pumpAndSettle();
}

AchievementWallDto _wall() => const AchievementWallDto(
  totalScore: 250,
  level: 2,
  nextLevelName: 'Lv3',
  nextLevelRequired: 500,
  earnedBadges: [
    AchievementBadgeDto(
      badgeType: 1,
      name: '新手',
      description: '完成首个任务',
      icon: 'starter',
      earned: true,
    ),
  ],
  lockedBadges: [
    AchievementBadgeDto(
      badgeType: 2,
      name: '连续打卡',
      description: '连续打卡 7 天',
      icon: 'streak',
      earned: false,
    ),
  ],
);
