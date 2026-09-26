import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/timezone_preference_repository.dart';

/// specs/055（FL Issue #368）：「设置 → 日期与时间 → 时区」总开关。
///
/// 分工要说清楚，别把两侧的断言混成一锅：
///   * R 侧（真 in-memory Drift）判**持久化与不动任务数据**：R1 = FR-4，R2 = FR-3 主断言；
///   * W 侧（假仓储）判**设置页这条开关的呈现与写路径**：W1 接线、W2 读屏语义、
///     W3 四件套-1 的 320px + 1.3 倍字号、W4/W5 四件套-3 的失败态。
const _settingsKey = ValueKey('settings-timezone-enabled');

void main() {
  test('R1 无记录即「开」；切换只写偏好一行并入队 view_preference', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TimezonePreferenceRepository(db, SyncChangeQueue(db));

    expect(
      await repository.get(),
      isTrue,
      reason: 'spec 六-1：默认取「开」，否则既有能力对老用户凭空消失',
    );

    await repository.setEnabled(false);

    expect(await repository.get(), isFalse);
    final preference =
        await (db.select(db.todoViewPreferences)..where(
              (row) =>
                  row.sourceType.equals(
                    TimezonePreferenceRepository.sourceType,
                  ) &
                  row.sourceKey.equals(TimezonePreferenceRepository.sourceKey),
            ))
            .get();
    expect(
      preference,
      hasLength(1),
      reason: '总开关只占一行偏好；写第二次应当是 update 而不是再插一行',
    );
    expect(jsonDecode(preference.single.valueJson) as Map<String, dynamic>, {
      'enabled': false,
    });

    final changes =
        await (db.select(db.todoSyncChanges)..where(
              (change) => change.entity.equals(SyncEntities.viewPreference),
            ))
            .get();
    expect(
      changes,
      hasLength(1),
      reason: '偏好要能同步出去，否则换设备又是默认值（specs/054 的同一类缺陷）',
    );

    await repository.setEnabled(true);
    expect(await repository.get(), isTrue);
    expect(
      await (db.select(db.todoViewPreferences)..where(
            (row) =>
                row.sourceType.equals(TimezonePreferenceRepository.sourceType),
          ))
          .get(),
      hasLength(1),
      reason: '再开是同一行被改写；这里若变 2 行就是 id 丢了',
    );
  });

  test('R2 切开关不改任务上的 timeZone / fixedTimezone（FR-3 主断言）', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 19, 9);
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'fixed-tz-task',
            listId: 'inbox',
            title: '伦敦时间上午 10 点开会',
            timeZone: const Value('Europe/London'),
            fixedTimezone: const Value(true),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repository = TimezonePreferenceRepository(db, SyncChangeQueue(db));

    final before = await (db.select(
      db.todoTasks,
    )..where((task) => task.id.equals('fixed-tz-task'))).getSingle();

    await repository.setEnabled(false);
    await repository.setEnabled(true);
    await repository.setEnabled(false);

    final after = await (db.select(
      db.todoTasks,
    )..where((task) => task.id.equals('fixed-tz-task'))).getSingle();
    expect(
      after.timeZone,
      before.timeZone,
      reason: '显隐是 UI 的事：关掉总开关不许把已设的 IANA 时区抹掉',
    );
    expect(
      after.fixedTimezone,
      before.fixedTimezone,
      reason: '同上 —— 这条如果被弄坏，用户重新打开开关时会发现设置"自己没了"',
    );
  });

  testWidgets('W1 设置页有「日期与时间 → 时区」：显示取流值，点一下走仓储写一次', (
    tester,
  ) async {
    final repository = _FakeTimezoneRepository(true);
    await _pumpSettings(tester, repository: repository);

    expect(find.text('日期与时间'), findsOneWidget);
    final switcher = find.descendant(
      of: find.byKey(_settingsKey),
      matching: find.byType(Switch),
    );
    expect(switcher, findsOneWidget);
    expect(
      tester.widget<Switch>(switcher).value,
      isTrue,
      reason: '首屏默认「开」（与仓储同口径，见 spec 六-1）',
    );

    await tester.tap(find.byKey(_settingsKey));
    await tester.pumpAndSettle();

    expect(
      repository.writes,
      [false],
      reason: '开关是"扳一下写一次"：这里 0 次就是只改内存的假开关',
    );
    expect(
      tester.widget<Switch>(switcher).value,
      isFalse,
      reason: '写完要经 watch() 把新状态送回 UI，不是本地自嗨',
    );
  });

  testWidgets('W2 开关有独立读屏语义：名称与可扳性都在', (tester) async {
    final repository = _FakeTimezoneRepository(true);
    final semantics = tester.ensureSemantics();
    await _pumpSettings(tester, repository: repository);

    // ⚠️ 探针实测（`AppDatabase` 无关，纯语义树）：`SwitchListTile` 上挂 key 的节点与内部
    // `Switch` 解析到**同一个** `SemanticsNode`（merge 掉了子节点），且合并节点上
    // `flagsCollection.isChecked` / `isToggled` 恒为 `none`、`isButton` = false
    // ⇒ 光靠 `Switch` 自己，读屏念不出"开着还是关着"。状态必须由 label 带出来
    //（merge 只合并 label），所以正反两条都判 label。
    expect(
      find.bySemanticsLabel(RegExp('时区')),
      findsOneWidget,
      reason: '没有可读名称时这条要红（嘀嗒术语「时区」照抄，不许只剩一个颜色点）',
    );
    final on = tester.getSemantics(find.byKey(_settingsKey));
    expect(
      on.label,
      allOf(contains('时区'), contains('已开启')),
      reason: '读屏只读出"时区"三个字、读不出开还是关 = 这条对视障用户是坏的',
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(_settingsKey)).onChanged,
      isNotNull,
      reason: '回调为 null = 读屏里它扳不动（禁用态），开关就成了摆设',
    );

    await tester.tap(find.byKey(_settingsKey));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(_settingsKey)).label,
      contains('已关闭'),
      reason: '反向对照：切换后播报要跟着翻，不然上一条可能恒真',
    );
    semantics.dispose();
  });

  testWidgets('W3 320px + 1.3 倍字号：这条开关自身不溢出', (tester) async {
    final repository = _FakeTimezoneRepository(true);
    await _pumpSettings(tester, repository: repository, textScale: 1.3);

    expect(
      find.descendant(
        of: find.byKey(_settingsKey),
        matching: find.byType(Switch),
      ),
      findsOneWidget,
      reason: '溢出判据只在该控件真被渲染的前提下才有意义',
    );
    expect(
      tester.takeException(),
      isNull,
      reason:
          'RenderFlex 溢出在测试里是作为异常抛出的；若这条恒 null，'
          '说明被测的 Column 不在窄屏路径上（那就得换被测对象，别当成通过）',
    );
  });

  testWidgets('W4 没有仓储（未就绪）：点一下明确告知不可用，不静默', (tester) async {
    await _pumpSettings(tester, repository: null);

    expect(tester.widget<Switch>(
      find.descendant(
        of: find.byKey(_settingsKey),
        matching: find.byType(Switch),
      ),
    ).value, isTrue);

    await tester.tap(find.byKey(_settingsKey));
    await tester.pumpAndSettle();

    expect(find.text('时区设置暂不可用'), findsOneWidget);
  });

  testWidgets('W5 写失败：给反馈且开关停在原值（四件套-3 不假装成功）', (
    tester,
  ) async {
    final repository = _FakeTimezoneRepository(true)..failNextWrite = true;
    await _pumpSettings(tester, repository: repository);

    await tester.tap(find.byKey(_settingsKey));
    await tester.pumpAndSettle();

    expect(find.text('时区设置未保存'), findsOneWidget);
    expect(
      tester.widget<Switch>(
        find.descendant(
          of: find.byKey(_settingsKey),
          matching: find.byType(Switch),
        ),
      ).value,
      isTrue,
      reason: '非乐观更新：写失败就不该把用户的开关拨过去（拨过去就是谎报已保存）',
    );
    expect(
      repository.current,
      isTrue,
      reason: '失败路径不许改内存态，否则下一次重建就顺着假状态显示了',
    );
  });
}

/// 只替掉「仓储」这一层：`timezoneEnabledProvider` 仍走真实实现去 `watch()` 它，
/// 所以 W1/W5 判的是「读流 → UI → 写 → 读流」整条接线，而不是我手工喂给 UI 的两个值。
///
/// 为什么不接真库：第一版把 in-memory Drift 的 `watch()` 接到 UI 上，收尾必炸
/// `A Timer is still pending even after the widget tree was disposed`（drift 的
/// `markAsClosed` 留 0 时长计时器），改成"收尾 settle 再关库"反而拖到 10 分钟超时。
/// 真库读流由 R1/R2 判，UI 判据不该靠真读库才有意义。
class _FakeTimezoneRepository implements TimezonePreferenceRepository {
  _FakeTimezoneRepository(this.current);

  bool current;
  final List<bool> writes = [];
  bool failNextWrite = false;
  final _changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> watch() async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<bool> get() async => current;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('模拟写库失败');
    }
    writes.add(enabled);
    current = enabled;
    _changes.add(enabled);
  }

  void dispose() => _changes.close();
}

/// 视口宽度就是要测的宽度；高度给足，否则 `ListView(children: …)` 用
/// SliverChildListDelegate 只构建进视口的行 —— 我第一版就是栽在这里：
/// 320×700 下「日期与时间」整节根本没被构建，`find.text` 0 命中，
/// 看着像"控件没做出来"，其实是"没滚到"。
Future<void> _pumpSettings(
  WidgetTester tester, {
  required TimezonePreferenceRepository? repository,
  double textScale = 1.0,
  double width = 320,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        timezonePreferenceRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const SettingsRoute(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
