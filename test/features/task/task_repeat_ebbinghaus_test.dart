import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';

import '../../support/todo_visual_fixture.dart';

/// FL #326（客户端接线，service !416 已并）：艾宾浩斯档位「能选、能存、能读回中文」。
///
/// 嘀嗒《10-设置重复任务》`:105`「重复周期按照 1，2，4，7，15，15，15…… 循环」。
/// 阶梯命中哪天由服务端算（`isEbbinghausOffset` 纯函数），客户端只做档位入口与上行契约。
const _taskId = TodoVisualFixture.pinnedTaskId;

Future<void> _pumpDetail(WidgetTester tester, TodoVisualFixture fixture) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(
          body: TaskDetailPane(taskId: _taskId, onClose: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRepeatDialog(WidgetTester tester) async {
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

Future<void> _revealChip(WidgetTester tester, Key key) async {
  final chip = find.byKey(key);
  if (chip.evaluate().isEmpty) {
    throw StateError('档位 chip 不在树上：key=$key');
  }
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('档位表里有「艾宾浩斯」，选它出库带 ebbinghaus 且不带星期集', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    final chip = find.byKey(const Key('task-repeat-frequency-ebbinghaus'));
    expect(
      chip,
      findsOneWidget,
      reason: '服务端 !416 已支持 ebbinghaus，档位进不了选择器就等于没有这一档',
    );

    await _revealChip(tester, const Key('task-repeat-frequency-ebbinghaus'));
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    final rules = await fixture.database
        .select(fixture.database.todoRepeatRules)
        .get();
    expect(rules.single.freq, 'EBBINGHAUS');
    expect(
      rules.single.byDay,
      isNull,
      reason: '阶梯 offset 内生于档位 —— 服务端 v1 带 weekdays 就拒，客户端不许派生星期集',
    );

    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(payload['frequency'], 'ebbinghaus');
  });

  testWidgets('保存后详情面读回「艾宾浩斯」而不是裸枚举', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    await _revealChip(tester, const Key('task-repeat-frequency-ebbinghaus'));
    await tester.tap(find.byKey(const Key('task-repeat-frequency-ebbinghaus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('艾宾浩斯'), findsWidgets);
    expect(
      find.text('EBBINGHAUS'),
      findsNothing,
      reason: '文案表漏一档时会退化成把枚举名直接印给用户',
    );
  });
}
