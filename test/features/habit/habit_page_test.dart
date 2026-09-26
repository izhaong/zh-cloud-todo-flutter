import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// #375 批次 1：习惯页的列表与统计格在「刷新失败」时不得丢掉已加载数据。
///
/// 立单前提由第 1 条用例钉住：Riverpod 在重取失败时给的是 `AsyncError`
/// **且仍带着上一次的 value**（`hasValue=true`、`valueOrNull` 非空），
/// 丢掉数据的是 `.when` 的分支判别，不是框架。
void main() {
  testWidgets('刷新失败保留已加载的列表与统计，并给可见提示', (tester) async {
    final repo = _ProbeRepo();
    final container = await _pump(tester, repo);

    expect(find.text('晨跑'), findsOneWidget);
    expect(find.text('连续打卡'), findsOneWidget);
    // 没有失败时不许出现提示条。
    expect(find.text('列表刷新失败，仍显示上一次的数据'), findsNothing);

    repo.failNext = true;
    container.invalidate(myHabitsProvider);
    container.invalidate(habitStatsProvider);
    await tester.pumpAndSettle();

    expect(find.text('晨跑'), findsOneWidget, reason: '刷新失败不该丢掉已加载的列表');
    expect(find.text('连续打卡'), findsOneWidget, reason: '统计格同理');
    expect(find.text('列表刷新失败，仍显示上一次的数据'), findsOneWidget);
    expect(find.text('统计刷新失败，显示的是上一次数据'), findsOneWidget);
  });

  testWidgets('首值就没读到才走失败态，「重试」成功后恢复列表', (tester) async {
    final repo = _ProbeRepo()..failNext = true;
    await _pump(tester, repo);

    expect(find.text('暂无习惯'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, '重试'),
      findsOneWidget,
      reason: '没有可保留的数据时要有出路的失败态',
    );

    repo.failNext = false;
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(find.text('晨跑'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重试'), findsNothing);
  });

  testWidgets('提示条有独立读屏语义（liveRegion），读屏才会播报新增提示', (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = _ProbeRepo();
    final container = await _pump(tester, repo);

    repo.failNext = true;
    container.invalidate(myHabitsProvider);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('列表刷新失败，仍显示上一次的数据')),
      matchesSemantics(label: '列表刷新失败，仍显示上一次的数据', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('320px + 1.3 倍字号：提示与保留的数据都还在，且无布局溢出', (tester) async {
    final repo = _ProbeRepo();
    final container = await _pump(tester, repo, width: 320, textScale: 1.3);

    repo.failNext = true;
    container.invalidate(myHabitsProvider);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '窄屏 + 大字号不得溢出');
    expect(find.text('晨跑'), findsOneWidget);
    expect(find.text('列表刷新失败，仍显示上一次的数据'), findsOneWidget);
  });

  testWidgets('两次连发刷新：过期的旧响应不得覆盖新响应', (tester) async {
    final repo = _ProbeRepo();
    final container = await _pump(tester, repo);
    expect(find.text('晨跑'), findsOneWidget);

    // 第二次刷新先发但不回，第三次后发先回；最后再放第二次的迟到结果。
    final second = repo.holdNext();
    container.invalidate(myHabitsProvider);
    await tester.pumpAndSettle();
    final third = repo.holdNext();
    container.invalidate(myHabitsProvider);
    await tester.pumpAndSettle();

    third.complete([HabitDto(id: 2, name: '夜跑')]);
    await tester.pumpAndSettle();
    expect(find.text('夜跑'), findsOneWidget);

    second.complete([HabitDto(id: 3, name: '游泳')]);
    await tester.pumpAndSettle();
    expect(find.text('游泳'), findsNothing, reason: '迟到的旧响应不能盖掉新响应');
    expect(find.text('夜跑'), findsOneWidget);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _ProbeRepo repo, {
  double width = 800,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [habitRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const HabitPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// 可控的习惯仓：失败可切换，响应可挂起（测「过期响应」必须有这一层）。
class _ProbeRepo extends HabitRepository {
  _ProbeRepo() : super(Dio());

  bool failNext = false;

  /// 排队挂起器：非空时下一次 listMine 等它被 complete。
  final List<Completer<List<HabitDto>>> _gates = [];

  /// 让下一次 listMine 挂起，返回它的 Completer（由用例决定何时放行）。
  Completer<List<HabitDto>> holdNext() {
    final gate = Completer<List<HabitDto>>();
    _gates.add(gate);
    return gate;
  }

  @override
  Future<List<HabitDto>> listMine({int pageNo = 1, int pageSize = 50}) {
    if (_gates.isNotEmpty) return _gates.removeAt(0).future;
    if (failNext) return Future.error(Exception('boom-list'));
    return Future.value([HabitDto(id: 1, name: '晨跑')]);
  }

  @override
  Future<Map<String, dynamic>> overviewStats() async {
    if (failNext) throw Exception('boom-stats');
    return {'currentStreak': 7, 'weeklyDone': 3, 'totalCheckIns': 21};
  }
}
