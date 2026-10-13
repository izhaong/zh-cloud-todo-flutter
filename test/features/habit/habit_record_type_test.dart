import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_editor.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// FL #544：习惯「打卡方式」三档的客户端接线。
///
/// 判据源：嘀嗒《05-习惯打卡/02-更好地完成习惯.md》——
/// 自动记录（每次打卡算一次）、手动记录（打卡时可输入完成的量）、
/// 完成全部（当日有记录即完成）；设置路径「编辑-目标-打卡时」。
/// 服务端契约已落 zh-cloud-service !347（`record_type` + `amount`）。
const _pagePath = '/todo/habit/page';
const _createPath = '/todo/habit/create';
const _updatePath = '/todo/habit/update';
const _checkInPath = '/todo/habit/check-in';
const _statsPath = '/todo/habit/stats';

void main() {
  test('HabitDto 解析 recordType，缺省按自动记录（1）', () {
    expect(
      HabitDto.fromJson({'id': 7, 'name': '喝水', 'recordType': 2}).recordType,
      2,
    );
    expect(HabitDto.fromJson({'id': 7, 'name': '喝水'}).recordType, 1);
  });

  test('checkIn 手动档上送 amount，自动档不带该键', () async {
    final server = CaptureServer();
    final repo = HabitRepository(server.dio());
    await repo.checkIn(11, amount: 3);
    expect((server.last(_checkInPath).data as Map)['amount'], 3);
    server.requests.clear();
    await repo.checkIn(11);
    expect(
      (server.last(_checkInPath).data as Map).containsKey('amount'),
      isFalse,
      reason: '自动/完成全部档不该发 amount 键',
    );
  });

  testWidgets('新建习惯默认自动记录；选「手动记录」后 create 带 recordType=2', (tester) async {
    final server = CaptureServer();
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(
          HabitRepository(server.dio()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HabitPage()),
      ),
    );
    await tester.pumpAndSettle();

    // specs/132 后编辑器多一个「打卡日志」开关 ⇒ 表单加高，320x720 视口
    // 装不下保存键（tap miss）⇒ 抬高视口。
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.tap(find.byTooltip('新建习惯'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-editor-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('habit-editor-recordtype-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-editor-name')), '喝水');
    await tester.tap(find.widgetWithText(AppButton, '保存'));
    await tester.pumpAndSettle();

    expect(
      (server.last(_createPath).data as Map)['recordType'],
      2,
      reason: '选中的打卡方式要进 create 请求体',
    );
  });

  testWidgets('编辑已有习惯：三档回显，改成「完成全部」后 update 带 recordType=3', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = CaptureServer();
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(
          HabitRepository(server.dio()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showHabitEditor(
                  context,
                  habit: HabitDto(id: 7, name: '喝水', recordType: 2),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('habit-editor-recordtype-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, '保存'));
    await tester.pumpAndSettle();

    expect((server.last(_updatePath).data as Map)['recordType'], 3);
  });

  testWidgets('手动档点打卡先弹完成量，输入 3 确认后 check-in 带 amount=3', (tester) async {
    final server = CaptureServer(habits: [_habitJson(recordType: 2)]);
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(
          HabitRepository(server.dio()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HabitPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, '打卡'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-checkin-amount')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('habit-checkin-amount')), '3');
    await tester.tap(find.byKey(const Key('habit-checkin-confirm')));
    await tester.pumpAndSettle();

    final body = server.last(_checkInPath).data as Map;
    expect(body['amount'], 3);
    expect(body['habitId'], 11);
  });

  testWidgets('完成量非法（0）时确认给可见错误且不发请求', (tester) async {
    final server = CaptureServer(habits: [_habitJson(recordType: 2)]);
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(
          HabitRepository(server.dio()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HabitPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, '打卡'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-checkin-amount')), '0');
    await tester.tap(find.byKey(const Key('habit-checkin-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('完成量至少为 1'), findsOneWidget);
    expect(
      server.requests.where((r) => r.path.endsWith(_checkInPath)),
      isEmpty,
      reason: '非法完成量不许发出打卡请求',
    );
  });

  testWidgets('自动档点打卡直接完成，不弹完成量', (tester) async {
    final server = CaptureServer();
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(
          HabitRepository(server.dio()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HabitPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, '打卡'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('habit-checkin-amount')), findsNothing);
    expect(
      (server.last(_checkInPath).data as Map).containsKey('amount'),
      isFalse,
    );
  });

  testWidgets('非自动档在列表行上可读（手动记录/完成全部），自动档不显示', (tester) async {
    final server = CaptureServer(
      habits: [
        _habitJson(recordType: 2),
        _habitJson(recordType: 3, name: '早起'),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(
          HabitRepository(server.dio()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HabitPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('手动记录'), findsWidgets);
    expect(find.textContaining('完成全部'), findsWidgets);
  });
}

Map<String, dynamic> _habitJson({int recordType = 1, String name = '喝水'}) => {
  'id': 11,
  'name': name,
  'icon': 'water',
  'color': '#22C55E',
  'period': 1,
  'targetCount': 8,
  'recordType': recordType,
};

/// 真会记请求的假服务：/page 返回列表、写接口一律成功、/stats 给固定统计。
class CaptureServer {
  CaptureServer({List<Map<String, dynamic>>? habits})
    : habits = habits ?? [_habitJson()];

  final List<Map<String, dynamic>> habits;
  final List<RequestOptions> requests = [];

  RequestOptions last(String suffix) => requests.lastWhere(
    (r) => r.path.endsWith(suffix),
    orElse: () => throw StateError('没有命中 $suffix 的请求，已记录：$_paths'),
  );

  String get _paths => requests.map((r) => '${r.method} ${r.path}').join(' | ');

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
                'list': [for (final h in habits) Map<String, dynamic>.from(h)],
                'total': habits.length,
              }),
            );
          }
          if (path.endsWith(_createPath) ||
              path.endsWith(_updatePath) ||
              path.endsWith(_checkInPath)) {
            return handler.resolve(
              _ok(options, path.endsWith(_checkInPath) ? 1 : true),
            );
          }
          if (path.endsWith(_statsPath)) {
            return handler.resolve(
              _ok(options, {
                'continuousDays': 3,
                'totalCheckIns': 7,
                'dailyCounts': [
                  {'date': '2026-09-23', 'count': 1},
                ],
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
