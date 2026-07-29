import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/quadrant/quadrant_rules_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

void main() {
  testWidgets('规则页展示服务端默认规则并可进入编辑', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quadrantRulesProvider.overrideWith(
            (ref) async => const [
              QuadrantRuleDto(
                id: 7,
                name: '我的四象限',
                type: QuadrantRuleType.priorityTime,
                isDefault: true,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: QuadrantRulesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的四象限'), findsOneWidget);
    expect(find.text('优先级 + 截止时间 · 默认规则'), findsOneWidget);

    await tester.tap(find.text('我的四象限'));
    await tester.pumpAndSettle();
    expect(find.text('编辑四象限规则'), findsOneWidget);
    expect(find.text('设为默认规则'), findsOneWidget);
  });

  testWidgets('自定义规则在提交前校验分组 JSON', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quadrantRulesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: QuadrantRulesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建第一条规则'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '规则名称'), '自定义规则');
    await tester.tap(find.text('优先级 + 截止时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义条件').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '自定义分组 JSON'),
      'not-json',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('自定义条件必须是非空的 [{key, condition}] JSON 数组'), findsOneWidget);
  });
}
