import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/features/pomodoro/pomodoro_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// Epic #708 Phase A：效率三件套的**端到端冒烟清单**（书面化）。
///
/// 与既有契约测试（pomodoro 63 / habit 11 / countdown 全家）的差别：
/// 这里每条都把「用户点下去 → 写请求真发出 → 界面真变化」三段连成
/// 一条链 —— 契约测试断各段的行为，冒烟断**链没断**。
///
/// 1. 番茄：点「开始专注」→ 计时器跳秒 → 点「完成」⇒ `/complete` 真被调；
/// 2. 习惯：列表行点「打卡」⇒ `/check-in` 真被调（发的是这行的 habitId）；
/// 3. 倒数日：新建表单提交 ⇒ `/create` 真被调。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('冒烟① 番茄：开始 → 计时跳秒 → 完成 ⇒ /complete 真被调', (tester) async {
    final api = _SmokePomodoroApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pomodoroApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PomodoroPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自由'));
    await tester.pump();
    await tester.tap(find.text('开始专注'));
    await tester.pump();
    // session 活着（冒烟的「活」证据）：计时器归零显示且「完成」可点
    expect(find.text('00:00'), findsOneWidget, reason: '会话没建立 = 链断在计时器');
    expect(find.text('完成'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(api.completeCalls, isNotEmpty, reason: '点完成没发 /complete = 链断在写侧');
  });

  testWidgets('冒烟② 习惯：列表行点「打卡」⇒ /check-in 真被调', (tester) async {
    final server = _SmokeHabitServer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitRepositoryProvider.overrideWithValue(
            HabitRepository(server.dio()),
          ),
        ],
        child: const MaterialApp(home: HabitPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('喝水'), findsOneWidget, reason: '预置习惯没上屏');
    await tester.tap(find.text('打卡'));
    await tester.pumpAndSettle();

    final checkin = server.requests.where(
      (r) => r.path.endsWith('/habit/check-in'),
    );
    expect(checkin, isNotEmpty, reason: '打卡没发 /check-in = 链断在写侧');
    expect(
      (checkin.last.data as Map)['habitId'],
      7,
      reason: '发的必须是这一行的 habitId，不是别人的',
    );
  });

  testWidgets('冒烟③ 倒数日：新建表单提交 ⇒ /create 真被调', (tester) async {
    final api = _SmokeCountdownApi([]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countdownApiProvider.overrideWithValue(api),
          countdownsProvider.overrideWith((ref) => api.list()),
        ],
        child: const MaterialApp(home: CountdownPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 空列表 ⇒ 新建入口
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('countdown-title-field')),
      '产品发布会',
    );
    await tester.tap(find.byKey(const Key('countdown-editor-save')));
    await tester.pumpAndSettle();

    expect(
      api.createCalls,
      isNotEmpty,
      reason: '保存没发 /countdown/create = 链断在写侧',
    );
    expect(api.createCalls.single, '产品发布会');
    expect(find.text('产品发布会'), findsOneWidget, reason: '新建后列表没出现新项');
  });
}

/// 只覆写冒烟链用到的两个方法的假 API。
class _SmokePomodoroApi extends PomodoroApi {
  _SmokePomodoroApi() : super(Dio());

  final List<int> completeCalls = [];

  @override
  Future<List<PomodoroPresetDto>> presets() async => const [
    PomodoroPresetDto(
      mode: 'MODE_25_5',
      label: '经典 25/5',
      focusMinutes: 25,
      breakMinutes: 5,
    ),
    PomodoroPresetDto(mode: 'FREE', label: '自由'),
  ];

  @override
  Future<PomodoroSessionDto> start({
    int? taskId,
    String mode = 'MODE_25_5',
    int? plannedMinutes,
  }) async => PomodoroSessionDto(
    id: 41,
    mode: mode,
    plannedMinutes: plannedMinutes,
    status: 'RUNNING',
    startedAt: DateTime.now(),
  );

  @override
  Future<void> complete(int id, {String? remark, DateTime? clientEndAt}) async {
    completeCalls.add(id);
  }

  @override
  Future<PomodoroStatsDto> stats({String period = 'week'}) async =>
      const PomodoroStatsDto.empty();

  @override
  Future<List<PomodoroTimelineDto>> timeline({required DateTime date}) async =>
      const [];

  @override
  Future<PomodoroSessionDto?> active() async => null;

  @override
  Future<List<PomodoroSessionDto>> page({
    String? status,
    int pageNo = 1,
    int pageSize = 20,
  }) async => const [];
}

/// 只回一个习惯 + 记录请求路径的假服务。
class _SmokeHabitServer {
  Dio dio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          if (path.endsWith('/habit/page')) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'list': [_habitJson],
                    'total': 1,
                  },
                },
              ),
            );
          }
          if (path.endsWith('/habit/check-in')) {
            return handler.resolve(
              Response(requestOptions: options, data: {'code': 0, 'data': 1}),
            );
          }
          if (path.endsWith('/habit/stats')) {
            return handler.resolve(
              Response(requestOptions: options, data: {'code': 0, 'data': []}),
            );
          }
          return handler.resolve(
            Response(requestOptions: options, data: {'code': 0, 'data': null}),
          );
        },
      ),
    );
    return dio;
  }

  final List<RequestOptions> requests = [];

  static const _habitJson = {
    'id': 7,
    'name': '喝水',
    'icon': 'water',
    'color': '#22C55E',
    'period': 1,
    'targetCount': 8,
    'sortOrder': 3,
    'archived': false,
  };
}

/// 只记 create 的假倒数日 API。
class _SmokeCountdownApi extends CountdownApi {
  _SmokeCountdownApi(this.items) : super(Dio());

  List<CountdownDto> items;
  final List<String> createCalls = [];

  @override
  Future<List<CountdownDto>> list({bool archived = false}) async {
    if (createCalls.isEmpty) return items;
    // 新建之后：模拟服务端已经落库 —— 列表出现新项。
    return [
      ...items,
      CountdownDto(
        id: 99,
        title: createCalls.last,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        daysRemaining: 30,
        style: 1,
        showAge: false,
      ),
    ];
  }

  @override
  Future<int> create({
    required String title,
    required DateTime targetDate,
    bool showAge = false,
    int style = 1,
    String? backgroundImage,
    String? color,
    String? note,
    bool noteShowInDetail = false,
  }) async {
    createCalls.add(title);
    return 99;
  }

  @override
  Future<void> update({
    required int id,
    required String title,
    required DateTime targetDate,
    required int style,
    required bool showAge,
    String? backgroundImage,
    String? color,
    String? note,
    bool noteShowInDetail = false,
  }) async {}

  @override
  Future<void> delete(int id) async {}
}
