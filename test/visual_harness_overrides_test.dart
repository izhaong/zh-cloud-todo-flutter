import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/achievement/achievement_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

import 'support/todo_visual_fixture.dart';
import 'support/todo_visual_test_harness.dart';

/// 视觉 harness 必须能把 override 注进 fixture 的容器。
///
/// `TodoVisualFixture.create` 早就收 `overridesBuilder`，但 `pumpTodoVisualScenario` 把它吞了
/// ⇒ 需要假数据的页面级用例只能自己手搓 `ProviderScope`，与 golden 用的容器成了两套
/// （specs/027 复核 B2 就卡在这）。
///
/// 注意生效顺序：fixture 把调用方的 overrides 拼在内置项**之后**，Riverpod 是 last-wins，
/// 所以调用方连 `appDatabaseProvider`/`apiClientProvider` 都能覆盖掉。
void main() {
  testWidgets('harness 的 overrides 真的被容器采用', (tester) async {
    var consulted = 0;
    await pumpTodoVisualScenario(
      tester,
      viewport: const Size(320, 700),
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (AppDatabase database) => [
        achievementWallProvider.overrideWith((ref) async {
          consulted++;
          throw Exception('故意失败：只为证明注入生效');
        }),
      ],
      child: const AchievementPage(),
    );
    await tester.pump();
    await tester.pump();

    // 只有「注入生效」才会走到这个计数：不覆盖时页面走真 Dio（测试绑定直接给 400），
    // 界面同样是失败态 —— 所以光断言失败文案区分不了，必须盯住 provider 被问过。
    expect(consulted, greaterThan(0), reason: 'overridesBuilder 没被透传时这里就是 0');
    expect(find.text('成就数据加载失败'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('achievement-wall-retry')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
