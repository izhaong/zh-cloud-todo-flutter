import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《03-管理倒数纪念日》:204「目前只支持置顶一个倒数纪念日」由服务端在同一事务里保证，
/// 这里的替身复刻那条契约：置某一条为顶时清掉其余行。
class _FakeCountdownApi extends CountdownApi {
  _FakeCountdownApi(this.all) : super(Dio());

  final List<CountdownDto> all;
  final Map<int, bool> pinned = {};
  final List<({int id, bool pinned})> writes = [];
  bool failWrite = false;

  /// 非空时**下一次**列表请求挂在这个 completer 上，并把请求时刻的快照存进 [heldSnapshot]，
  /// 这样测试就能造出「旧请求晚于新请求返回」的真时序（上一版只有一条 gate，被 _runPin
  /// 自己的重取撞上，等于没造出时序 —— FL #453）。
  Completer<List<CountdownDto>>? holdNext;
  List<CountdownDto>? heldSnapshot;

  @override
  Future<List<CountdownDto>> list({bool archived = false}) async {
    final rows =
        all
            .where((e) => (archivedFlags[e.id] ?? false) == archived)
            .map(
              (e) => CountdownDto(
                id: e.id,
                title: e.title,
                targetDate: e.targetDate,
                daysRemaining: e.daysRemaining,
                style: e.style,
                showAge: e.showAge,
                backgroundImage: e.backgroundImage,
                archived: archivedFlags[e.id] ?? false,
                isPinned: pinned[e.id] ?? false,
              ),
            )
            .toList()
          ..sort((a, b) => (a.isPinned ? 0 : 1).compareTo(b.isPinned ? 0 : 1));
    if (holdNext != null) {
      heldSnapshot = rows;
      return holdNext!.future.then((_) => rows);
    }
    return rows;
  }

  final Map<int, bool> archivedFlags = {};

  @override
  Future<void> setPinned(int id, bool pinnedValue) async {
    if (failWrite) throw _businessError();
    writes.add((id: id, pinned: pinnedValue));
    if (pinnedValue) {
      pinned.updateAll((key, value) => false);
    }
    pinned[id] = pinnedValue;
  }

  @override
  Future<void> setArchived(int id, bool archived) async {
    archivedFlags[id] = archived;
  }
}

DioException _businessError() => DioException(
  requestOptions: RequestOptions(path: '/app-api/todo/countdown/1/pinned'),
  error: '服务不可用',
);

CountdownDto _dto(int id, String title) => CountdownDto(
  id: id,
  title: title,
  targetDate: DateTime(2026, 12, 31),
  daysRemaining: 90,
  style: 1,
  showAge: false,
  isPinned: false,
);

Future<_FakeCountdownApi> _pump(
  WidgetTester tester, {
  List<CountdownDto>? all,
  _FakeCountdownApi? withApi,
  Size surface = const Size(420, 900),
  double textScale = 1.0,
}) async {
  final api =
      withApi ?? _FakeCountdownApi(all ?? [_dto(1, '倒数日1'), _dto(2, '倒数日2')]);
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

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openTileMenu(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('countdown-tile-more-$id')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('未置顶的卡片「...」菜单里有嘀嗒的「置顶」', (tester) async {
    await _pump(tester);
    await _openTileMenu(tester, 1);
    expect(find.byKey(const Key('countdown-menu-pin-1')), findsOneWidget);
    expect(find.text('置顶'), findsOneWidget);
  });

  testWidgets('点「置顶」发出 value=true 并重取，该行排到首位', (tester) async {
    final api = await _pump(tester);
    await _openTileMenu(tester, 2);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-2')));
    await tester.pumpAndSettle();
    expect(api.writes, [(id: 2, pinned: true)]);
    expect(tester.widgetList<Text>(find.text('倒数日2')).length, 1);
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('倒数日2')),
      findsOneWidget,
    );
    final rects = <int, double>{};
    for (final id in [1, 2]) {
      rects[id] = tester.getTopLeft(find.text('倒数日$id')).dy;
    }
    expect(rects[2]! < rects[1]!, isTrue, reason: '被置顶的行要排在前面，实际 $rects');
  });

  testWidgets('置顶另一条后，服务端清掉前一条，界面只有一条在顶', (tester) async {
    final api = await _pump(tester);
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-1')));
    await tester.pumpAndSettle();
    await _openTileMenu(tester, 2);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-2')));
    await tester.pumpAndSettle();
    expect(api.pinned[1], isFalse, reason: '服务端独占：前一条的置顶位要被清掉');
    expect(api.pinned[2], isTrue);
    expect(api.writes.length, 2);
  });

  testWidgets('已置顶的卡片不再给「置顶」入口（帮助页没写取消置顶，不自创）', (tester) async {
    final api = await _pump(tester);
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-1')));
    await tester.pumpAndSettle();
    await _openTileMenu(tester, 1);
    expect(find.text('置顶'), findsNothing);
    expect(api.writes.length, 1, reason: '只发过一次置顶写入');
  });

  testWidgets('置顶失败仍显示已加载列表并给出提示', (tester) async {
    final api = await _pump(tester);
    api.failWrite = true;
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-1')));
    await tester.pumpAndSettle();
    expect(find.text('倒数日1'), findsOneWidget);
    expect(find.text('倒数日2'), findsOneWidget);
    expect(find.byKey(const Key('countdown-pin-error')), findsOneWidget);
    expect(find.textContaining('置顶失败'), findsOneWidget);
  });

  testWidgets('320 宽 + 1.3 倍字号下「置顶」入口仍可点', (tester) async {
    await _pump(tester, surface: const Size(320, 640), textScale: 1.3);
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-1')));
    await tester.pumpAndSettle();
    expect(find.text('倒数日2'), findsOneWidget);
  });

  testWidgets('「置顶」入口的读屏 label 念得出置顶', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await _openTileMenu(tester, 1);
    // Semantics 包壳是 keyed PopupMenuButton 的祖先，所以只能整屏找那个带 label 的节点，
    // 不能用 descendant(of: byKey(...))——那样恒 0。
    expect(find.bySemanticsLabel('更多操作 倒数日1'), findsOneWidget);
    final labels = tester
        .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
        .map((e) => (e.child as Text?)?.data ?? '')
        .toList();
    expect(
      labels.any((e) => e.contains('置顶')),
      isTrue,
      reason: '菜单项文案 $labels',
    );
    handle.dispose();
  });

  testWidgets('迟到的列表响应不得覆盖置顶后的顺序', (tester) async {
    final api = await _pump(tester);
    // 先让「置顶 2」这次重取挂住：它带的是「2 在顶」的旧快照
    final gate = Completer<List<CountdownDto>>();
    api.holdNext = gate;
    await _openTileMenu(tester, 2);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-2')));
    await _advance(tester);
    expect(api.writes, [(id: 2, pinned: true)]);
    expect(api.heldSnapshot, isNotNull, reason: '重取请求没发出去，时序就没造起来');
    api.holdNext = null;
    // 再让「置顶 1」走通：这是更新的请求，服务端独占后 1 在顶
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-pin-1')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('倒数日1')).dy <
          tester.getTopLeft(find.text('倒数日2')).dy,
      isTrue,
      reason: '更新的响应没把 1 排到前面，后面的对照没有意义',
    );
    // 旧快照现在才回来
    gate.complete(api.heldSnapshot!);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('倒数日1')).dy <
          tester.getTopLeft(find.text('倒数日2')).dy,
      isTrue,
      reason: '迟到的旧响应把顺序改回去了',
    );
  });
}
