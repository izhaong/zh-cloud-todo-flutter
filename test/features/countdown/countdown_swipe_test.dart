import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 左滑快捷是纯读侧触发的写动作：fake 只记录调用，不真发网。
class _FakeCountdownApi extends CountdownApi {
  _FakeCountdownApi(this.all) : super(Dio());

  final List<CountdownDto> all;
  final List<int> archivedCalls = [];
  final List<int> pinnedCalls = [];
  final List<int> deletedIds = [];

  @override
  Future<List<CountdownDto>> list({bool archived = false}) async {
    return all.where((e) => e.archived == archived).toList();
  }

  @override
  Future<void> setArchived(int id, bool archived) async {
    archivedCalls.add(id);
    for (var i = 0; i < all.length; i++) {
      if (all[i].id == id) {
        all[i] = CountdownDto(
          id: all[i].id,
          title: all[i].title,
          targetDate: all[i].targetDate,
          daysRemaining: all[i].daysRemaining,
          style: all[i].style,
          showAge: all[i].showAge,
          backgroundImage: all[i].backgroundImage,
          archived: archived,
          isPinned: all[i].isPinned,
          type: all[i].type,
        );
      }
    }
  }

  @override
  Future<void> setPinned(int id, bool pinned) async {
    pinnedCalls.add(id);
  }

  @override
  Future<void> delete(int id) async {
    deletedIds.add(id);
  }
}

CountdownDto _dto(
  int id,
  String title, {
  bool archived = false,
  bool isPinned = false,
}) => CountdownDto(
  id: id,
  title: title,
  targetDate: DateTime(2026, 12, 31),
  daysRemaining: 90,
  style: 1,
  showAge: false,
  archived: archived,
  isPinned: isPinned,
);

Future<_FakeCountdownApi> _pump(
  WidgetTester tester,
  List<CountdownDto> all,
) async {
  final api = _FakeCountdownApi(all);
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [countdownApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: CountdownPage()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> _swipeLeft(WidgetTester tester, int id) async {
  await tester.drag(
    find.byKey(Key('countdown-row-$id')),
    const Offset(-110, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('主列表左滑一行露出 置顶/归档/删除 三个快捷操作', (tester) async {
    await _pump(tester, [_dto(1, '甲'), _dto(2, '乙')]);
    // 关闭时快捷钮也在树里（只是被行盖住）：可见性用 hitTestable 判。
    expect(
      find.byKey(const Key('countdown-swipe-archive-1')).hitTestable(),
      findsNothing,
    );
    await _swipeLeft(tester, 1);
    expect(find.byKey(const Key('countdown-swipe-pin-1')), findsOneWidget);
    expect(find.byKey(const Key('countdown-swipe-archive-1')), findsOneWidget);
    expect(find.byKey(const Key('countdown-swipe-delete-1')), findsOneWidget);
  });

  testWidgets('左滑快捷「归档」直接调 setArchived(true) 并收起', (tester) async {
    final api = await _pump(tester, [_dto(1, '甲')]);
    await _swipeLeft(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-swipe-archive-1')));
    await tester.pumpAndSettle();
    expect(api.archivedCalls, [1]);
    expect(find.byKey(const Key('countdown-swipe-archive-1')), findsNothing);
  });

  testWidgets('左滑快捷「置顶」调 setPinned(true)', (tester) async {
    final api = await _pump(tester, [_dto(1, '甲')]);
    await _swipeLeft(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-swipe-pin-1')));
    await tester.pumpAndSettle();
    expect(api.pinnedCalls, [1]);
  });

  testWidgets('左滑快捷「删除」走二次确认，确认后调 delete', (tester) async {
    final api = await _pump(tester, [_dto(1, '甲')]);
    await _swipeLeft(tester, 1);
    await tester.tap(find.byKey(const Key('countdown-swipe-delete-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.deletedIds, isEmpty, reason: '确认前不该删');
    await tester.tap(find.byKey(const Key('countdown-delete-confirm')));
    await tester.pumpAndSettle();
    expect(api.deletedIds, [1]);
  });

  testWidgets('已置顶的行左滑后没有「置顶」快捷钮（嘀嗒：只支持置顶一个）', (tester) async {
    await _pump(tester, [_dto(1, '甲', isPinned: true)]);
    await _swipeLeft(tester, 1);
    expect(find.byKey(const Key('countdown-swipe-pin-1')), findsNothing);
    expect(find.byKey(const Key('countdown-swipe-archive-1')), findsOneWidget);
  });

  testWidgets('开启「显示分组」后左滑不再露出快捷操作（嘀嗒 :204）', (tester) async {
    await _pump(tester, [_dto(1, '甲'), _dto(2, '乙')]);
    await tester.tap(find.byKey(const Key('countdown-page-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('countdown-menu-groups')));
    await tester.pumpAndSettle();
    await _swipeLeft(tester, 1);
    expect(
      find.byKey(const Key('countdown-swipe-archive-1')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('「已归档」视图左滑不露出本单的快捷操作', (tester) async {
    final api = await _pump(tester, [
      _dto(1, '甲'),
      _dto(2, '已归档乙', archived: true),
    ]);
    await tester.tap(find.byKey(const Key('countdown-page-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('countdown-menu-archived')));
    await tester.pumpAndSettle();
    expect(find.text('已归档乙'), findsOneWidget);
    await _swipeLeft(tester, 2);
    expect(api.archivedCalls, isEmpty);
    expect(find.byKey(const Key('countdown-swipe-archive-2')), findsNothing);
  });
}
