import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《02-功能指南/05-习惯打卡/02-更好地完成习惯.md》：
/// `:77`/`:84`「点击习惯…查看当月打卡情况」、`:94`「在「月度打卡表」中点击任意日期，即可补记打卡」。
///
/// 用例只驱动已有的 `HabitPage` + 字符串 key + 可见文案，不引用新 widget 类名 ⇒
/// 未实现时是「点了没出表 / 补记没传 date」的行为红，不是编译红。
void main() {
  String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final today = DateTime.now();

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
        overrides: [
          habitRepositoryProvider.overrideWithValue(repo),
          myHabitsProvider.overrideWith(
            (ref) async => [HabitDto(id: 7, name: '喝水')],
          ),
          habitStatsProvider.overrideWith(
            (ref) async => {
              'currentStreak': 3,
              'weeklyDone': 5,
              'totalCheckIns': 9,
            },
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: const HabitPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _FakeHabitRepository(
      dailyCounts: [
        {'date': dayKey(yesterday), 'count': 2},
        {'date': dayKey(today), 'count': 1},
      ],
    );
  });

  testWidgets('点习惯行出现「月度打卡表」，标题点明是哪个月', (tester) async {
    await pumpHabit(tester);
    expect(find.text('月度打卡表'), findsNothing);

    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    expect(find.text('月度打卡表'), findsOneWidget);
    expect(
      find.textContaining('${today.year} 年 ${today.month} 月'),
      findsOneWidget,
      reason: '源页 `:72` 的措辞是「月度打卡表」，标题要说是哪个月',
    );
  });

  testWidgets('当月每一天都占一格：有记录的显示次数，没记录的也在', (tester) async {
    await pumpHabit(tester);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    // 后端给了两条 dailyCounts ⇒ 这两天的次数要渲染出来
    expect(
      find.byKey(ValueKey('todo-habit-day-${dayKey(yesterday)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('todo-habit-day-${dayKey(today)}')),
      findsOneWidget,
    );
    // 月里没记录的日子也必须在（源页 `:72`「哪一天没背够 5 页也能记录付出」的前提是看得见空日子）
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('todo-habit-day-'),
      ),
      findsAtLeastNWidgets(28),
    );
  });

  testWidgets('点某一格就是补记该日：checkIn 收到那一天的 date', (tester) async {
    await pumpHabit(tester);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('todo-habit-day-${dayKey(yesterday)}')),
    );
    await tester.pumpAndSettle();

    expect(repo.lastCheckInHabitId, 7);
    expect(repo.lastCheckInDate, isNotNull, reason: '补记必须把日期传下去（develop 上从不传）');
    expect(
      '${repo.lastCheckInDate!.year}-${repo.lastCheckInDate!.month}-${repo.lastCheckInDate!.day}',
      '${yesterday.year}-${yesterday.month}-${yesterday.day}',
    );
    expect(repo.statsCalls, greaterThan(1), reason: '补记后要重新拉当月数据');
  });

  testWidgets('补记失败：已渲染的格子不丢，并在表内给可见错误', (tester) async {
    repo.failCheckIn = true;
    await pumpHabit(tester);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('todo-habit-day-${dayKey(today)}')));
    await tester.pumpAndSettle();

    expect(find.text('月度打卡表'), findsOneWidget);
    expect(
      find.byKey(ValueKey('todo-habit-day-${dayKey(yesterday)}')),
      findsOneWidget,
      reason: '失败不能把已经加载出来的当月数据清空',
    );
    expect(find.textContaining('补记失败'), findsOneWidget);
  });

  testWidgets('每格是读屏可够到的按钮，announce 出几号与当日次数', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpHabit(tester);
      await tester.tap(find.text('喝水'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('${yesterday.day} 日.*2 次')),
        findsOneWidget,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320px + 1.3 倍字号下当月格子仍全部渲染', (tester) async {
    await pumpHabit(tester, surface: const Size(320, 720), textScale: 1.3);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('月度打卡表'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('todo-habit-day-'),
      ),
      findsAtLeastNWidgets(28),
    );
  });
}

class _FakeHabitRepository implements HabitRepository {
  _FakeHabitRepository({required this.dailyCounts});

  final List<Map<String, dynamic>> dailyCounts;
  bool failCheckIn = false;
  int statsCalls = 0;
  int? lastCheckInHabitId;
  DateTime? lastCheckInDate;

  @override
  Future<List<HabitDto>> listMine({int pageNo = 1, int pageSize = 50}) async {
    return [HabitDto(id: 7, name: '喝水')];
  }

  @override
  Future<Map<String, dynamic>> stats(
    int habitId, {
    String period = 'WEEK',
  }) async {
    statsCalls += 1;
    return {
      'currentStreak': 3,
      'continuousDays': 3,
      'totalCheckIns': 9,
      'weeklyDone': 5,
      'dailyCounts': dailyCounts,
      'period': period,
    };
  }

  @override
  Future<int> checkIn(int habitId, {DateTime? date}) async {
    if (failCheckIn) throw StateError('boom');
    lastCheckInHabitId = habitId;
    lastCheckInDate = date;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
