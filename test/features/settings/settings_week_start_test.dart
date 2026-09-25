import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/week_start_preference_repository.dart';

const _tile = Key('todo-settings-week-start');
Key _option(int firstDay) => Key('todo-settings-week-start-option-$firstDay');

/// 让「入队」抛错的写队列：**仓储用真的**，所以 `save()` 里那句
/// 「写偏好行 + 入队」仍然跑在同一个 `_db.transaction` 内。
///
/// 复核 4(a) 指出的坑：原先是 `extends WeekStartPreferenceRepository` + 覆盖 `save` 直接抛，
/// 那次 fake 在 `super.save` 之前就退出，**任何生产改动都不可能让「档位没变」这句断言变红**
/// （它测的是 fake 自己）。换成注入坏队列之后：只要有人把写库挪出事务，
/// 偏好行就会留下，这条断言当场红。
class _ThrowingQueue extends SyncChangeQueue {
  _ThrowingQueue(super.db);

  @override
  Future<void> enqueue({
    required String entity,
    required String op,
    String? localId,
    int? serverId,
    String? clientMutationId,
    required Map<String, dynamic> payload,
  }) async {
    throw StateError('故意让写队列失败');
  }
}

Future<WeekStartPreferenceRepository> _pumpSettings(
  WidgetTester tester, {
  double textScale = 1,
  double width = 360,
  bool pendingForever = false,
  WeekStartPreferenceRepository Function(AppDatabase db, SyncChangeQueue q)?
  build,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final repository =
      (build ??
      (AppDatabase d, SyncChangeQueue q) =>
          WeekStartPreferenceRepository(d, q))(db, SyncChangeQueue(db));
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weekStartPreferenceRepositoryProvider.overrideWithValue(repository),
        // pendingForever = 首值未到（FR-7 的 loading 态）：给一条永不回包的流，
        // 这一档必须走兜底而不是 requireValue —— 否则整个设置页第一帧就抛。
        if (pendingForever)
          weekStartProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          // 1.3 倍字号必须在「设置」这个路由自己的 context 上生效，
          // 塞进 home 之下会让 AppBar 用默认字号，测出来的溢出是假的。
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const SettingsRoute(signedInMobile: '13800000000'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(_tile),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  return repository;
}

/// 收尾必须**在测试体内**卸载 ProviderScope。
///
/// drift 取消流订阅时会排一个零时长定时器（`StreamQueryStore.markAsClosed`）。
/// 留给 binding 在下一帧的 unmount 里跑，就会炸
/// 「A Timer is still pending even after the widget tree was disposed」，
/// 而且表现成"整份文件 7 条全红 + 每条卡满 10 分钟"，看着像功能坏了。
/// 先拆树再 pump 一帧，让那个定时器在 fakeAsync 内走完。
Future<void> _settleUnmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // 必须真的推进时钟：drift 的取消回调跑在**这一帧之后的 microtask** 里，
  // `pump()`（时长 0）会把那个零时长定时器留在队列里 —— 实测这样仍报 pending timer。
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('设置页有「日期与时间」分组，里面有「星期开始于」并显示当前档位', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('日期与时间'), findsOneWidget);
    expect(find.byKey(_tile), findsOneWidget);
    expect(find.text('星期开始于'), findsOneWidget);
    expect(find.text('周一'), findsOneWidget, reason: '默认档要显示在行上');

    await _settleUnmount(tester);
  });

  testWidgets('首值未到（loading）时设置行仍显示默认档「周一」，不抛也不空（FR-7 端到端）', (tester) async {
    // 探针 PH（把 resolveWeekStartFirstDay 改成 requireValue）必须在这一条上红：
    // 这一档如果直接取值，设置页第一帧就整个抛掉，用户看到的是打不开的「设置」。
    await _pumpSettings(tester, pendingForever: true);

    expect(
      tester.takeException(),
      isNull,
      reason: '首值未到必须走兜底，不能抛 —— 设置页整页白掉比闪一下严重',
    );
    expect(find.text('星期开始于'), findsOneWidget);
    expect(find.text('周一'), findsOneWidget, reason: '兜底要显示成默认档，不能空着');

    await _settleUnmount(tester);
  });

  testWidgets('点开后正好三档、文案逐字取嘀嗒，且当前档带勾选标记（四件套 ②）', (tester) async {
    await _pumpSettings(tester);

    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();

    expect(find.byKey(_option(DateTime.sunday)), findsOneWidget);
    expect(find.byKey(_option(DateTime.monday)), findsOneWidget);
    expect(find.byKey(_option(DateTime.saturday)), findsOneWidget);
    // 嘀嗒只给这三档，出现第四档就是自创
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith(
              'todo-settings-week-start-option-',
            ),
      ),
      findsNWidgets(3),
    );
    // 三条档位文案必须**限定在弹层子树里**数：设置行自己的副标题也写着「周一」，
    // 按全局 find.text('周一') 断 findsOneWidget 会被两处同时命中（实测 `-1: Found 2 widgets`）。
    final sheet = find.byType(BottomSheet);
    for (final label in ['周日', '周一', '周六']) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
        reason: '弹层里该有「$label」这一档',
      );
    }
    expect(
      find.descendant(of: sheet, matching: find.byIcon(Icons.check)),
      findsOneWidget,
      reason: '只有当前档该有勾选',
    );

    await _settleUnmount(tester);
  });

  testWidgets('点「周日」立刻生效：出箱写库、行上副标题跟着换（FR-8）', (tester) async {
    final repository = await _pumpSettings(tester);

    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_option(DateTime.sunday)));
    await tester.pumpAndSettle();

    expect(await repository.get(), DateTime.sunday);
    expect(find.text('周日'), findsOneWidget, reason: '行上应显示新档位');
    expect(find.text('周一'), findsNothing);

    await _settleUnmount(tester);
  });

  testWidgets('保存失败：给可见提示，档位保持原样（四件套 ③）', (tester) async {
    final repository = await _pumpSettings(
      tester,
      // 真仓储 + 坏队列：save() 里「写偏好行」和「入队」在同一个事务内，
      // 入队抛错 ⇒ 事务回滚 ⇒ 档位不变。谁把写库挪出事务，这条就红。
      build: (db, _) => WeekStartPreferenceRepository(db, _ThrowingQueue(db)),
    );

    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_option(DateTime.sunday)));
    await tester.pumpAndSettle();

    expect(
      find.text('保存失败，星期开始于仍为当前设置'),
      findsOneWidget,
      reason: '失败必须可见，静默早退会被当成"没点上"',
    );
    expect(await repository.get(), DateTime.monday, reason: '失败不能改档位');
    expect(find.text('周一'), findsOneWidget);

    await _settleUnmount(tester);
  });

  testWidgets('库未就绪时点档位给提示，不静默（四件套 ③）', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weekStartPreferenceRepositoryProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          home: SettingsRoute(signedInMobile: '13800000000'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(_tile),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();

    expect(find.text('本地数据库尚未就绪，暂时无法修改星期开始于'), findsOneWidget);

    await _settleUnmount(tester);
  });

  testWidgets('点选写入的是"那一个字面值"：重复点同一档不变、连点两档停在后点的（四件套 ④）', (tester) async {
    final repository = await _pumpSettings(tester);

    // 同一档点两次仍是该档 ⇒ 这一项不是开关，不存在"从当前值取反"
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_option(DateTime.sunday)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_option(DateTime.sunday)));
    await tester.pumpAndSettle();
    expect(await repository.get(), DateTime.sunday, reason: '重复点同一档不能翻回别的档');

    // 再点周六，停在最后一次点中的值（不是回到默认，也不是取反）
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_option(DateTime.saturday)));
    await tester.pumpAndSettle();
    expect(await repository.get(), DateTime.saturday);

    await _settleUnmount(tester);
  });

  testWidgets('320px + 1.3 倍字号：设置行与档位弹层都不溢出（四件套 ①）', (tester) async {
    await _pumpSettings(tester, textScale: 1.3, width: 320);
    expect(
      tester.takeException(),
      isNull,
      reason: '「日期与时间」分组在 320px + 1.3 倍字号下溢出',
    );

    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '三档弹层在 320px + 1.3 倍字号下溢出');
    expect(find.byKey(_option(DateTime.sunday)), findsOneWidget);

    await _settleUnmount(tester);
  });
}
