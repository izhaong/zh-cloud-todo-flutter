import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 归档与恢复的服务端替身：`list(archived:)` 按 `flags` 分流，`setArchived` 记录调用。
class _FakeCountdownApi extends CountdownApi {
  _FakeCountdownApi(this.all) : super(Dio());

  /// 全部条目；`flags[id]` 缺省视为未归档。
  final List<CountdownDto> all;
  final Map<int, bool> flags = {};
  final List<({int id, bool archived})> writes = [];
  bool failWrite = false;

  /// 非空时「已归档」请求挂起，等测试手动 complete，用来投「迟到的响应」。
  Completer<List<CountdownDto>>? archivedGate;

  @override
  Future<List<CountdownDto>> list({bool archived = false}) async {
    final filtered = all
        .where((e) => (flags[e.id] ?? false) == archived)
        .map(
          (e) => CountdownDto(
            id: e.id,
            title: e.title,
            targetDate: e.targetDate,
            daysRemaining: e.daysRemaining,
            style: e.style,
            showAge: e.showAge,
            backgroundImage: e.backgroundImage,
            archived: flags[e.id] ?? false,
          ),
        )
        .toList();
    if (archived && archivedGate != null) {
      await archivedGate!.future;
    }
    return filtered;
  }

  @override
  Future<void> setArchived(int id, bool archived) async {
    if (failWrite) throw _businessError();
    writes.add((id: id, archived: archived));
    flags[id] = archived;
  }
}

DioException _businessError() => DioException(
  requestOptions: RequestOptions(path: '/app-api/todo/countdown/1/archived'),
  error: '服务不可用',
);

CountdownDto _dto(int id, String title, {bool archived = false}) =>
    CountdownDto(
      id: id,
      title: title,
      targetDate: DateTime(2026, 12, 31),
      daysRemaining: 90,
      archived: archived,
    );

_FakeCountdownApi _api(List<CountdownDto> items) {
  final api = _FakeCountdownApi(items);
  for (final dto in items) {
    api.flags[dto.id] = dto.archived;
  }
  return api;
}

Future<_FakeCountdownApi> _pump(
  WidgetTester tester, {
  List<CountdownDto>? all,
  _FakeCountdownApi? withApi,
  Size? surface,
  double textScale = 1,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final api =
      withApi ??
      _api(
        all ??
            [_dto(1, '倒数日1'), _dto(2, '倒数日2'), _dto(9, '已归档A', archived: true)],
      );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        countdownApiProvider.overrideWithValue(api),
        countdownsProvider.overrideWith((ref) => api.list()),
        archivedCountdownsProvider.overrideWith(
          (ref) => api.list(archived: true),
        ),
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

/// 展开某张卡片的「...」菜单。
Future<void> _openTileMenu(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('countdown-tile-more-$id')));
  await tester.pumpAndSettle();
}

/// 打开页面右上角「...」：pump(400ms) 只出一帧，路由几何未就位会打不中菜单项，
/// 所以先推一帧再推满动画时长。
Future<void> _openPageMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('countdown-page-more')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 定点推进：菜单动画 + autoDispose 视图切换后的重取都要跑完，
/// 但 gate 挂着时加载圈是无限动画，pumpAndSettle 会超时。
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 走页面右上角「...」切到指定视图。
Future<void> _gotoView(WidgetTester tester, Key itemKey) async {
  await tester.tap(find.byKey(const Key('countdown-page-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(itemKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('主列表卡片有「...」入口，菜单里有嘀嗒的「归档」', (tester) async {
    await _pump(tester);
    await _openTileMenu(tester, 1);
    expect(find.byKey(const Key('countdown-menu-archive-1')), findsOneWidget);
    expect(find.text('归档'), findsOneWidget);
  });

  testWidgets('点「归档」发出 value=true 并重取，该条离开主列表', (tester) async {
    final api = await _pump(tester);
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-archive-1')));
    await tester.pumpAndSettle();
    expect(api.writes, [(id: 1, archived: true)]);
    expect(find.text('倒数日1'), findsNothing);
    expect(find.text('倒数日2'), findsOneWidget);
  });

  testWidgets('AppBar「...」-「已归档」只列归档内容，且菜单文案是「恢复」', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('countdown-page-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-menu-archived')));
    await tester.pumpAndSettle();
    expect(find.text('已归档A'), findsOneWidget);
    expect(find.text('倒数日1'), findsNothing);
    await _openTileMenu(tester, 9);
    expect(find.byKey(const Key('countdown-menu-restore-9')), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
  });

  testWidgets('已归档里点「恢复」发出 value=false 并回到主列表', (tester) async {
    final api = await _pump(tester);
    await tester.tap(find.byKey(const Key('countdown-page-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-menu-archived')));
    await tester.pumpAndSettle();
    await _openTileMenu(tester, 9);
    await tester.tap(find.byKey(const Key('countdown-menu-restore-9')));
    await tester.pumpAndSettle();
    expect(api.writes, [(id: 9, archived: false)]);
  });

  testWidgets('归档失败仍显示已加载列表并给出可重试提示', (tester) async {
    final api = await _pump(tester);
    api.failWrite = true;
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-archive-1')));
    await tester.pumpAndSettle();
    expect(find.text('倒数日1'), findsOneWidget);
    expect(find.text('倒数日2'), findsOneWidget);
    expect(find.byKey(const Key('countdown-archive-error')), findsOneWidget);
  });

  testWidgets('320 宽 + 1.3 倍字号下「归档」入口仍可点', (tester) async {
    await _pump(tester, surface: const Size(320, 640), textScale: 1.3);
    await _openTileMenu(tester, 1);
    await tester.ensureVisible(
      find.byKey(const Key('countdown-menu-archive-1')),
    );
    await tester.tap(find.byKey(const Key('countdown-menu-archive-1')));
    await tester.pumpAndSettle();
    expect(find.text('倒数日1'), findsNothing);
  });

  testWidgets('归档入口的读屏 label 念得出「归档」', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await _openTileMenu(tester, 1);
    final node = tester.getSemantics(
      find.descendant(
        of: find.byKey(const Key('countdown-menu-archive-1')),
        matching: find.text('归档'),
      ),
    );
    expect(node.label, contains('归档'));
    handle.dispose();
  });

  testWidgets('刚归档的那条，在「已归档」里能被恢复（卡片菜单不得仍写「归档」）', (tester) async {
    final api = await _pump(tester);
    await _openTileMenu(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-menu-archive-1')));
    await tester.pumpAndSettle();
    await _gotoView(tester, const Key('countdown-menu-archived'));
    expect(find.text('倒数日1'), findsOneWidget);
    await _openTileMenu(tester, 1);
    expect(find.byKey(const Key('countdown-menu-restore-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('countdown-menu-restore-1')));
    await tester.pumpAndSettle();
    expect(api.writes, [(id: 1, archived: true), (id: 1, archived: false)]);
  });

  testWidgets('恢复失败提示说「恢复失败」而不是「归档失败」', (tester) async {
    final api = await _pump(tester);
    await _gotoView(tester, const Key('countdown-menu-archived'));
    api.failWrite = true;
    await _openTileMenu(tester, 9);
    await tester.tap(find.byKey(const Key('countdown-menu-restore-9')));
    await tester.pumpAndSettle();
    expect(find.textContaining('恢复失败'), findsOneWidget);
    expect(find.textContaining('归档失败'), findsNothing);
  });

  testWidgets('迟到的「已归档」响应不得覆盖已经切回的主列表', (tester) async {
    // 加载圈是无限动画：gate 挂着期间一律用定点 pump，pumpAndSettle 会超时。
    final api = _api([
      _dto(1, '倒数日1'),
      _dto(2, '倒数日2'),
      _dto(9, '已归档A', archived: true),
    ]);
    api.archivedGate = Completer<List<CountdownDto>>();
    await _pump(tester, withApi: api);
    await _openPageMenu(tester);
    await tester.tap(find.byKey(const Key('countdown-menu-archived')));
    // 菜单关闭是动画：gate 挂着时不能 pumpAndSettle（加载圈无限）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已归档A'), findsNothing);
    await _openPageMenu(tester);
    await tester.tap(find.byKey(const Key('countdown-menu-main')));
    await _advance(tester);
    expect(find.text('倒数日1'), findsOneWidget);
    api.archivedGate!.complete([_dto(9, '已归档A', archived: true)]);
    await _advance(tester);
    expect(find.text('倒数日1'), findsOneWidget);
    expect(find.text('已归档A'), findsNothing);
  });
}
