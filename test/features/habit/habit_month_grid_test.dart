import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/habit/habit_month_grid.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《02-功能指南/05-习惯打卡/02-更好地完成习惯.md》：
/// `:77`/`:84`「点击习惯…查看当月打卡情况」、`:94`「在「月度打卡表」中点击任意日期，即可补记打卡」。
///
/// 用例只驱动已有的 `HabitPage` + 字符串 key + 可见文案，不引用新 widget 类名 ⇒
/// 未实现时是「点了没出表 / 补记没传 date」的行为红，不是编译红。
void main() {
  /// 后端 `AppTodoHabitStatsRespVO.DailyCountVO.date` 的真实形状：Java
  /// `LocalDate.toString()` ⇒ 零填充的 ISO `yyyy-MM-dd`。
  /// 这里故意用 `toIso8601String` 派生，不照抄生产代码里的 padLeft ⇒
  /// 「客户端解析出的 key 与后端给的串对得上」不是自证。
  String iso(DateTime d) => d.toIso8601String().split('T').first;
  String cellKey(DateTime d) => 'todo-habit-day-${iso(d)}';

  // 全部落在当月：每一天都有 1、2、末号三格，用例不随「今天是几号」变红。
  final now = DateTime.now();
  final dayA = DateTime(now.year, now.month, 1);
  final dayB = DateTime(now.year, now.month, 2);
  final lastDay = DateTime(now.year, now.month + 1, 0);
  final monthDayCount = lastDay.day;

  late _FakeHabitRepository repo;

  Future<void> pumpHabit(
    WidgetTester tester, {
    Size? surface,
    double textScale = 1,
  }) async {
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      ProviderScope(
        // 只假仓库：`myHabitsProvider` / `habitStatsProvider` 都走真实实现，
        // 这样「补记后刷的是打卡概览」才有可断言的调用次数。
        overrides: [habitRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          // 档位挂在 `MaterialApp.builder` 上：`showModalBottomSheet` 的路由是
          // Navigator 的子节点，包在 `home:` 里的 MediaQuery 传不进弹层。
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const HabitPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMonthSheet(WidgetTester tester) async {
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    // 嘀嗒《02-更好地完成习惯》:77 是「点击习惯进入打卡页面」，月度表挂在详情页「...」里，
    // 不再是点列表行直接弹表 ⇒ 本文件的入口全部走详情页。
    await tester.tap(find.byKey(const Key('habit-detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月度打卡表'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('todo-habit-month-title')),
      findsOneWidget,
      reason: '没真正弹开表的话，下面所有断言会在空树上假绿',
    );
  }

  Finder monthCells() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('todo-habit-day-'),
  );

  setUp(() {
    repo = _FakeHabitRepository(
      dailyCounts: [
        {'date': iso(dayA), 'count': 2},
        {'date': iso(dayB), 'count': 1},
      ],
    );
  });

  test('「还没到」只按日子判：今天及以下都不算，跨到明天才算（字面日期，不随今天漂移）', () {
    final today = DateTime(2026, 9, 25);
    expect(habitIsFutureDay(DateTime(2026, 9, 24), today), isFalse);
    expect(
      habitIsFutureDay(today, today),
      isFalse,
      reason: '今天必须还能补记；这条判据写宽了会把整月一起封掉',
    );
    expect(
      habitIsFutureDay(DateTime(2026, 9, 25, 23, 59), today),
      isFalse,
      reason: '同一天的时间戳不算未来',
    );
    expect(habitIsFutureDay(DateTime(2026, 9, 26), today), isTrue);
    // 月末当天：整月都已到 ⇒ 不许有一格是「还没到」。
    final endOfMonth = DateTime(2026, 9, 30);
    expect(habitIsFutureDay(endOfMonth, endOfMonth), isFalse);
    expect(
      habitIsFutureDay(DateTime(2026, 10, 1), endOfMonth),
      isTrue,
      reason: '要按整天比，不能拿 day 数字比（1 > 30 会把跨月判反）',
    );
  });

  testWidgets('详情页「...」→「月度打卡表」出表，标题点明是哪个月', (tester) async {
    await pumpHabit(tester);
    expect(find.text('月度打卡表'), findsNothing);

    await openMonthSheet(tester);

    expect(
      find.textContaining('${now.year} 年 ${now.month} 月'),
      findsOneWidget,
      reason: '源页 `:70`-`:90` 一节讲的是「当月打卡情况」，标题要说是哪个月',
    );
  });

  testWidgets('当月每一天都占一格：有记录的按后端给的 ISO 串对上次数，没记录的也在', (tester) async {
    await pumpHabit(tester);
    await openMonthSheet(tester);

    // 精确到当月天数（不是「至少 28」）：多排、少排都要红。
    expect(monthCells(), findsNWidgets(monthDayCount));

    // 后端回的是 yyyy-MM-dd ⇒ 客户端 key 必须与它同形，否则次数落不到格子上。
    expect(
      find.descendant(
        of: find.byKey(ValueKey(cellKey(dayA))),
        matching: find.text('2'),
      ),
      findsOneWidget,
      reason: 'dailyCounts 的日期串解析不上就显示不出次数',
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey(cellKey(dayB))),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    // 没记录的日子也占位并明确说未打卡（当月末号一定没有记录）。
    expect(find.byKey(ValueKey(cellKey(lastDay))), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey(cellKey(lastDay))),
        matching: find.text('${lastDay.day}'),
      ),
      findsOneWidget,
      reason: '空格子显示的是几号，不是次数',
    );
  });

  testWidgets('点某一格就是补记该日：checkIn 收到那一天的 date，并刷打卡概览', (tester) async {
    await pumpHabit(tester);
    await openMonthSheet(tester);
    final overviewBefore = repo.overviewStatsCalls;

    await tester.tap(find.byKey(ValueKey(cellKey(dayB))));
    await tester.pumpAndSettle();

    expect(repo.lastCheckInHabitId, 7);
    expect(
      repo.lastCheckInDate,
      isNotNull,
      reason: '补记必须把日期传下去（develop 上唯一调用方从不传）',
    );
    expect(iso(repo.lastCheckInDate!), iso(dayB));
    expect(repo.statsCalls, greaterThan(1), reason: '补记后要重新拉当月数据');
    expect(
      repo.overviewStatsCalls,
      greaterThan(overviewBefore),
      reason: '补记会改变累计值 ⇒ 刷的是「打卡概览」那条通道，不是月表自己的',
    );
  });

  testWidgets('补记失败：已渲染的格子不丢，并在表内给可见错误', (tester) async {
    repo.failCheckIn = true;
    await pumpHabit(tester);
    await openMonthSheet(tester);

    await tester.tap(find.byKey(ValueKey(cellKey(dayB))));
    await tester.pumpAndSettle();

    expect(find.text('月度打卡表'), findsOneWidget);
    expect(monthCells(), findsNWidgets(monthDayCount));
    expect(
      find.descendant(
        of: find.byKey(ValueKey(cellKey(dayA))),
        matching: find.text('2'),
      ),
      findsOneWidget,
      reason: '失败不能把已经加载出来的当月数据清空',
    );
    expect(find.textContaining('补记失败'), findsOneWidget);
  });

  testWidgets('每格是读屏可够到的按钮，announce 出几号与当日次数', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpHabit(tester);
      await openMonthSheet(tester);

      final node = tester.getSemantics(find.byKey(ValueKey(cellKey(dayA))));
      expect(
        node.label,
        '${dayA.day} 日，打卡 2 次',
        reason: '格子里可见的那个数字不能并进同一个节点（实测会多出 "\\n2"，读屏重复播报）',
      );
      expect(
        node.flagsCollection.isButton,
        isTrue,
        reason: '摘掉生产里的 button: true 这条必须红（InkWell 自己不给 isButton）',
      );
      // 这里原来还断了一句 `lastDay` 的标签是「N 日，未打卡」——那钉的是缺陷
      // （月末之外的日子里 lastDay 是**还没到**的一天，被读成了「没打卡」）。
      // 逐格的档位判定已由下面那条整月用例穷举，留两处只会互相打脸。
    } finally {
      handle.dispose();
    }
  });

  testWidgets('整月逐格按「日子到没到」分档：已到才谈打卡/未打卡，没到只说还没到', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpHabit(tester);
      await openMonthSheet(tester);

      final today = DateTime(now.year, now.month, now.day);
      for (var i = 1; i <= monthDayCount; i++) {
        final day = DateTime(now.year, now.month, i);
        final node = tester.getSemantics(find.byKey(ValueKey(cellKey(day))));
        // 判据在测试里自己算，不调生产的那个 helper ⇒ 生产把「已到」判成「没到」时这里必红。
        final arrived = !day.isAfter(today);
        final seeded = day == dayA ? 2 : (day == dayB ? 1 : 0);
        expect(
          node.label,
          arrived
              ? (seeded > 0 ? '${day.day} 日，打卡 $seeded 次' : '${day.day} 日，未打卡')
              : '${day.day} 日，还没到',
          reason: '${day.day} 日这格判错了档（今天=$today）',
        );
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('点还没到的格子：不发补记请求，但提示要看得见（不许静默早退）', (tester) async {
    await pumpHabit(tester);
    await openMonthSheet(tester);

    if (now.day == monthDayCount) {
      // 月末当天：整月都已到 ⇒ 一格「还没到」都不许出现（反向对照，别留静默通道）。
      expect(find.text('这个日期还没到，不能补记'), findsNothing);
      expect(monthCells(), findsNWidgets(monthDayCount));
      return;
    }
    final futureDay = DateTime(now.year, now.month, now.day + 1);
    final statsBefore = repo.statsCalls;

    await tester.tap(find.byKey(ValueKey(cellKey(futureDay))));
    await tester.pumpAndSettle();

    expect(
      repo.checkInCalls,
      0,
      reason: 'BE getStats 的窗口是 to = now ⇒ 补到未来日的记录永远看不见',
    );
    expect(repo.statsCalls, statsBefore, reason: '没补记就不该再刷一次当月数据');
    expect(
      find.text('这个日期还没到，不能补记'),
      findsOneWidget,
      reason: '提示必须落在弹层可见区，同 Issue #292 的口径',
    );
    expect(
      find.byKey(const ValueKey('todo-habit-month-notice')),
      findsOneWidget,
      reason: '提示走自己的槽位：借用错误条等于承认这一发本该成功',
    );
    expect(find.byKey(const ValueKey('todo-habit-month-error')), findsNothing);
    expect(find.textContaining('补记失败'), findsNothing, reason: '这不是失败，别借用错误条');
  });

  testWidgets('今天照样能补记：提示不挡已到的日子，也不残留到下一次操作', (tester) async {
    final today = DateTime(now.year, now.month, now.day);
    await pumpHabit(tester);
    await openMonthSheet(tester);

    if (now.day < monthDayCount) {
      await tester.tap(
        find.byKey(
          ValueKey(cellKey(DateTime(now.year, now.month, now.day + 1))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('这个日期还没到，不能补记'), findsOneWidget);
    }

    await tester.tap(find.byKey(ValueKey(cellKey(today))));
    await tester.pumpAndSettle();

    expect(repo.checkInCalls, 1, reason: '今天不是未来日，必须还能补记');
    expect(iso(repo.lastCheckInDate!), iso(today));
    expect(find.text('这个日期还没到，不能补记'), findsNothing, reason: '上一次的提示不能盖住这一次的结果');
  });

  testWidgets('320px + 1.3 倍字号：提示落在可见区且不溢出', (tester) async {
    await pumpHabit(tester, surface: const Size(320, 720), textScale: 1.3);
    await openMonthSheet(tester);

    if (now.day == monthDayCount) {
      expect(tester.takeException(), isNull);
      expect(monthCells(), findsNWidgets(monthDayCount));
      return;
    }
    await tester.tap(
      find.byKey(ValueKey(cellKey(DateTime(now.year, now.month, now.day + 1)))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('这个日期还没到，不能补记'), findsOneWidget);
    expect(monthCells(), findsNWidgets(monthDayCount));
  });

  testWidgets('1.3 倍字号真的落在弹层自己的 context 上', (tester) async {
    await pumpHabit(tester, textScale: 1.3);
    await openMonthSheet(tester);

    final scaler = MediaQuery.textScalerOf(tester.element(find.text('月度打卡表')));
    expect(
      scaler.scale(10),
      closeTo(13, 0.001),
      reason: '档位只包 home: 时弹层拿到的是 1.0，这条会红',
    );
  });

  testWidgets('320px + 1.3 倍字号下当月格子仍全部渲染且不溢出', (tester) async {
    await pumpHabit(tester, surface: const Size(320, 720), textScale: 1.3);
    await openMonthSheet(tester);

    expect(tester.takeException(), isNull);
    expect(monthCells(), findsNWidgets(monthDayCount));
  });

  testWidgets('连点两格：先发后到的旧回包不覆盖新数据', (tester) async {
    await pumpHabit(tester);
    await openMonthSheet(tester);

    // 第 2、3 次 stats 分别挂起，回包内容不同：旧包说 1 号打了 9 次，新包说 3 次。
    repo.queuedCounts
      ..add([
        {'date': iso(dayA), 'count': 9},
        {'date': iso(dayB), 'count': 1},
      ])
      ..add([
        {'date': iso(dayA), 'count': 3},
        {'date': iso(dayB), 'count': 1},
      ]);
    repo.gates
      ..add(Completer<void>())
      ..add(Completer<void>());

    await tester.tap(find.byKey(ValueKey(cellKey(dayA))));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(cellKey(dayB))));
    await tester.pump();
    expect(repo.statsCalls, 3, reason: '两次补记各触发一次刷新且都还挂着，竞态才真的成立');

    repo.gates[1].complete(); // 后发的先回
    await tester.pump();
    repo.gates[0].complete(); // 先发的后回 ⇒ 必须被丢弃
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ValueKey(cellKey(dayA))),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey(cellKey(dayA))),
        matching: find.text('9'),
      ),
      findsNothing,
      reason: '过期响应不得覆盖新响应',
    );
  });

  // 第 72 轮复核 D2：PR 正文原来写「下一次操作前清场，不残留」，那对顺序操作成立、
  // 对下面这条例外说过头。这条用例把真实行为钉成设计：两条消息各说各的事，不互相顶掉。
  testWidgets('提示与错误各占一条：先前那次刷新的失败，不顶掉刚给的「还没到」提示', (tester) async {
    if (now.day == monthDayCount) {
      // 月末没有未来日可点 ⇒ 这条测不了，显式说明而不是静默通过。
      markTestSkipped('月末当天没有可点的未来格，这条例外路径不存在');
      return;
    }
    await pumpHabit(tester);
    await openMonthSheet(tester);
    final futureDay = DateTime(now.year, now.month, now.day + 1);
    repo
      ..failStats = true
      ..queuedCounts.add(<Map<String, dynamic>>[])
      ..gates.add(Completer<void>());

    // 先点一个**已到**的日子：补记成功 ⇒ 触发一次重拉，而这次重拉挂在闸门上还没回。
    await tester.tap(find.byKey(ValueKey(cellKey(dayA))));
    await tester.pump();
    expect(repo.statsCalls, 2, reason: '补记后要重拉当月数据，且这一次还挂在闸门上');

    // 在飞期间点未来格 ⇒ 提示出现（守卫不发请求，也就不会自己把在飞的那次顶掉）。
    await tester.tap(find.byKey(ValueKey(cellKey(futureDay))));
    await tester.pump();
    expect(find.text('这个日期还没到，不能补记'), findsOneWidget);

    repo.gates[0].complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining('当月打卡情况加载失败'),
      findsOneWidget,
      reason: '在飞的那次刷新失败要可见（第 72 轮之前的口径：静默早退会被当成"没生效"）',
    );
    expect(
      find.text('这个日期还没到，不能补记'),
      findsOneWidget,
      reason: '错误说的是"上一次刷新失败"，提示说的是"这一次点按被拒"，两件事不该互相顶掉',
    );
    expect(monthCells(), findsNWidgets(monthDayCount), reason: '失败后当月格子仍要在');
  });

  testWidgets('320px + 1.3 倍字号下提示与错误同时可见：不溢出', (tester) async {
    if (now.day == monthDayCount) {
      markTestSkipped('月末当天没有可点的未来格，这条例外路径不存在');
      return;
    }
    await pumpHabit(tester, surface: const Size(320, 720), textScale: 1.3);
    await openMonthSheet(tester);
    final futureDay = DateTime(now.year, now.month, now.day + 1);
    repo
      ..failStats = true
      ..queuedCounts.add(<Map<String, dynamic>>[])
      ..gates.add(Completer<void>());

    await tester.tap(find.byKey(ValueKey(cellKey(dayA))));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(cellKey(futureDay))));
    await tester.pump();
    repo.gates[0].complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 一个可见消息条都不许被挤掉：同时两条时布局仍然容得下（容不下就是真缺陷，
    // 那时该改的是"同屏"这个决定，而不是把这条断言放宽）。
    expect(tester.takeException(), isNull);
    expect(find.textContaining('当月打卡情况加载失败'), findsOneWidget);
    expect(find.text('这个日期还没到，不能补记'), findsOneWidget);
  });
}

class _FakeHabitRepository implements HabitRepository {
  _FakeHabitRepository({required this.dailyCounts});

  List<Map<String, dynamic>> dailyCounts;
  bool failCheckIn = false;

  /// 与 `gates` 配套：放行闸门后让这一次 `stats` 抛错（第 72 轮复核 D2 用）。
  bool failStats = false;
  int statsCalls = 0;
  int overviewStatsCalls = 0;
  int checkInCalls = 0;
  int? lastCheckInHabitId;
  DateTime? lastCheckInDate;

  /// 造竞态用：第 n 次 `stats`（n ≥ 2 且 `queuedCounts` 够长）先等 `gates[n-2]`，
  /// 再回 `queuedCounts[n-2]`（n=1 是首屏加载，直接回默认可见数据）⇒ 回包顺序由测试手动放行。
  final List<Completer<void>> gates = [];
  final List<List<Map<String, dynamic>>> queuedCounts = [];

  @override
  Future<List<HabitDto>> listMine({int pageNo = 1, int pageSize = 50}) async {
    return [HabitDto(id: 7, name: '喝水')];
  }

  @override
  Future<Map<String, dynamic>> stats(
    int habitId, {
    String period = 'WEEK',
  }) async {
    // #377 的「打卡数据」卡片会在详情页额外拉一次 YEAR：竞态队列/闸门
    // 只对当月表（MONTH）成立，其它档位直接回空，不掺进 statsCalls 计数。
    if (period != 'MONTH') {
      return {'dailyCounts': const <Map<String, dynamic>>[], 'period': period};
    }
    statsCalls += 1;
    final index = statsCalls - 2;
    if (index >= 0 && index < queuedCounts.length) {
      await gates[index].future;
      if (failStats) throw StateError('故意让当月数据加载失败');
      return {'dailyCounts': queuedCounts[index], 'period': period};
    }
    return {'dailyCounts': dailyCounts, 'period': period};
  }

  @override
  Future<Map<String, dynamic>> overviewStats() async {
    overviewStatsCalls += 1;
    return {'currentStreak': 3, 'weeklyDone': 5, 'totalCheckIns': 9};
  }

  @override
  Future<int> checkIn(int habitId, {DateTime? date, int? amount}) async {
    checkInCalls += 1;
    if (failCheckIn) throw StateError('boom');
    lastCheckInHabitId = habitId;
    lastCheckInDate = date;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
