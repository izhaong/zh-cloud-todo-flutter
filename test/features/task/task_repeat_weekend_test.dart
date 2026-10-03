import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';

import '../../support/todo_visual_fixture.dart';

const _taskId = TodoVisualFixture.pinnedTaskId;

/// 「每周末」档：嘀嗒《设置重复任务》「固定在每周六和周日重复」。
void main() {
  Future<void> openRepeatDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('task-schedule-options')));
    await tester.pumpAndSettle();

    final detailScroll = find.byType(Scrollable).last;
    final repeatRule = find.byKey(const Key('task-repeat-rule'));
    await tester.scrollUntilVisible(repeatRule, 160, scrollable: detailScroll);
    await tester.ensureVisible(repeatRule);
    await tester.pumpAndSettle();
    await tester.tap(repeatRule);
    await tester.pumpAndSettle();
  }

  testWidgets('重复频率档位表里有「每周末」，保存后按 weekend 出库', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(
            body: TaskDetailPane(taskId: _taskId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openRepeatDialog(tester);
    expect(
      find.byKey(const Key('task-repeat-frequency-weekend')),
      findsOneWidget,
      reason: '档位表里没有每周末档，服务端已支持的 weekend 值到不了用户',
    );
    await tester.tap(find.byKey(const Key('task-repeat-frequency-weekend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    final rules = await fixture.database
        .select(fixture.database.todoRepeatRules)
        .get();
    expect(rules, hasLength(1));
    expect(rules.single.freq, 'WEEKEND');

    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    expect(change.entity, 'repeat_rule');
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(payload['frequency'], 'weekend');
  });

  testWidgets('保存每周末后详情面读回「每周末」而不是裸枚举', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(
            body: TaskDetailPane(taskId: _taskId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openRepeatDialog(tester);
    await tester.tap(find.byKey(const Key('task-repeat-frequency-weekend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('每周末'), findsWidgets);
    expect(find.text('WEEKEND'), findsNothing);
  });
}
