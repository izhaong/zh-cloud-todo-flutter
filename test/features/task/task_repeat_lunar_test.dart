import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// FL #325（客户端接线，service !417 已并）：农历两档「能选、能存、能读回中文」。
///
/// 嘀嗒《10-设置重复任务》`:91`「农历每年（春节、中秋、家人农历生日）/ 农历每月（初一、十五祈福）」。
/// 农历月日是**用户意图**（opencode 交叉验证修正：上行的是意图不是结果；
/// 服务端以它为准并规范化 startAt，客户端无农历表、不反解）。
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
  testWidgets('选「农历每年」+ 八月十五 ⇒ 出库带 lunar-yearly/lunarMonth=8/lunarDay=15', (
    tester,
  ) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    final chip = find.byKey(const Key('task-repeat-frequency-lunar-yearly'));
    expect(
      chip,
      findsOneWidget,
      reason: '服务端 !417 已支持 lunar-yearly，档位进不了选择器就等于没有这一档',
    );
    await _revealChip(tester, const Key('task-repeat-frequency-lunar-yearly'));
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // 农历选择器自动弹出（选中档位即要求表达"意图"）
    final monthPicker = find.byKey(const Key('lunar-month-picker'));
    expect(monthPicker, findsOneWidget, reason: '农历每年档必须先选农历月日（意图）');
    await tester.tap(monthPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('农历八月').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lunar-day-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('十五').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lunar-picker-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    final rules = await fixture.database
        .select(fixture.database.todoRepeatRules)
        .get();
    expect(rules.single.freq, 'LUNAR_YEARLY');
    expect(rules.single.lunarMonth, 8);
    expect(rules.single.lunarDay, 15);
    expect(rules.single.byDay, isNull, reason: '农历档与星期集正交 —— 服务端带了就拒，客户端不许派生');

    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(payload['frequency'], 'lunar-yearly');
    expect(payload['lunarMonth'], 8);
    expect(payload['lunarDay'], 15);
  });

  test(
    '直调 repository：农历每年缺 lunarMonth/lunarDay ⇒ ArgumentError（防静默 NULL 落库）',
    () async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repository = fixture.container.read(repeatRuleRepositoryProvider);
      expect(repository, isNotNull, reason: 'fixture 应提供 repeatRuleRepository');
      await expectLater(
        repository!.save(
          taskId: _taskId,
          frequency: 'LUNAR_YEARLY',
          lunarMonth: null,
          lunarDay: null,
          startAt: DateTime.now(),
        ),
        throwsArgumentError,
        reason:
            '缺意图时必须拒 —— 静默存 NULL 会让服务端反解兜底悄悄生效，'
            '而用户以为自己设了"八月十五"',
      );
      await expectLater(
        repository.save(
          taskId: _taskId,
          frequency: 'LUNAR_MONTHLY',
          lunarMonth: 8, // 每月档带月 ⇒ 拒
          lunarDay: 15,
          startAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.save(
          taskId: _taskId,
          frequency: 'LUNAR_MONTHLY',
          lunarDay: null, // 每月档缺农历日 ⇒ 拒（本判据咬的就是这条检查）
          startAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.save(
          taskId: _taskId,
          frequency: 'DAILY',
          lunarDay: 15, // 非农历档带 lunar 字段 ⇒ 拒（反向互斥，防改档残留）
          startAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    },
  );

  testWidgets('农历每年未选月日时保存被拦（不静默存 NULL 意图）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    final chip = find.byKey(const Key('task-repeat-frequency-lunar-yearly'));
    await _revealChip(tester, const Key('task-repeat-frequency-lunar-yearly'));
    await tester.tap(chip);
    await tester.pumpAndSettle();
    // 选了档但**取消**农历选择器 ⇒ 意图缺失 ⇒ 保存按钮必须拦住。
    // ⚠️ 树上有两个"取消"（重复弹窗 + 农历选择器）—— 用 key 定位后弹的那个，
    // `.last` 在弹层关闭顺序变化时会点错（本判据第一版就因此假绿：探针拿掉守卫仍绿）
    await tester.tap(find.byKey(const Key('lunar-picker-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    final rules = await fixture.database
        .select(fixture.database.todoRepeatRules)
        .get();
    expect(
      rules,
      isEmpty,
      reason:
          '意图缺失时保存必须被拦 —— 存 NULL 会让服务端反解兜底悄悄生效，'
          '而用户以为自己设了"八月十五"',
    );
  });

  testWidgets('保存后详情面读回「农历每年 八月十五」而不是裸枚举', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    final chip = find.byKey(const Key('task-repeat-frequency-lunar-yearly'));
    await _revealChip(tester, const Key('task-repeat-frequency-lunar-yearly'));
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lunar-month-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('农历八月').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lunar-day-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('十五').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lunar-picker-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('农历每年 八月十五'), findsWidgets);
    expect(
      find.text('LUNAR_YEARLY'),
      findsNothing,
      reason: '文案表漏一档时会退化成把枚举名直接印给用户',
    );
  });
}
