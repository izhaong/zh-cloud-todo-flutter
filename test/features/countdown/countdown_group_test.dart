import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 分组是纯读侧：条目按服务端给的 `type` 自动归到四类，不产生新的写入。
class _FakeCountdownApi extends CountdownApi {
  _FakeCountdownApi(this.all) : super(Dio());

  final List<CountdownDto> all;
  int listCalls = 0;
  bool failList = false;

  @override
  Future<List<CountdownDto>> list({bool archived = false}) async {
    listCalls++;
    if (failList) throw _businessError();
    return all.where((e) => e.archived == archived).toList();
  }
}

DioException _businessError() => DioException(
  requestOptions: RequestOptions(path: '/app-api/todo/countdown/list'),
  error: '服务不可用',
);

CountdownDto _dto(
  int id,
  String title, {
  int type = 1,
  bool archived = false,
}) => CountdownDto(
  id: id,
  title: title,
  targetDate: DateTime(2026, 12, 31),
  daysRemaining: 90,
  style: 1,
  showAge: false,
  archived: archived,
  type: type,
);

List<CountdownDto> _fourGroups() => [
  _dto(1, '倒数日甲', type: 1),
  _dto(2, '纪念日甲', type: 2),
  _dto(3, '生日甲', type: 3),
  _dto(4, '节日甲', type: 4),
  _dto(5, '倒数日乙', type: 1),
];

Future<_FakeCountdownApi> _pump(
  WidgetTester tester, {
  List<CountdownDto>? all,
  _FakeCountdownApi? withApi,
  Size surface = const Size(420, 900),
  double textScale = 1.0,
}) async {
  final api = withApi ?? _FakeCountdownApi(all ?? _fourGroups());
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [countdownApiProvider.overrideWithValue(api)],
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

Future<void> _toggleGroups(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('countdown-page-more')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(const Key('countdown-menu-groups')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('右上角「...」里有嘀嗒的「显示分组」开关', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('countdown-page-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('countdown-menu-groups')), findsOneWidget);
    expect(find.text('显示分组'), findsOneWidget);
  });

  testWidgets('未开启时列表平铺，不出现分组标题', (tester) async {
    await _pump(tester);
    expect(find.text('倒数日甲'), findsOneWidget);
    expect(find.text('纪念日甲'), findsOneWidget);
    expect(find.text('生日甲'), findsOneWidget);
    expect(find.text('节日甲'), findsOneWidget);
    expect(find.byKey(const Key('countdown-group-header-2')), findsNothing);
  });

  testWidgets('开启「显示分组」后按类型自动分组：四类都有标题且顺序固定', (tester) async {
    await _pump(tester);
    await _toggleGroups(tester);
    for (final type in [1, 2, 3, 4]) {
      expect(
        find.byKey(Key('countdown-group-header-$type')),
        findsOneWidget,
        reason: '第 $type 类缺分组标题',
      );
    }
    final ys = <int, double>{};
    for (final type in [1, 2, 3, 4]) {
      ys[type] = tester
          .getTopLeft(find.byKey(Key('countdown-group-header-$type')))
          .dy;
    }
    expect(
      ys[1]! < ys[2]! && ys[2]! < ys[3]! && ys[3]! < ys[4]!,
      isTrue,
      reason: '分组标题要按 倒数日 纪念日 生日 节日 的先后排：$ys',
    );
  });

  testWidgets('分组标题用的是嘀嗒原文的四类名', (tester) async {
    await _pump(tester);
    await _toggleGroups(tester);
    for (final label in ['倒数日', '纪念日', '生日', '节日']) {
      expect(find.text(label), findsWidgets, reason: '缺分类名 $label');
    }
  });

  testWidgets('某一类没有条目时不出现那一组的标题', (tester) async {
    await _pump(
      tester,
      all: [_dto(1, '只有倒数日', type: 1), _dto(2, '也是倒数日', type: 1)],
    );
    await _toggleGroups(tester);
    expect(find.byKey(const Key('countdown-group-header-1')), findsOneWidget);
    for (final type in [2, 3, 4]) {
      expect(
        find.byKey(Key('countdown-group-header-$type')),
        findsNothing,
        reason: '空类别 $type 不该有标题',
      );
    }
  });

  testWidgets('320 宽 + 1.3 倍字号下开关可用、分组标题在屏', (tester) async {
    await _pump(tester, surface: const Size(320, 640), textScale: 1.3);
    await _toggleGroups(tester);
    expect(find.byKey(const Key('countdown-group-header-1')), findsOneWidget);
    expect(find.text('倒数日甲'), findsOneWidget);
  });

  testWidgets('列表加载失败时不吞掉界面：给出提示而不是空白', (tester) async {
    final api = _FakeCountdownApi(_fourGroups());
    await _pump(tester, withApi: api);
    api.failList = true;
    await _toggleGroups(tester);
    expect(find.byType(CountdownPage), findsOneWidget);
    expect(api.listCalls, greaterThan(0));
  });
}
