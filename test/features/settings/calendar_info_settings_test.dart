import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/calendar_info_preference_repository.dart';

/// specs/125 · 「显示农历 / 显示节假日调休」开关（矩阵 #31 面 ①）。
///
/// 判据源《02-日历/06-日历显示设置.md》:5-21——
/// 「在『设置』-『日期与时间』里开启『显示农历』和『显示节假日调休』即可」。
void main() {
  group('CalendarInfoPreferenceRepository 开关持久化', () {
    test('默认双关；save 后回读一致；双键独立保存', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = CalendarInfoPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );

      expect(
        await repository.get(),
        const CalendarInfoFlags(showLunar: false, showHolidays: false),
      );

      await repository.save(
        const CalendarInfoFlags(showLunar: true, showHolidays: false),
      );
      expect(
        await repository.get(),
        const CalendarInfoFlags(showLunar: true, showHolidays: false),
      );

      await repository.save(
        const CalendarInfoFlags(showLunar: true, showHolidays: true),
      );
      expect(
        await repository.get(),
        const CalendarInfoFlags(showLunar: true, showHolidays: true),
      );
    });

    test('旧数据/损坏 JSON 安全降级为默认档', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = CalendarInfoPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      await db
          .into(db.todoViewPreferences)
          .insert(
            TodoViewPreferencesCompanion.insert(
              id: 'broken',
              sourceType: 'CALENDAR_INFO',
              sourceKey: 'global',
              valueJson: 'not-json',
              updatedAt: DateTime(2026, 7, 15),
              createdAt: DateTime(2026, 7, 15),
            ),
          );
      expect(
        await repository.get(),
        const CalendarInfoFlags(showLunar: false, showHolidays: false),
      );
    });

    test('save 同步入箱（view_preference 通道），不落半条', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = CalendarInfoPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      await repository.save(
        const CalendarInfoFlags(showLunar: true, showHolidays: true),
      );
      final rows = await db.select(db.todoViewPreferences).get();
      expect(rows, hasLength(1));
      final changes = await db.select(db.todoSyncChanges).get();
      expect(changes, hasLength(1));
      expect(changes.single.entity, 'view_preference');
    });
  });

  group('设置页开关（widget 级）', () {
    testWidgets('「日期与时间」组里有「显示农历」「显示节假日调休」两行', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(390, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            syncChangeQueueProvider.overrideWithValue(SyncChangeQueue(db)),
          ],
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const SettingsRoute(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('显示农历'), findsOneWidget);
      expect(find.text('显示节假日调休'), findsOneWidget);
      expect(find.byKey(const Key('todo-settings-show-lunar')), findsOneWidget);
      expect(
        find.byKey(const Key('todo-settings-show-holidays')),
        findsOneWidget,
      );

      // 收尾在测试体内卸载 ProviderScope：drift 取消流订阅会排零时长定时器
      // （StreamQueryStore.markAsClosed），先拆树再推进时钟让它在 fakeAsync
      // 内走完（settings_week_start 的 _settleUnmount 同款先例）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('开「显示农历」落库（真仓储直写，绕开页面拖拽）', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = CalendarInfoPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      // 模拟开关回调要做的事（与 _CalendarInfoToggleTile.onChanged 同一写入）。
      await repository.save(
        const CalendarInfoFlags(showLunar: true, showHolidays: false),
      );
      final flags = await repository.get();
      expect(flags.showLunar, isTrue);
      expect(flags.showHolidays, isFalse);
    });
  });
}
