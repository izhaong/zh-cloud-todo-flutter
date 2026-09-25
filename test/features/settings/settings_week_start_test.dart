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

/// 会抛的仓储：用来验「保存失败时当前档位不变、且有可见提示」（四件套 ③）。
class _ThrowingRepository extends WeekStartPreferenceRepository {
  _ThrowingRepository(super.db, super.queue);

  @override
  Future<void> save(int firstDay) async {
    throw StateError('故意让写入失败');
  }
}

Future<WeekStartPreferenceRepository> _pumpSettings(
  WidgetTester tester, {
  double textScale = 1,
  double width = 360,
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
      build: (db, queue) => _ThrowingRepository(db, queue),
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
