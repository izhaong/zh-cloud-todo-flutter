import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/083 / FL Issue #324：重复频率缺「法定工作日」「法定节假日」两档。
///
/// 嘀嗒《02-功能指南/01-任务/10-设置重复任务》`:65`「- 法定工作日」/
/// `:78`「- 法定节假日」。服务端 Issue #319 已合并（`641aa0768ba2`），
/// 这两档在客户端只做「能选、能存、能读回中文」——命中哪天由服务端字典表决定。
const _taskId = TodoVisualFixture.pinnedTaskId;

Future<void> _pumpDetail(WidgetTester tester, TodoVisualFixture fixture) async {
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

/// 弹窗里档位很多，窄屏/大字下要先滚到目标 chip 才谈得上"可点"。
/// 用 ensureVisible 而不是自算滚动距离：它走的是 widget 自己那层可滚动祖先，
/// 不用在「详情面的 Scrollable」和「弹窗的 Scrollable」之间猜哪个是 .last。
Future<void> _revealChip(WidgetTester tester, Key key) async {
  final chip = find.byKey(key);
  if (chip.evaluate().isEmpty) {
    throw StateError('档位 chip 不在树上：key=$key');
  }
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('档位表里有「法定工作日」与「法定节假日」，选前者出库带 legal-workday', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    final workday = find.byKey(
      const Key('task-repeat-frequency-legal-workday'),
    );
    final holiday = find.byKey(
      const Key('task-repeat-frequency-legal-holiday'),
    );
    expect(
      workday,
      findsOneWidget,
      reason: '服务端已支持 legal-workday，档位进不了选择器就等于没有这一档',
    );
    expect(holiday, findsOneWidget);

    await _revealChip(tester, const Key('task-repeat-frequency-legal-workday'));
    await tester.tap(workday);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    final rules = await fixture.database
        .select(fixture.database.todoRepeatRules)
        .get();
    expect(rules.single.freq, 'LEGAL_WORKDAY');
    expect(
      rules.single.byDay,
      isNull,
      reason: '客户端不许为这两档派生星期集，否则「法定工作日」被偷偷近似成「周一至周五」',
    );

    final change =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .last;
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(payload['frequency'], 'legal-workday');
  });

  testWidgets('保存后详情面读回「法定节假日」而不是裸枚举', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    await _revealChip(tester, const Key('task-repeat-frequency-legal-holiday'));
    await tester.tap(
      find.byKey(const Key('task-repeat-frequency-legal-holiday')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-repeat-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('法定节假日'), findsWidgets);
    expect(
      find.text('LEGAL_HOLIDAY'),
      findsNothing,
      reason: '文案表漏一档时会退化成把枚举名直接印给用户',
    );
  });

  testWidgets('320px 宽 + 1.3 倍字号：两档 chip 仍在同一张档位表里且可点', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpDetail(tester, fixture);

    await _openRepeatDialog(tester);
    for (final key in const [
      Key('task-repeat-frequency-legal-workday'),
      Key('task-repeat-frequency-legal-holiday'),
    ]) {
      await _revealChip(tester, key);
      expect(find.byKey(key), findsOneWidget);
      final box = tester.renderObject<RenderBox>(find.byKey(key));
      expect(
        box.size.width,
        lessThanOrEqualTo(320),
        reason: '窄屏里档位 chip 不该撑出可视宽',
      );
    }
    expect(tester.takeException(), isNull, reason: '1.3 倍字号下不该抛溢出');
  });

  testWidgets('两档都有能被读屏念出的中文名', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pumpDetail(tester, fixture);
    final handle = tester.ensureSemantics();

    await _openRepeatDialog(tester);
    await _revealChip(tester, const Key('task-repeat-frequency-legal-workday'));
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('task-repeat-frequency-legal-workday')),
          )
          .label,
      contains('法定工作日'),
    );
    await _revealChip(tester, const Key('task-repeat-frequency-legal-holiday'));
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('task-repeat-frequency-legal-holiday')),
          )
          .label,
      contains('法定节假日'),
    );
    handle.dispose();
  });
}
