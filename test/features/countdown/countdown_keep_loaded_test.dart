import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// #375 批次 1：倒数日列表刷新失败时不得把已加载的行换成整页「加载失败」。
void main() {
  testWidgets('刷新失败保留已加载的行，并给可见提示', (tester) async {
    final api = _FakeCountdownApi();
    final container = await _pump(tester, api);

    expect(
      find.byKey(const Key('countdown-row-1')),
      findsOneWidget,
      reason: '首屏按 fake 渲染出一行',
    );
    expect(find.text('列表刷新失败，仍显示上一次的数据'), findsNothing);

    api.fail = true;
    container.invalidate(countdownsProvider);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('countdown-row-1')),
      findsOneWidget,
      reason: '刷新失败不该丢掉已加载的列表',
    );
    expect(find.text('列表刷新失败，仍显示上一次的数据'), findsOneWidget);
    expect(
      find.textContaining('加载失败: Exception: boom'),
      findsNothing,
      reason: '有值时不再整页失败',
    );
  });

  testWidgets('提示条有独立读屏语义（liveRegion）', (tester) async {
    final semantics = tester.ensureSemantics();
    final api = _FakeCountdownApi();
    final container = await _pump(tester, api);

    api.fail = true;
    container.invalidate(countdownsProvider);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('列表刷新失败，仍显示上一次的数据')),
      matchesSemantics(label: '列表刷新失败，仍显示上一次的数据', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('320px + 1.3 倍字号：保留的行与提示都在，且无布局溢出', (tester) async {
    final api = _FakeCountdownApi();
    final container = await _pump(tester, api, width: 320, textScale: 1.3);

    api.fail = true;
    container.invalidate(countdownsProvider);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '窄屏 + 大字号不得溢出');
    expect(find.byKey(const Key('countdown-row-1')), findsOneWidget);
    expect(find.text('列表刷新失败，仍显示上一次的数据'), findsOneWidget);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _FakeCountdownApi api, {
  double width = 800,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [countdownApiProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const MaterialApp(home: CountdownPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _FakeCountdownApi extends CountdownApi {
  _FakeCountdownApi() : super(Dio());

  bool fail = false;

  @override
  Future<List<CountdownDto>> list({bool archived = false}) async {
    if (fail) throw Exception('boom');
    return [
      CountdownDto(
        id: 1,
        title: '生日',
        targetDate: DateTime(2026, 12, 31),
        daysRemaining: 90,
      ),
    ];
  }
}
