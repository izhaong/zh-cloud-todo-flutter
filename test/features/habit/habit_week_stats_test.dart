import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《05-习惯打卡/03-习惯数据统计》:28/:29/:33/:34（FL #542，矩阵 #46 ④）：
/// 「点击习惯页面中的统计图标，就能够查看到所有习惯的打卡情况」+
/// 「周、月视图」——周视图本单落地；整月视图按 2026-09-23 范围裁定属商业化
/// 不做；「记录回顾」时间轴依赖打卡日志（#45 ④，未落地）不在本单。
const _pagePath = '/todo/habit/page';
const _statsPath = '/todo/habit/stats';

/// 服务端 `stats(period: 'WEEK')` 窗口＝本自然周周一，`dailyCounts` 覆盖
/// 窗口起点到今天的每一天（service `TodoHabitServiceImpl.windowStart`）。
/// 这里用 2026-09-28（周一）..10-04（周日）当"本周"：今天钉在 10-02，
/// 10-03/10-04 两格是未来档——客户端要靠 dailyCounts 有没有这天来分辨，
/// 不能拿本地时钟猜。
final _week = [
  {'date': '2026-09-28', 'count': 1},
  {'date': '2026-09-29', 'count': 0},
  {'date': '2026-09-30', 'count': 2},
  {'date': '2026-10-01', 'count': 0},
  {'date': '2026-10-02', 'count': 3},
];

class FakeHabitServer {
  FakeHabitServer({
    List<Map<String, dynamic>>? habits,
    this.failStatsFor = const {},
  }) : habits = habits ?? _habitsJson();

  final List<Map<String, dynamic>> habits;
  final Set<int> failStatsFor;
  final List<RequestOptions> requests = [];
  final List<String> statsPeriods = [];

  Dio dio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          if (path.endsWith(_pagePath)) {
            return handler.resolve(
              _ok(options, {'list': habits, 'total': habits.length}),
            );
          }
          if (path.endsWith(_statsPath)) {
            final habitId = int.parse('${options.queryParameters['habitId']}');
            statsPeriods.add('${options.queryParameters['period']}');
            if (failStatsFor.contains(habitId)) {
              return handler.resolve(_err(options));
            }
            return handler.resolve(
              _ok(options, {
                'dailyCounts': _week,
                'continuousDays': 2,
                'totalCheckIns': 6,
              }),
            );
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
    data: {'code': 500, 'data': null, 'msg': '服务端统计失败'},
  );
}

List<Map<String, dynamic>> _habitsJson() => [
  {'id': 7, 'name': '喝水', 'period': 1, 'targetCount': 8, 'sortOrder': 1},
  {'id': 9, 'name': '晨跑', 'period': 2, 'targetCount': 3, 'sortOrder': 2},
];

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

void main() {
  testWidgets('列表页有「打卡统计」入口：图标唯一且带读屏标签，点进统计页', (tester) async {
    await pumpHabits(tester);

    expect(find.byKey(const Key('habit-stats-entry')), findsOneWidget);
    expect(find.bySemanticsLabel('打卡统计'), findsOneWidget);

    await tester.tap(find.byKey(const Key('habit-stats-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-week-stats-page')), findsOneWidget);
    expect(find.text('打卡统计'), findsWidgets);
  });

  testWidgets('周视图：每个习惯一行 7 格，表头周一..周日，格子次数来自服务端', (tester) async {
    await pumpHabits(tester);
    await tester.tap(find.byKey(const Key('habit-stats-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('habit-week-row-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('habit-week-row-9')), findsOneWidget);
    expect(find.text('喝水'), findsOneWidget);
    expect(find.text('晨跑'), findsOneWidget);
    // 窗口起点＝服务端 dailyCounts 最早一天（周一 09-28），表头要跟它对齐
    // 而不是拿本地时钟算周一——时区漂移时两边会差一天。
    expect(find.text('09-28'), findsOneWidget);
    // 周视图的格子数与次数：喝水 09-30 打了 2 次
    expect(
      find.byKey(const Key('habit-week-cell-7-2026-09-30')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('habit-week-cell-7-2026-09-30')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('habit-week-cell-9-2026-10-02')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('窗口满 7 列：今天之后的格子是「还没到」，不是 0 次打卡', (tester) async {
    await pumpHabits(tester);
    await tester.tap(find.byKey(const Key('habit-stats-entry')));
    await tester.pumpAndSettle();

    // 服务端只发到今天 10-02；10-03/10-04 两列要画出来但语义是「还没到」
    expect(
      find.byKey(const Key('habit-week-cell-7-2026-10-03')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('habit-week-cell-7-2026-10-04')),
      findsOneWidget,
    );
    expect(find.text('10-03'), findsOneWidget);
    expect(find.text('10-04'), findsOneWidget);
  });

  testWidgets('读屏：有打卡 / 零打卡 / 还没到三种格子各自念得出', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpHabits(tester);
      await tester.tap(find.byKey(const Key('habit-stats-entry')));
      await tester.pumpAndSettle();

      // 两个习惯共用同一份周数据 ⇒ 同一标签会出现两份；按行收窄作用域，
      // 顺便证明「每一行」的格子都各自带读屏标签，不是只有第一行有。
      Finder inRow(int habitId, String label) => find.descendant(
        of: find.byKey(ValueKey('habit-week-row-$habitId')),
        matching: find.bySemanticsLabel(label),
      );
      expect(inRow(7, '9月30日 打卡2次'), findsOneWidget);
      expect(inRow(9, '9月30日 打卡2次'), findsOneWidget);
      expect(inRow(7, '9月29日 没有打卡'), findsOneWidget);
      expect(inRow(9, '9月29日 没有打卡'), findsOneWidget);
      expect(inRow(7, '10月3日 还没到'), findsOneWidget);
      expect(inRow(9, '10月3日 还没到'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('一个习惯统计失败：其余行保留 + 可见提示 + 重试入口', (tester) async {
    final server = FakeHabitServer(failStatsFor: {9});
    await pumpHabits(tester, server: server);
    await tester.tap(find.byKey(const Key('habit-stats-entry')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('habit-week-row-7')),
      findsOneWidget,
      reason: '别的习惯加载成功了就要照常画，不能一个失败整页丢光',
    );
    expect(
      find.byKey(const Key('habit-week-retry')),
      findsOneWidget,
      reason: '部分失败要有可见提示与重试入口',
    );
    expect(find.byKey(const Key('app-refresh-failed-hint')), findsOneWidget);
  });

  testWidgets('全部习惯统计失败：空页给失败提示，重试仍失败不崩', (tester) async {
    final server = FakeHabitServer(failStatsFor: {7, 9});
    await pumpHabits(tester, server: server);
    await tester.tap(find.byKey(const Key('habit-stats-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('habit-week-retry')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('habit-week-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-week-retry')), findsOneWidget);
  });

  testWidgets('320px + 1.3 倍字体：统计页排得下（行内横向滚动兜底）', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHabits(tester);
    await tester.tap(find.byKey(const Key('habit-stats-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('habit-week-stats-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
  });
}
