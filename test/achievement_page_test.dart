import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/achievement/achievement_page.dart';
import 'package:zh_cloud_todo_flutter/features/efficiency/efficiency_hub_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

void main() {
  testWidgets('成就墙展示等级进度和已获得、未解锁勋章', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementWallProvider.overrideWith((ref) async => _wall()),
        ],
        child: const MaterialApp(home: AchievementPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv2'), findsOneWidget);
    expect(find.text('250 成就值'), findsOneWidget);
    expect(find.text('距离 Lv3 还需 250'), findsOneWidget);
    expect(find.text('已获得 · 1'), findsOneWidget);
    expect(find.text('新手'), findsOneWidget);
    expect(find.text('完成首个任务'), findsOneWidget);
    expect(find.text('未解锁 · 1'), findsOneWidget);
    expect(find.text('连续打卡'), findsOneWidget);
  });

  testWidgets('成就墙加载失败后可以重试', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementWallProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw Exception('network');
            return _wall();
          }),
        ],
        child: const MaterialApp(home: AchievementPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('成就数据加载失败'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('achievement-wall-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('250 成就值'), findsOneWidget);
  });

  testWidgets('效率中心提供成就勋章第四个页签', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pomodoroApiProvider.overrideWithValue(_FakePomodoroApi()),
          myHabitsProvider.overrideWith((ref) async => const []),
          habitStatsProvider.overrideWith((ref) async => const {}),
          countdownsProvider.overrideWith((ref) async => const []),
          achievementWallProvider.overrideWith((ref) async => _wall()),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(320, 700)),
            child: EfficiencyHubPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('番茄专注'), findsWidgets);
    expect(find.text('习惯打卡'), findsOneWidget);
    expect(find.text('倒数纪念日'), findsOneWidget);
    expect(find.text('成就勋章'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
      earned: false,
    ),
  ],
);

class _FakePomodoroApi extends PomodoroApi {
  _FakePomodoroApi() : super(Dio());

  @override
  Future<PomodoroSessionDto?> active() async => null;
}
