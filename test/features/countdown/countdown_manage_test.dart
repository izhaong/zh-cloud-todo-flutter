import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// `_unwrapData` 遇到 code!=0 抛的就是不带 type 的 DioException，
/// 失败路径要按真实异常类型测，否则测的是不存在的失败模型。
DioException _businessError() => DioException(
  requestOptions: RequestOptions(path: '/app-api/todo/countdown'),
  error: '服务不可用',
);

class _FakeCountdownApi extends CountdownApi {
  _FakeCountdownApi(this.items) : super(Dio());

  final List<CountdownDto> items;
  final List<int> deletedIds = [];
  final List<({int id, String title, int style, bool showAge})> updates = [];
  int listCalls = 0;
  bool failNextWrite = false;

  /// 非空时写请求挂起等待该 Future，用于验证同一时刻只放行一个写。
  Future<void>? writeGate;

  @override
  Future<List<CountdownDto>> list({bool archived = false}) async {
    listCalls++;
    return List.unmodifiable(items);
  }

  @override
  Future<void> update({
    required int id,
    required String title,
    required DateTime targetDate,
    required int style,
    required bool showAge,
    String? backgroundImage,
  }) async {
    await writeGate;
    if (failNextWrite) {
      failNextWrite = false;
      throw _businessError();
    }
    updates.add((id: id, title: title, style: style, showAge: showAge));
    items
      ..removeWhere((item) => item.id == id)
      ..add(
        CountdownDto(
          id: id,
          title: title,
          targetDate: targetDate,
          daysRemaining: 11,
          style: style,
          showAge: showAge,
        ),
      );
  }

  @override
  Future<void> delete(int id) async {
    await writeGate;
    if (failNextWrite) {
      failNextWrite = false;
      throw _businessError();
    }
    deletedIds.add(id);
    items.removeWhere((item) => item.id == id);
  }
}

CountdownDto _countdown({
  int id = 7,
  String title = '发布日',
  int daysRemaining = 11,
  int style = 1,
  bool showAge = false,
}) {
  return CountdownDto(
    id: id,
    title: title,
    targetDate: DateTime(2026, 8, 10),
    daysRemaining: daysRemaining,
    style: style,
    showAge: showAge,
  );
}

Future<_FakeCountdownApi> _pumpPage(
  WidgetTester tester,
  List<CountdownDto> items, {
  Size? surface,
  double textScale = 1.0,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final api = _FakeCountdownApi(items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        countdownApiProvider.overrideWithValue(api),
        countdownsProvider.overrideWith((ref) => api.list()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const CountdownPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// 把倒数日页挂在可 pop 的路由上：用于构造「写请求在途时用户离开页面」。
Future<_FakeCountdownApi> _pumpRoutedPage(
  WidgetTester tester,
  List<CountdownDto> items,
) async {
  final api = _FakeCountdownApi(items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        countdownApiProvider.overrideWithValue(api),
        countdownsProvider.overrideWith((ref) => api.list()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CountdownPage(),
                  ),
                ),
                child: const Text('open-countdown'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open-countdown'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('倒数日可进入编辑并按服务端契约提交样式与已过天数', (tester) async {
    final api = await _pumpPage(tester, [_countdown()]);

    await tester.tap(find.byKey(const Key('countdown-edit-7')));
    await tester.pumpAndSettle();
    expect(find.text('编辑倒数日'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('countdown-title-field')))
          .controller!
          .text,
      '发布日',
    );

    await tester.tap(find.byKey(const Key('countdown-style-3')));
    await tester.tap(find.byKey(const Key('countdown-show-age')));
    await tester.enterText(
      find.byKey(const Key('countdown-title-field')),
      '  发布日 v2  ',
    );
    await tester.tap(find.byKey(const Key('countdown-editor-save')));
    await tester.pumpAndSettle();

    final update = api.updates.single;
    expect(update.id, 7);
    expect(update.title, '发布日 v2');
    expect(update.style, 3);
    expect(update.showAge, isTrue);
    expect(api.listCalls, greaterThan(1));
    expect(find.text('发布日 v2'), findsOneWidget);
  });

  testWidgets('保存失败时保留当前列表并给出可重试提示', (tester) async {
    final api = await _pumpPage(tester, [_countdown()]);
    api.failNextWrite = true;

    await tester.tap(find.byKey(const Key('countdown-edit-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-style-2')));
    await tester.tap(find.byKey(const Key('countdown-editor-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('操作失败'), findsOneWidget);
    expect(api.updates, isEmpty);
    // 失败路径不得重新读取列表，原数据保持原位。
    expect(api.listCalls, 1);
    expect(find.text('发布日'), findsOneWidget);
  });

  testWidgets('删除需二次确认，取消不请求、确认才按 id 删除', (tester) async {
    final api = await _pumpPage(tester, [_countdown()]);

    await tester.tap(find.byKey(const Key('countdown-delete-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.deletedIds, isEmpty);

    await tester.tap(find.byKey(const Key('countdown-delete-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-delete-confirm')));
    await tester.pumpAndSettle();

    expect(api.deletedIds, [7]);
    expect(find.text('发布日'), findsNothing);
  });

  testWidgets('删除失败时该项仍在列表中可重试', (tester) async {
    final api = await _pumpPage(tester, [_countdown()]);
    api.failNextWrite = true;

    await tester.tap(find.byKey(const Key('countdown-delete-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('操作失败'), findsOneWidget);
    expect(api.deletedIds, isEmpty);
    expect(find.text('发布日'), findsOneWidget);
  });

  testWidgets('写请求在途时不再放行第二个写，避免旧列表覆盖新结果', (tester) async {
    final gate = Completer<void>();
    final api = await _pumpPage(tester, [
      _countdown(id: 1, title: '甲'),
      _countdown(id: 2, title: '乙'),
    ]);
    api.writeGate = gate.future;

    await tester.tap(find.byKey(const Key('countdown-edit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-editor-save')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('countdown-delete-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('countdown-delete-confirm')), findsNothing);

    // 新建入口若未闸住，用户填完保存时会被单飞闸静默丢弃，等于丢失输入。
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('新建倒数日'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(api.updates.single.id, 1);
    expect(api.deletedIds, isEmpty);
  });

  testWidgets('写成功返回时页面已离开：不刷新已卸载的列表，也不抛异常', (tester) async {
    final gate = Completer<void>();
    final api = await _pumpRoutedPage(tester, [_countdown()]);
    api.writeGate = gate.future;

    await tester.tap(find.byKey(const Key('countdown-delete-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-delete-confirm')));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('countdown-row-7')), findsNothing);
    expect(api.deletedIds, isEmpty);

    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('写失败返回时页面已离开：不把过期提示甩到用户已经离开的那一页', (tester) async {
    final gate = Completer<void>();
    final api = await _pumpRoutedPage(tester, [_countdown()]);
    api.writeGate = gate.future;
    api.failNextWrite = true;

    await tester.tap(find.byKey(const Key('countdown-delete-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-delete-confirm')));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('countdown-row-7')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 未加 mounted 守卫时，提示会投递到用户已经离开的那一页所属的 messenger。
    expect(find.textContaining('操作失败'), findsNothing);
  });

  testWidgets('过期项只在显示已过天数时呈现已过文案', (tester) async {
    await _pumpPage(tester, [
      _countdown(id: 11, title: '开放日', daysRemaining: -5, showAge: true),
      _countdown(id: 12, title: '停服日', daysRemaining: -5, showAge: false),
    ]);

    expect(find.text('已过 5 天'), findsOneWidget);
    expect(find.text('2026-8-10'), findsOneWidget);
    expect(find.textContaining('还有 -5'), findsNothing);
  });

  testWidgets('三种样式的徽标结构互不相同', (tester) async {
    await _pumpPage(tester, [
      _countdown(id: 21, title: '默认项', style: 1),
      _countdown(id: 22, title: '翻页项', style: 2),
      _countdown(id: 23, title: '圆环项', style: 3),
    ]);

    expect(
      tester.widget(find.byKey(const ValueKey('countdown-badge-21'))),
      isA<CircleAvatar>(),
    );

    final flip =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('countdown-badge-22')),
                )
                .decoration!
            as BoxDecoration;
    expect(flip.shape, BoxShape.rectangle);
    expect(flip.borderRadius, isNotNull);

    final ring =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('countdown-badge-23')),
                )
                .decoration!
            as BoxDecoration;
    expect(ring.shape, BoxShape.circle);
  });

  testWidgets('320px 与 1.3 倍字体下编辑和删除入口具备读屏语义且无溢出', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpPage(
      tester,
      [_countdown(id: 31, title: '一个比较长的倒数日名称用来验证窄屏', style: 3)],
      surface: const Size(320, 700),
      textScale: 1.3,
    );

    expect(find.bySemanticsLabel('编辑 一个比较长的倒数日名称用来验证窄屏'), findsOneWidget);
    expect(find.bySemanticsLabel('删除 一个比较长的倒数日名称用来验证窄屏'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
