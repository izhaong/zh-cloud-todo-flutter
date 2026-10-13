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
const _createPath = '/todo/habit/create';
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
            r.path.endsWith(_createPath) ||
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
          if (path.endsWith(_createPath)) {
            // 新建也要被"真的接住"：以前这里落到 handler.next() ⇒ 请求发不出去、
            // 走的是 catch 分支，于是「FR-5 新建带齐 7 个字段」其实是在一次失败里读的请求体。
            if (failWrites) return handler.resolve(_err(options));
            return handler.resolve(_ok(options, true));
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

/// Issue #308 那 6 条负路径都发生在**新建**这张表单上，统一从这里进弹层。
/// 返回假服务，让每条用例都能查「到底发没发写请求」——不这么判就成了只看界面的空断言。
Future<FakeHabitServer> pumpNewHabitSheet(
  WidgetTester tester, {
  bool failWrites = false,
}) async {
  final server = FakeHabitServer(failWrites: failWrites);
  await pumpHabits(tester, server: server);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('habit-editor-sheet')),
    findsOneWidget,
    reason: '前提不成立：新建表单没打开，后面每条断言都是在空转',
  );
  return server;
}

/// 弹层里的东西一律按 surface 限定后再找（`inSurface` 的既有口径）。
Finder sheetChild(Finder child) =>
    inSurface(const Key('habit-editor-sheet'), child);

Finder sheetField(String keyName) =>
    sheetChild(find.byKey(Key('habit-editor-$keyName')));

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
      'recordType': 1,
      'journalEnabled': true,
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
    expect(find.text('月度打卡表'), findsOneWidget);
    expect(
      find.text('归档'),
      findsNothing,
      reason:
          'PUT /habit/{id}/archived 只在未合并的 zh-cloud-service!276 里，提前接就是线上 404',
    );
  });

  testWidgets('详情页「...」→「月度打卡表」开的是当月表（嘀嗒《02-更好地完成习惯》:77/:84）', (tester) async {
    await pumpHabits(tester);
    await tester.tap(find.text('喝水'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('habit-detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月度打卡表'));
    await tester.pumpAndSettle();

    // 按弹层自己的 key 定位，别用裸文案：详情页宿主上也可能出现同样的字。
    expect(
      find.byKey(const ValueKey('todo-habit-month-title')),
      findsOneWidget,
      reason: '入口没接到 showHabitMonthSheet 时，这里找不到月度表的标题',
    );
    expect(
      find.byKey(const ValueKey('todo-habit-month-grid')),
      findsOneWidget,
      reason: '标题在而表不在 ⇒ 只弹了壳，没渲染当月格',
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
    await tester.scrollUntilVisible(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
      200,
      scrollable: inSurface(
        const Key('habit-editor-sheet'),
        find.byType(Scrollable),
      ).first,
    );
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
    await tester.scrollUntilVisible(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
      200,
      scrollable: inSurface(
        const Key('habit-editor-sheet'),
        find.byType(Scrollable),
      ).first,
    );
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
    // specs/132 后保存键在弹层可视区外，tap 前先滚到它。
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: inSurface(
        const Key('habit-editor-sheet'),
        find.byType(Scrollable),
      ).first,
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

  testWidgets('读屏：「...」菜单三项各自念得出且是按钮（复核 F-3 补的钉）', (tester) async {
    // 复核第 1 轮 F-3：换宿主之后菜单是**新表面**，全仓当时没有任何一条对它三项的语义断言
    // （只钉了触发器「更多操作」）。按第 43 轮给格子补 isButton + label 的同一标准补这一钉。
    final handle = tester.ensureSemantics();
    try {
      await pumpHabits(tester);
      await tester.tap(find.text('喝水'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('habit-detail-menu')));
      await tester.pumpAndSettle();

      for (final label in const ['月度打卡表', '编辑', '删除']) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: '菜单项「$label」念不出来，读屏用户只能靠猜',
        );
        expect(
          tester.getSemantics(find.text(label)).flagsCollection.isButton,
          isTrue,
          reason: '「$label」要带按钮标志，否则读屏不知道它能按',
        );
      }
    } finally {
      handle.dispose();
    }
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
    await tester.scrollUntilVisible(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
      200,
      scrollable: inSurface(
        const Key('habit-editor-sheet'),
        find.byType(Scrollable),
      ).first,
    );
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
        'recordType': 1,
        'journalEnabled': true,
      },
    );
    // 请求体对不等于"这一面走得通"：还得看得见成功。基线（`9032005`，本文件 18 条）上
    // 把 `/habit/create` 的接住抽掉照样全绿 —— create 落进 catch 分支也会留下同样的请求体，
    // 而旧用例只断言请求体。补上下面两条后，同一处抽掉（探针 P0）就变红：
    // `Actual: Found 1 widget with key <'habit-editor-sheet'>`。
    expect(
      find.byKey(const Key('habit-editor-sheet')),
      findsNothing,
      reason: '创建成功却不收弹层 ⇒ 用户以为没保存上，会再点一次写两条习惯',
    );
    expect(
      find.textContaining('保存失败'),
      findsNothing,
      reason: '假服务已回 200，仍显示失败说明这条用例分不出成功与失败',
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
    await tester.scrollUntilVisible(
      inSurface(const Key('habit-editor-sheet'), find.text('保存')),
      200,
      scrollable: inSurface(
        const Key('habit-editor-sheet'),
        find.byType(Scrollable),
      ).first,
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

  // ===== Issue #308：从关掉的 !295 转出来的 6 条负路径，逐条在 develop 上补回 =====
  // 已有正路径与「名称留空」两条在上方，这里不重复写。

  for (final input in const ['0', '-3', '', 'abc']) {
    testWidgets('目标填「$input」：原因落在字段上并在弹层里可见，且一条写请求都不发', (tester) async {
      final server = await pumpNewHabitSheet(tester);
      await tester.enterText(sheetField('name'), '晨跑');
      await tester.enterText(sheetField('target'), input);
      // specs/132 后表单多一个「打卡日志」开关 ⇒ 保存键在弹层可视区外，
      // tap 前先滚到它（弹层自滚动；Too many elements 用 first 取主滚动）。
      await tester.scrollUntilVisible(
        sheetChild(find.text('保存')),
        200,
        scrollable: sheetChild(find.byType(Scrollable)).first,
      );
      await tester.tap(sheetChild(find.text('保存')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(sheetField('target'));
      expect(field.decoration?.errorText, '目标至少为 1');
      expect(
        sheetChild(find.text('目标至少为 1')),
        findsOneWidget,
        reason: '提示必须在弹层自己的子树里：根 ScaffoldMessenger 会被模态路由盖住',
      );
      expect(server.writeRequests, isEmpty, reason: '校验没过就不该写库（create 也算写请求）');
      expect(
        find.byKey(const Key('habit-editor-sheet')),
        findsOneWidget,
        reason: '校验没过不该把用户正在填的表单关掉',
      );
    });
  }

  testWidgets('新建失败：名称、频率、目标全都留着，不用重填', (tester) async {
    final server = await pumpNewHabitSheet(tester, failWrites: true);
    await tester.enterText(sheetField('name'), '晨跑');
    await tester.tap(find.byKey(const Key('habit-editor-period-2')));
    await tester.enterText(sheetField('target'), '5');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      sheetChild(find.text('保存')),
      200,
      scrollable: sheetChild(find.byType(Scrollable)).first,
);
    await tester.tap(sheetChild(find.text('保存')));
    await tester.pumpAndSettle();

    expect(
      server.writeRequests.where((r) => r.path.endsWith(_createPath)),
      hasLength(1),
      reason: '前提：这一次真的把 create 发出去了（否则"失败后保留输入"是空断言）',
    );
    expect(
      sheetChild(find.textContaining('保存失败')),
      findsOneWidget,
      reason: '失败必须在弹层内可见，不能悄悄回到列表',
    );
    expect(
      tester.widget<TextField>(sheetField('name')).controller!.text,
      '晨跑',
      reason: '失败后清空输入等于要用户重填一遍',
    );
    expect(
      tester.widget<TextField>(sheetField('target')).controller!.text,
      '5',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('habit-editor-period-2')))
          .selected,
      isTrue,
      reason: '频率档位的回显要用 selected 判，ChoiceChip 的文案本来就常驻',
    );
    expect(
      find.byKey(const Key('habit-editor-sheet')),
      findsOneWidget,
      reason: '失败不该关闭表单',
    );
  });

  testWidgets('读屏：「频率」组名与「目标」字段各自念得出来（不是只有图标/色块有标签）', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpNewHabitSheet(tester);
      expect(
        sheetChild(find.bySemanticsLabel('频率')),
        findsOneWidget,
        reason: '三档 chip 只有文案，组名念不出来就不知道这一组在选什么',
      );
      expect(
        sheetChild(find.bySemanticsLabel('目标')),
        findsOneWidget,
        reason: '数字输入框没有可读标签时，读屏只会念"编辑框"',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('新建默认值是「每天 / 1 次」，且不带上一条习惯的回填', (tester) async {
    await pumpNewHabitSheet(tester);
    for (final period in const [1, 2, 3]) {
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(Key('habit-editor-period-$period')))
            .selected,
        period == 1,
        reason: '只有「每天」该选中；按 selected 判才不会被常驻文案蒙过去',
      );
    }
    expect(
      tester.widget<TextField>(sheetField('target')).controller!.text,
      '1',
    );
    expect(tester.widget<TextField>(sheetField('name')).controller!.text, '');
  });

  testWidgets('320px + 1.3 倍字体：新建表单（含字数计数器）排得下且用自己的档位', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpNewHabitSheet(tester);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('habit-editor-sheet'))),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '弹层是新表面，档位必须在它自己的 context 上复检（上方那条编辑用例不覆盖新建态）',
    );
    // 这一档下实测 maxScrollExtent=0（内容 559.6 视口 / 「保存」底 692 ≤ 弹层底 704）
    // ⇒ 表单本来就排得下，不需要滚；drag 与下面那条条件断言留着，是为了让"哪天加高到
    // 需要滚"时这条用例仍然在检验可达性，而不是悄悄退化成只读一屏。
    // drag 的目标只能是那张 sheet 自己：`habit-editor-sheet` 这个 key 就打在
    // `SingleChildScrollView`（`habit_editor.dart:158`）上，而
    // `find.descendant(of: <该 key>, matching: SingleChildScrollView)` 永远 findsNothing
    // —— descendant 不含起点自身，第一次跑就是这样红的。
    final sheet = find.byKey(const Key('habit-editor-sheet'));
    final save = sheetChild(find.text('保存'));
    // 取"这一张 sheet 自己的"滚动位置：不能按类型在 sheet 子树里找 Scrollable ——
    // 每个 TextField 内部也各有一个，`find.descendant` 会 "Too many elements"。
    // 从「保存」往上取最近祖先，恰好是 sheet 那张。
    final position = Scrollable.of(tester.element(save)).position;
    final maxScrollExtent = position.maxScrollExtent;
    final saveHitBefore = tester.any(save.hitTestable());
    await tester.drag(sheet, const Offset(0, -400));
    await tester.pumpAndSettle();

    final saveHitAfter = tester.any(save.hitTestable());
    debugPrint(
      'NEW_SHEET_320_1_3 maxScrollExtent=$maxScrollExtent '
      'pixels=${position.pixels} viewport=${position.viewportDimension} '
      'hitTestable(保存): $saveHitBefore→$saveHitAfter '
      'bottom=${tester.getRect(save).bottom} sheetBottom=${tester.getRect(sheet).bottom}',
    );
    // 两条分支都要能证伪：内容超出视口时「滚一格都没发生」= drag 打空了，
    // 后面那条可达断言就成了假的绿灯。
    if (maxScrollExtent > 0) {
      expect(
        position.pixels,
        greaterThan(0),
        reason: 'maxScrollExtent=$maxScrollExtent 却没滚动 ⇒ 这一档下的可达性没被真正检验',
      );
    }
    expect(
      saveHitAfter,
      isTrue,
      reason: '「保存」点不到就建不出习惯（320px + 1.3 下这条路径必须走得通）',
    );
    expect(tester.takeException(), isNull, reason: '新建表单在 320px + 1.3 下溢出');
    // 用例名承诺了「含字数计数器」，就得把计数器钉住。探针 PJ 实测：去掉 `maxLength: 64`
    // 会让计数器整行消失（视口 559.6→534.6），而补这两句之前本条用例仍然全绿。
    // 原先这里写的对照组是 `find.text('目标至少为 1')` findsNothing —— 本条用例根本不点
    // 「保存」，校验错误不可能出现，那句永远为真，已删。
    expect(
      tester.widget<TextField>(sheetField('name')).maxLength,
      64,
      reason: 'maxLength 是计数器的来源，不钉住等于没测这一档下的计数器',
    );
    expect(
      sheetChild(find.textContaining('/64')),
      findsOneWidget,
      reason: '计数器必须真的画在弹层里，才算"这一档下含字数计数器"那一格',
    );
  });

  test('ApiConfig.todoPrefix 仍指向 /app-api/todo（本文件的断言按该前缀写死）', () {
    expect(ApiConfig.todoPrefix, '/app-api/todo');
  });
}