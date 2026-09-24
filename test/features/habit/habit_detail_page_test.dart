import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_config.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《05-习惯打卡/01-开始坚持一个习惯》第 58 行（移动端原文）：
/// 「点击习惯进入详情页，点击右上角「...」，可进行编辑、开始专注、分享、归档或删除等操作。」
/// 本文件钉的就是这条主路的「编辑」「删除」两半。
const _pagePath = '/todo/habit/page';
const _updatePath = '/todo/habit/update';
const _deletePath = '/todo/habit/delete';
const _checkInPath = '/todo/habit/check-in';
const _statsPath = '/todo/habit/stats';

/// 一个真的会改状态的假服务：`/page` 返回当前状态、`/update` 合并、`/delete` 移除。
/// 不这么做的假（返回固定 JSON）会让「列表里少了一条」这类断言变成空转。
class FakeHabitServer {
  FakeHabitServer({Map<String, dynamic>? habit, this.failWrites = false})
    : habit = habit ?? _habitJson();

  final Map<String, dynamic> habit;
  final bool failWrites;
  final List<RequestOptions> requests = [];

  List<RequestOptions> get writeRequests => requests
      .where(
        (r) =>
            r.path.endsWith(_updatePath) ||
            r.path.endsWith(_deletePath) ||
            r.path.endsWith(_checkInPath),
      )
      .toList();

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
                'list': _deleted ? [] : [Map<String, dynamic>.from(habit)],
                'total': _deleted ? 0 : 1,
              }),
            );
          }
          if (path.endsWith(_updatePath)) {
            if (failWrites) return handler.resolve(_err(options));
            final body = Map<String, dynamic>.from(options.data as Map);
            habit.addAll(body);
            return handler.resolve(_ok(options, true));
          }
          if (path.endsWith(_deletePath)) {
            if (failWrites) return handler.resolve(_err(options));
            _deleted = true;
            return handler.resolve(_ok(options, true));
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
          if (path.endsWith(_checkInPath)) {
            return handler.resolve(_ok(options, 1));
          }
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  bool _deleted = false;
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
    data: {'code': 500, 'data': null, 'msg': '服务端写失败'},
  );
}

/// 2026-09-23 09:00 本地时区——服务端 `reminderAt` 走 epoch 毫秒（见 spec FR-6）。
final _reminderAt = DateTime(2026, 9, 23, 9, 0);

Map<String, dynamic> _habitJson() => {
  'id': 7,
  'name': '喝水',
  'icon': 'water',
  'color': '#22C55E',
  'period': 1,
  'targetCount': 8,
  'reminderAt': _reminderAt.millisecondsSinceEpoch,
  'sortOrder': 3,
  'archived': false,
};

Future<FakeHabitServer> pumpHabits(
  WidgetTester tester, {
  FakeHabitServer? server,
  bool failWrites = false,
  HabitRepository? repository,
}) async {
  final fake = server ?? FakeHabitServer(failWrites: failWrites);
  // 提醒档位要在 push 路由 / 弹层自己的 context 上自检，故尺寸由调用方设置。
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitRepositoryProvider.overrideWithValue(
          repository ?? HabitRepository(fake.dio()),
        ),
      ],
      child: const MaterialApp(home: HabitPage()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// 弹层 / 对话框是新表面，挂在根 navigator 上；按 key 定位再取子树，
/// 避免「宿主页面里恰好也有这四个字」造成的假命中。
Finder inSurface(Key key, Finder child) {
  return find.descendant(of: find.byKey(key), matching: child);
}

Future<void> openEditorFromDetail(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('habit-detail-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑'));
  await tester.pumpAndSettle();
}

void main() {
  test('HabitDto 解析契约已有的 icon / reminderAt / sortOrder（epoch 毫秒）', () {
    final dto = HabitDto.fromJson(_habitJson());
    expect(dto.icon, 'water');
    expect(dto.reminderAt, _reminderAt);
    expect(dto.sortOrder, 3);
  });

  test('checkIn 与 update 的 LocalDateTime 按 epoch 毫秒上送，不发 ISO 字符串', () async {
    final server = FakeHabitServer();
    final repo = HabitRepository(server.dio());
    await repo.checkIn(7, date: DateTime(2026, 9, 23, 8, 0, 0));
    final checkedAt =
        (server.last(_checkInPath).data as Map)['checkedAt'] as Object?;
    expect(
      checkedAt,
      DateTime(2026, 9, 23, 8).millisecondsSinceEpoch,
      reason:
          '服务端 TimestampLocalDateTimeDeserializer 用 getValueAsLong() 读，'
          'ISO 字符串不是契约形状',
    );
    expect(checkedAt, isA<int>());
  });

  test('update 打 PUT /habit/update，body 含 id + 可编辑字段 + 原 sortOrder', () async {
    final server = FakeHabitServer();
    final repo = HabitRepository(server.dio());
    await repo.update(
      id: 7,
      name: '每天喝水',
      icon: 'glass',
      color: '#0EA5E9',
      period: 2,
      targetCount: 21,
      reminderAt: _reminderAt,
      sortOrder: 3,
    );
    final request = server.last(_updatePath);
    expect(request.method, 'PUT');
    expect(Map<String, dynamic>.from(request.data as Map), {
      'id': 7,
      'name': '每天喝水',
      'icon': 'glass',
      'color': '#0EA5E9',
      'period': 2,
      'targetCount': 21,
      'reminderAt': _reminderAt.millisecondsSinceEpoch,
      'sortOrder': 3,
    });
  });

  test('delete 打 DELETE /habit/delete 且 id 走 queryParameters', () async {
    final server = FakeHabitServer();
    final repo = HabitRepository(server.dio());
    await repo.delete(7);
    final request = server.last(_deletePath);
    expect(request.method, 'DELETE');
    expect(request.queryParameters['id'], 7);
  });

  testWidgets('点击习惯卡片进入详情页：标题是习惯名，右上角有「...」', (tester) async {
    await pumpHabits(tester);
    expect(find.byKey(const Key('habit-detail-menu')), findsNothing);

    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('habit-detail-page')), findsOneWidget);
    expect(find.text('喝水'), findsWidgets);
    expect(find.byKey(const Key('habit-detail-menu')), findsOneWidget);
  });

  testWidgets('「...」恰好含「编辑」「删除」，不含「归档」（归档契约未合并）', (tester) async {
    await pumpHabits(tester);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('habit-detail-menu')));
    await tester.pumpAndSettle();

    // 菜单项只在弹开时存在于树上，所以「找到了」本身就是「展开后确实有这一项」。
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(
      find.text('归档'),
      findsNothing,
      reason:
          'PUT /habit/{id}/archived 只在未合并的 zh-cloud-service!276 里，提前接就是线上 404',
    );
  });

  testWidgets('编辑弹层回填当前值，保存后 PUT body 逐键正确且列表统计跟着刷新', (tester) async {
    final server = FakeHabitServer();
    await pumpHabits(tester, server: server);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    await openEditorFromDetail(tester);

    expect(find.byKey(const Key('habit-editor-sheet')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            inSurface(
              const Key('habit-editor-sheet'),
              find.byKey(const Key('habit-editor-name')),
            ),
          )
          .controller!
          .text,
      '喝水',
      reason: '编辑不回填等于让用户重打一遍',
    );

    await tester.enterText(
      inSurface(
        const Key('habit-editor-sheet'),
        find.byKey(const Key('habit-editor-name')),
      ),
      '喝水 8 杯',
    );
    await tester.tap(find.byKey(const Key('habit-editor-period-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
    );
    await tester.pumpAndSettle();

    final body = Map<String, dynamic>.from(
      server.last(_updatePath).data as Map,
    );
    expect(body['id'], 7);
    expect(body['name'], '喝水 8 杯');
    expect(body['period'], 2);
    expect(body['targetCount'], 8, reason: '未改动的目标必须原样回传，不能被重置成默认 1');
    expect(body['icon'], 'water');
    expect(body['color'], '#22C55E');
    expect(body['sortOrder'], 3, reason: 'UI 不暴露排序 ⇒ 编辑不能顺手丢掉 sortOrder');
    expect(
      body['reminderAt'],
      _reminderAt.millisecondsSinceEpoch,
      reason: '未改动的提示不能被发成 null：契约 NOT_NULL 更新策略下 null 会被静默丢弃',
    );
    expect(find.byKey(const Key('habit-editor-sheet')), findsNothing);
  });

  testWidgets('删除：先按嘀嗒措辞二次确认，确认后发 DELETE 并从列表移除', (tester) async {
    final server = FakeHabitServer();
    await pumpHabits(tester, server: server);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('habit-detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).content,
      isNotNull,
    );
    expect(
      find.textContaining('永久移除'),
      findsOneWidget,
      reason: '嘀嗒《02-更好地完成习惯》:122「习惯将被永久移除，所有打卡记录也会被清空，无法恢复」',
    );

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(server.last(_deletePath).queryParameters['id'], 7);
    expect(find.text('喝水'), findsNothing, reason: '删除后列表还在原地显示，等于没告诉用户已经没了');
  });

  testWidgets('取消删除确认 ⇒ 一个写请求都不发', (tester) async {
    final server = FakeHabitServer();
    await pumpHabits(tester, server: server);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('habit-detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(server.writeRequests, isEmpty, reason: '确认框的「取消」不是「稍后再说」，不能已经把习惯删了');
    expect(find.byKey(const Key('habit-detail-page')), findsOneWidget);
  });

  testWidgets('编辑失败：弹层不关、输入不丢、提示可见，且不 invalidate 列表', (tester) async {
    final server = FakeHabitServer(failWrites: true);
    await pumpHabits(tester, server: server);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    await openEditorFromDetail(tester);

    await tester.enterText(
      inSurface(
        const Key('habit-editor-sheet'),
        find.byKey(const Key('habit-editor-name')),
      ),
      '改一半就失败',
    );
    // 起点计数：启动时 /page 至少被列表与 overviewStats 各拉一次，写死 1 是假判据。
    final pagesBefore = server.requests
        .where((r) => r.path.endsWith(_pagePath))
        .length;
    await tester.tap(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
    );
    await tester.pumpAndSettle();

    expect(
      inSurface(const Key('habit-editor-sheet'), find.textContaining('保存失败')),
      findsOneWidget,
      reason: '挂在根 ScaffoldMessenger 上的 SnackBar 会被弹层盖住，等于没有反馈',
    );
    expect(
      tester
          .widget<TextField>(
            inSurface(
              const Key('habit-editor-sheet'),
              find.byKey(const Key('habit-editor-name')),
            ),
          )
          .controller!
          .text,
      '改一半就失败',
    );
    // 数据通道仍在：详情还在，列表侧仍拿得到旧数据。
    expect(find.byKey(const Key('habit-detail-page')), findsOneWidget);
    expect(
      server.requests.where((r) => r.path.endsWith(_pagePath)).length,
      pagesBefore,
      reason: '写失败不该顺手重拉列表，把用户已经看到的视图抖掉',
    );
  });

  testWidgets('保存在飞期间重复点保存 ⇒ 只发一次 PUT', (tester) async {
    final gate = Completer<bool>();
    final sent = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith(_updatePath)) {
              sent.add(options);
              gate.future.then((_) => handler.resolve(_ok(options, true)));
              return;
            }
            if (options.path.endsWith(_pagePath)) {
              return handler.resolve(
                _ok(options, {
                  'list': [_habitJson()],
                  'total': 1,
                }),
              );
            }
            if (options.path.endsWith(_statsPath)) {
              return handler.resolve(
                _ok(options, {
                  'continuousDays': 0,
                  'totalCheckIns': 0,
                  'dailyCounts': [],
                }),
              );
            }
            handler.next(options);
          },
        ),
      );
    await pumpHabits(tester, repository: HabitRepository(dio));
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    await openEditorFromDetail(tester);

    final save = inSurface(
      const Key('habit-editor-sheet'),
      find.widgetWithText(FilledButton, '保存'),
    );
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save);
    // 在飞期间 AppButton 的转圈是无限动画，pumpAndSettle 永远不会"settle"⇒ 只推单帧。
    await tester.pump(const Duration(milliseconds: 100));

    expect(sent, hasLength(1), reason: '早退守卫漏掉就会连着写三次同一份表单');

    gate.complete(true);
    await tester.pumpAndSettle();
  });

  testWidgets('320px + 1.3 倍字体：详情页与编辑弹层排得下，且各用自己的档位', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHabits(tester);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('habit-detail-page'))),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '档位没传到详情页自己的 context，这条用例就是在 1.0 上排版',
    );
    expect(tester.takeException(), isNull, reason: '详情页在窄屏大字体下溢出');

    await openEditorFromDetail(tester);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('habit-editor-sheet'))),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '弹层是新表面，必须复检它自己的 context',
    );
    expect(tester.takeException(), isNull, reason: '编辑弹层在 320px + 1.3 下溢出');
  });

  testWidgets('读屏：详情页「...」与颜色选项各有独立语义', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpHabits(tester);
      await tester.tap(find.text('喝水'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('更多操作'),
        findsOneWidget,
        reason: '只给一个 more_horiz 图标，读屏念不出这是什么',
      );

      await tester.tap(find.byKey(const Key('habit-detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('颜色 #22C55E'),
        findsOneWidget,
        reason: '色块只有视觉差异时必须自带可读标签',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('FR-5 新建走同一张表单，POST /habit/create 带齐 7 个字段', (tester) async {
    final server = FakeHabitServer();
    await pumpHabits(tester, server: server);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('habit-editor-sheet')),
      findsOneWidget,
      reason: '新建与编辑必须是同一张表单，否则两份表单会各自漂移',
    );
    expect(
      tester
          .widget<TextField>(
            inSurface(
              const Key('habit-editor-sheet'),
              find.byKey(const Key('habit-editor-name')),
            ),
          )
          .controller!
          .text,
      '',
      reason: '新建不能带上一条习惯的回填值',
    );

    await tester.enterText(
      inSurface(
        const Key('habit-editor-sheet'),
        find.byKey(const Key('habit-editor-name')),
      ),
      '晨跑',
    );
    await tester.tap(find.byKey(const Key('habit-editor-icon-run')));
    await tester.tap(find.byKey(const Key('habit-editor-color-#0EA5E9')));
    await tester.tap(find.byKey(const Key('habit-editor-period-2')));
    await tester.tap(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
    );
    await tester.pumpAndSettle();

    expect(
      Map<String, dynamic>.from(server.last('/todo/habit/create').data as Map),
      {
        'name': '晨跑',
        'icon': 'run',
        'color': '#0EA5E9',
        'period': 2,
        'targetCount': 1,
        'reminderAt': null,
        'sortOrder': 0,
      },
    );
  });

  testWidgets('名称留空：错误落在字段上，且不发任何写请求', (tester) async {
    final server = FakeHabitServer();
    await pumpHabits(tester, server: server);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    await openEditorFromDetail(tester);

    await tester.enterText(
      inSurface(
        const Key('habit-editor-sheet'),
        find.byKey(const Key('habit-editor-name')),
      ),
      '   ',
    );
    await tester.tap(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      inSurface(
        const Key('habit-editor-sheet'),
        find.byKey(const Key('habit-editor-name')),
      ),
    );
    expect(
      field.decoration?.errorText,
      '请填写习惯名称',
      reason: '提示落在表单底部：320px 下用户要滚回顶部才知道哪个字段错了',
    );
    expect(server.writeRequests, isEmpty);
    expect(
      find.byKey(const Key('habit-detail-page')),
      findsOneWidget,
      reason: '校验没过不该把用户已经打开的详情一起关掉',
    );
  });

  testWidgets('320px + 1.3：「...」菜单与删除确认框也各用自己的档位', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHabits(tester);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('habit-detail-menu')));
    await tester.pumpAndSettle();

    expect(
      MediaQuery.textScalerOf(tester.element(find.text('编辑'))).scale(10),
      closeTo(13, 0.001),
      reason: '菜单是独立路由，档位必须在它自己的 context 上复检',
    );
    expect(tester.takeException(), isNull, reason: '菜单在窄屏大字体下溢出');

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(AlertDialog)),
      ).scale(10),
      closeTo(13, 0.001),
    );
    expect(tester.takeException(), isNull, reason: '删除确认框在 320px + 1.3 下溢出');
  });

  test('ApiConfig.todoPrefix 仍指向 /app-api/todo（本文件的断言按该前缀写死）', () {
    expect(ApiConfig.todoPrefix, '/app-api/todo');
  });
}
