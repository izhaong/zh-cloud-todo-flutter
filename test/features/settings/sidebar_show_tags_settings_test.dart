import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md》
/// :16「点击侧边栏右下角「设置」…点击「标签」，选择「显示」」、
/// :27「点击头像进入「设置」-「智能清单」，找到「标签」设置为「显示」」。
const tileKey = Key('todo-settings-show-tags');

void main() {
  testWidgets('设置 →「智能清单」→「标签」：一次点击选「隐藏」就写库，选回「显示」也写回', (tester) async {
    final fixture = await _pumpSettings(tester);

    expect(find.text('智能清单'), findsOneWidget, reason: '分组名照抄嘀嗒');
    expect(find.text('标签'), findsOneWidget);
    expect(_trailingValue(tester), '显示');

    await _pick(tester, '隐藏');
    expect(_trailingValue(tester), '隐藏');
    expect(await _storedValue(fixture.database), isFalse);

    await _pick(tester, '显示');
    expect(_trailingValue(tester), '显示');
    expect(await _storedValue(fixture.database), isTrue);

    // 当前已经是「显示」时再点一次「显示」。少这一步 ⇒ 把实现写成
    // `save(showTags: !current)`（取反）也永远全绿：上面两次点击恰好都点在
    // 与当前相反的那一项上，取反与照抄字面值在那条路径上逐点等价。
    await _pick(tester, '显示');
    expect(_trailingValue(tester), '显示', reason: '写入的必须是点中的字面值，不是"和当前相反"');
    expect(await _storedValue(fixture.database), isTrue);
  });

  testWidgets('取值由这一行自己的读屏语义念出来，不是只画一个勾', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpSettings(tester);

    // 合并后的 label 用 \n 分隔 title/subtitle/trailing，所以通配要跨行。
    // 副标题里刻意不出现「显示 / 隐藏」，否则这两条断言会永远为真。
    expect(
      find.bySemanticsLabel(RegExp('标签[\\s\\S]*显示')),
      findsOneWidget,
      reason: '读屏要念出「标签」+ 当前取值',
    );
    expect(
      find.bySemanticsLabel(RegExp('标签[\\s\\S]*隐藏')),
      findsNothing,
      reason: '正向对照：当前是「显示」时不该念出「隐藏」',
    );

    await _pick(tester, '隐藏');
    expect(find.bySemanticsLabel(RegExp('标签[\\s\\S]*隐藏')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('标签[\\s\\S]*显示')), findsNothing);

    handle.dispose();
  });

  testWidgets('写入失败时给出可见提示，取值与库里的值都保持原样', (tester) async {
    final fixture = await _pumpSettings(tester, failing: true);
    final rowsBefore = await fixture.database
        .select(fixture.database.todoViewPreferences)
        .get();

    await _pick(tester, '隐藏');

    expect(_trailingValue(tester), '显示', reason: '失败后设置行不能显示成已改');
    expect(
      find.text('保存失败，显示标签仍为当前设置'),
      findsOneWidget,
      reason: '失败必须可见，不能静默回到原值',
    );
    expect(
      await fixture.database.select(fixture.database.todoViewPreferences).get(),
      hasLength(rowsBefore.length),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，显示标签仍为当前设置'), findsNothing);
  });

  testWidgets('打开弹层后不选直接关掉：不写库、取值不变', (tester) async {
    final fixture = await _pumpSettings(tester);

    await tester.tap(find.byKey(tileKey));
    await tester.pumpAndSettle();
    expect(find.text('隐藏'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(_trailingValue(tester), '显示');
    expect(
      await fixture.database.select(fixture.database.todoViewPreferences).get(),
      isEmpty,
    );
  });

  testWidgets('320px + 1.3 倍字号：设置行与选项弹层都排得下，且各用自己的档位', (tester) async {
    await _pumpSettings(tester, surface: const Size(320, 720), textScale: 1.3);

    expect(tester.takeException(), isNull, reason: '设置页在 320px + 1.3 下溢出');

    await tester.tap(find.byKey(tileKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '选项弹层在 320px + 1.3 下溢出');
    expect(find.text('隐藏'), findsOneWidget);
  });

  // FL Issue #363：这一格的取值文字原先用 `.when(error: …)`，把「出过一次值之后流才失败」
  // 也折进 error 分支 ⇒ 已经读到的取值被换成「读取失败」。与第 74 轮侧栏那条病灶同形
  // （四件套 ③「失败保留已加载数据」），侧栏那侧已由 `valueOrNull ?? (hasError ? 默认 : …)` 修掉。
  testWidgets('出过一次值之后流才失败：取值仍是上次读到的，失败另有可见提示', (tester) async {
    final gate = StreamController<bool>();
    addTearDown(gate.close);
    await _pumpSettings(tester, watchStream: gate.stream);

    gate.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_trailingValue(tester), '隐藏', reason: '先确认首值真的到达过');

    gate.addError(StateError('故意在出过一次值之后让流失败'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      _trailingValue(tester),
      '隐藏',
      reason: '错在有值之后 ⇒ 取值文字要留住上次读到的那个，退回「读取失败」等于把已加载数据丢掉',
    );
    expect(
      find.text('读取偏好失败，显示的是上次读到的值'),
      findsOneWidget,
      reason: '留住旧值不等于把失败藏起来：必须另给一句可见提示',
    );
  });

  testWidgets('首值就没读到就失败：取值显示「读取失败」，不假装读到了默认值', (tester) async {
    final gate = StreamController<bool>();
    addTearDown(gate.close);
    await _pumpSettings(tester, watchStream: gate.stream);

    gate.addError(StateError('故意让首值就失败'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(_trailingValue(tester), '读取失败');
    expect(
      find.text('读取偏好失败，显示的是上次读到的值'),
      findsNothing,
      reason: '从来没有旧值时不能说"显示的是上次读到的值"',
    );
  });

  testWidgets('加载中取值是「…」，失败提示此时不出现', (tester) async {
    final gate = StreamController<bool>();
    addTearDown(gate.close);
    await _pumpSettings(tester, watchStream: gate.stream);

    expect(_trailingValue(tester), '…');
    expect(find.text('读取偏好失败，显示的是上次读到的值'), findsNothing);
  });
}

/// 只替换 `watch()`，让用例自己决定首值/错误何时到达；`get()`/`save()` 仍走真库。
class _StreamVisibilityRepository extends SidebarVisibilityRepository {
  _StreamVisibilityRepository(super.db, super.queue, {required this.values});

  final Stream<bool> values;

  @override
  Stream<bool> watch() => values;
}

Future<TodoVisualFixture> _pumpSettings(
  WidgetTester tester, {
  bool failing = false,
  Stream<bool>? watchStream,
  Size surface = const Size(1000, 900),
  double textScale = 1,
}) async {
  List<Override> Function(AppDatabase)? builder;
  if (watchStream != null) {
    builder = (database) => [
      sidebarVisibilityRepositoryProvider.overrideWith(
        (ref) => _StreamVisibilityRepository(
          database,
          SyncChangeQueue(database),
          values: watchStream,
        ),
      ),
    ];
  } else if (failing) {
    builder = (database) => [
      sidebarVisibilityRepositoryProvider.overrideWith(
        (ref) => _FailingRepository(database, SyncChangeQueue(database)),
      ),
    ];
  }
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
    overridesBuilder: builder,
  );
  addTearDown(fixture.dispose);

  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        builder: textScale == 1
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
        home: const SettingsRoute(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _revealTile(tester);
  return fixture;
}

/// `ListView` 是懒建的：窄屏 + 大字号时「智能清单」分组还没被构建过，
/// 直接 `ensureVisible` 会 "No element"。先滚到被构建，再滚进可视区。
Future<void> _revealTile(WidgetTester tester) async {
  final finder = find.byKey(tileKey);
  if (finder.evaluate().isNotEmpty) {
    final top = tester.getRect(finder).top;
    if (top > 0 && top < tester.view.physicalSize.height) return;
  }
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String option) async {
  await tester.tap(find.byKey(tileKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_optionKey(option)));
  await tester.pumpAndSettle();
}

Key _optionKey(String option) =>
    Key('todo-settings-show-tags-option-${option == '显示'}');

String _trailingValue(WidgetTester tester) {
  final tile = tester.widget<ListTile>(
    find.descendant(of: find.byKey(tileKey), matching: find.byType(ListTile)),
  );
  final trailing = tile.trailing;
  expect(trailing, isA<Text>(), reason: '取值要用文字，不能只画勾');
  return (trailing! as Text).data!;
}

Future<bool?> _storedValue(AppDatabase db) async {
  final rows =
      await (db.select(db.todoViewPreferences)..where(
            (preference) => preference.sourceType.equals(
              SidebarVisibilityRepository.sourceType,
            ),
          ))
          .get();
  if (rows.isEmpty) return null;
  final decoded = jsonDecode(rows.single.valueJson) as Map<String, dynamic>;
  return decoded['showTags'] as bool;
}

/// 只让写入失败，读仍走真库：钉住「失败保留已加载数据」这一维。
class _FailingRepository extends SidebarVisibilityRepository {
  _FailingRepository(super.db, super.queue);

  @override
  Future<void> save({required bool showTags}) async {
    throw StateError('故意让写入失败');
  }
}
