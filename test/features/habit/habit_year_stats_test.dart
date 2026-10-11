import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《05-习惯打卡/03-习惯数据统计.md》：
/// - `:6`「在习惯详情页的统计中，我们提供了「月度打卡表」和「打卡数据」」
/// - `:10`（tab mobile）「在单个习惯页面中向上滑动就能够看到这个习惯整体的打卡数据。」
/// - `:24`「在打卡数据中点击「更多」，还能够进入到该习惯的年度热力统计页」
///
/// FL #377：本文件钉「打卡数据」卡片与「年度热力统计页」两面。
/// 「月度打卡表」在 specs/043 已有，不在这里重复。
const _pagePath = '/todo/habit/page';
const _statsPath = '/todo/habit/stats';

/// 假服务：`/stats` 记录 period 并按 [yearly] 返回年度窗口 payload。
/// `failStats` / `failStatsAfterFirst` 用来钉「刷新失败保留已加载数据」。
class FakeHabitServer {
  FakeHabitServer({this.yearly = true, this.failStats = false});

  bool yearly;
  bool failStats;
  bool failStatsAfterFirst = false;
  int statsCalls = 0;
  int yearCalls = 0;
  final List<String> statsPeriods = [];
  final List<RequestOptions> requests = [];

  Map<String, dynamic> _payload() {
    if (!yearly) {
      return {
        'continuousDays': 3,
        'longestContinuous': 5,
        'totalCheckIns': 7,
        'dailyCounts': [
          {'date': '2026-07-15', 'count': 1},
        ],
      };
    }
    // 2026-01-01 .. 2026-07-15：196 天（31+28+31+30+31+30+15），测试注入的「服务端今天」。
    final days = <Map<String, dynamic>>[];
    var date = DateTime(2026, 1, 1);
    final end = DateTime(2026, 7, 15);
    var checkIns = 0;
    while (!date.isAfter(end)) {
      final count = date.day % 5 == 0 ? 2 : (date.day % 7 == 0 ? 1 : 0);
      checkIns += count;
      days.add({
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'count': count,
      });
      date = date.add(const Duration(days: 1));
    }
    return {
      'continuousDays': 4,
      'longestContinuous': 9,
      'totalCheckIns': checkIns,
      'dailyCounts': days,
    };
  }

  Dio dio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          if (path.endsWith(_pagePath)) {
            return handler.resolve(
              _ok(options, {
                'list': [_habitJson()],
                'total': 1,
              }),
            );
          }
          if (path.endsWith(_statsPath)) {
            statsCalls++;
            final period = '${options.queryParameters['period']}';
            statsPeriods.add(period);
            final isYear = period == 'YEAR';
            if (isYear) yearCalls++;
            if (failStats ||
                // 只对 YEAR 请求注入失败：列表页 overviewStats 的 WEEK 调用
                // 也走这条拦截器，不能把「第一次成功」判据污染掉。
                (failStatsAfterFirst && isYear && yearCalls > 1)) {
              return handler.resolve(_err(options));
            }
            return handler.resolve(_ok(options, _payload()));
          }
          handler.next(options);
        },
      ),
    );
    return dio;
  }
}

Response<Map<String, dynamic>> _ok(RequestOptions options, dynamic data) {
  return Response<Map<String, dynamic>>(
    requestOptions: options,
    statusCode: 200,
    data: {'code': 0, 'data': data, 'msg': ''},
  );
}

Response<Map<String, dynamic>> _err(RequestOptions options) {
  return Response<Map<String, dynamic>>(
    requestOptions: options,
    statusCode: 200,
    data: {'code': 500, 'data': null, 'msg': '统计服务开小差'},
  );
}

Map<String, dynamic> _habitJson() => {
  'id': 7,
  'name': '喝水',
  'icon': 'water',
  'color': '#22C55E',
  'period': 1,
  'targetCount': 8,
  'sortOrder': 3,
  'archived': false,
};

Future<FakeHabitServer> pumpHabits(
  WidgetTester tester, {
  FakeHabitServer? server,
}) async {
  final fake = server ?? FakeHabitServer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitRepositoryProvider.overrideWithValue(HabitRepository(fake.dio())),
      ],
      child: const MaterialApp(home: HabitPage()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// 进入详情页（从列表点习惯卡片）。
Future<void> openDetail(WidgetTester tester) async {
  await tester.tap(find.text('喝水'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('habit-detail-page')), findsOneWidget);
}

void main() {
  testWidgets('详情页滚动区出现「打卡数据」：三项数字与服务端逐字段对上，窗口标「本年」，请求 period=YEAR', (
    tester,
  ) async {
    final server = await pumpHabits(tester);
    await openDetail(tester);

    expect(
      find.byKey(const Key('habit-stats-card')),
      findsOneWidget,
      reason: '打卡数据卡片没挂在详情页滚动区（:10「向上滑动就能够看到」）',
    );
    expect(
      server.statsPeriods.where((p) => p == 'YEAR'),
      hasLength(1),
      reason: '「整体打卡数据」按本年窗口取（服务端 YEAR ⇒ 本年 1 月 1 号起）',
    );
    final payload = FakeHabitServer()._payload();
    expect(find.text('打卡数据'), findsOneWidget);
    expect(
      find.text('本年'),
      findsOneWidget,
      reason: '窗口标签要与 period=YEAR 一致，不能无标签报总数',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('habit-stats-card')),
        matching: find.text('${payload['totalCheckIns']}'),
      ),
      findsOneWidget,
      reason: '累计打卡与服务端 totalCheckIns 逐字段对上',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('habit-stats-card')),
        matching: find.text('${payload['continuousDays']}'),
      ),
      findsOneWidget,
      reason: '连续天数与 continuousDays 对上',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('habit-stats-card')),
        matching: find.text('${payload['longestContinuous']}'),
      ),
      findsOneWidget,
      reason: '最长连续与 longestContinuous 对上',
    );
  });

  testWidgets('「更多」入口在卡片上且只有一处；菜单仍只有「月度打卡表」，不重复', (tester) async {
    await pumpHabits(tester);
    await openDetail(tester);

    expect(
      find.byKey(const Key('habit-stats-more')),
      findsOneWidget,
      reason: ':24「在打卡数据中点击「更多」」——入口挂在卡片上',
    );

    await tester.tap(find.byKey(const Key('habit-stats-more')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('habit-year-heatmap-page')),
      findsOneWidget,
      reason: '「更多」要推入年度热力统计页',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('habit-detail-menu')));
    await tester.pumpAndSettle();
    expect(
      find.text('年度热力'),
      findsNothing,
      reason: '菜单里不得出现第二处年度热力入口（:24 只写在打卡数据的「更多」上）',
    );
    expect(find.text('月度打卡表'), findsOneWidget);
  });

  testWidgets('年度热力页：格子数 == 服务端窗口天数，首格日期 == 当年 01-01，有打卡与零打卡都渲染', (
    tester,
  ) async {
    final server = await pumpHabits(tester);
    await openDetail(tester);
    await tester.tap(find.byKey(const Key('habit-stats-more')));
    await tester.pumpAndSettle();

    final payload = FakeHabitServer()._payload();
    final days = (payload['dailyCounts'] as List).length;
    expect(
      find.byWidgetPredicate(
        (w) => w.key is Key && '${(w.key as Key)}'.contains('habit-heat-cell-'),
      ),
      findsNWidgets(days),
      reason: '格数要 == 服务端 YEAR 窗口逐日数（本年已过天数），一天都不能少',
    );
    expect(
      find.byKey(const Key('habit-heat-cell-2026-01-01')),
      findsOneWidget,
      reason: '首格是 01-01（服务端 YEAR 窗口从本年 1 月 1 号起）',
    );
    expect(
      find.byKey(const Key('habit-heat-cell-2026-07-15')),
      findsOneWidget,
      reason: '末格是窗口最后一天',
    );
    expect(server.yearCalls, 1, reason: '热力页复用卡片已在飞的同一份 YEAR 数据，不再重复拉');
  });

  testWidgets('读屏：热力格念「M月d日 打卡N次」，0 次也念（不能只靠颜色）', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpHabits(tester);
      await openDetail(tester);
      await tester.tap(find.byKey(const Key('habit-stats-more')));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('1月5日 打卡2次'),
        findsOneWidget,
        reason: '有打卡的日子要念出日期与次数',
      );
      expect(
        find.bySemanticsLabel('1月1日 打卡0次'),
        findsOneWidget,
        reason: '零打卡日只有颜色差异 ⇒ 读屏必须把 0 也念出来',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('热力页下拉刷新失败：保留已加载数据并给可见提示', (tester) async {
    final server = FakeHabitServer()..failStatsAfterFirst = true;
    await pumpHabits(tester, server: server);
    await openDetail(tester);
    await tester.tap(find.byKey(const Key('habit-stats-more')));
    await tester.pumpAndSettle();

    // 首屏已经画出 07-15 的格子；下拉刷新第二次 YEAR 请求失败。
    expect(
      find.byKey(const Key('habit-heat-cell-2026-07-15')),
      findsOneWidget,
      reason: '前提：首屏加载成功',
    );
    await tester.drag(
      find.byKey(const Key('habit-heat-cell-2026-07-15')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

    expect(server.yearCalls, 2, reason: '下拉必须真的触发第二次 YEAR 请求，否则后面的「保留/提示」全在空转');
    expect(
      find.byKey(const Key('habit-heat-cell-2026-07-15')),
      findsOneWidget,
      reason: '刷新失败不能把已加载的整年格子丢掉（specs/045 同形）',
    );
    expect(
      find.byKey(const Key('app-refresh-failed-hint')),
      findsOneWidget,
      reason: '失败要有可见提示',
    );
    expect(
      find.byKey(const Key('habit-year-retry')),
      findsOneWidget,
      reason: '提示要带重试入口',
    );
  });

  testWidgets('打卡数据卡片加载失败：无数字、失败提示可见，重试仍失败不崩', (tester) async {
    final server = FakeHabitServer()..failStats = true;
    await pumpHabits(tester, server: server);
    await openDetail(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('habit-stats-card')),
        matching: find.byKey(const Key('habit-stats-total')),
      ),
      findsNothing,
      reason: '没有数据就不许画 0 冒充事实',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('habit-stats-card')),
        matching: find.byKey(const Key('app-refresh-failed-hint')),
      ),
      findsOneWidget,
      reason: '首屏失败要有可见提示',
    );

    await tester.tap(find.byKey(const Key('habit-stats-retry')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('habit-stats-card')),
        matching: find.byKey(const Key('app-refresh-failed-hint')),
      ),
      findsOneWidget,
      reason: '重试仍失败：提示保留、不崩溃',
    );
  });

  testWidgets('320px + 1.3 倍字体：详情页（含打卡数据）与热力页都排得下', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHabits(tester);
    await openDetail(tester);
    expect(tester.takeException(), isNull, reason: '详情页含打卡数据卡片在窄屏大字体下溢出');

    await tester.tap(find.byKey(const Key('habit-stats-more')));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: '热力页在 320px 下溢出——53 周格子要可横向滚动，不许缩字号硬塞',
    );

    final scrollable = find.descendant(
      of: find.byKey(const Key('habit-year-heatmap-page')),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsWidgets, reason: '热力页要有横向滚动承载全年格子');
  });
}
