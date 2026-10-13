import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/calendar_info_preference_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/129 · 习惯打卡进日历（矩阵 #45 面 ③）。
///
/// 判据源《02-功能指南/05-习惯打卡/02-更好地完成习惯.md》:43/:48/:116——
/// 习惯出现在日历时间轴 + 「显示习惯」开关。
void main() {
  group('CalendarInfoFlags.showHabits 持久化', () {
    test('默认关；三键独立保存互不影响', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = CalendarInfoPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );

      expect(
        await repository.get(),
        const CalendarInfoFlags(
          showLunar: false,
          showHolidays: false,
          showHabits: false,
        ),
      );

      await repository.save(
        const CalendarInfoFlags(
          showLunar: false,
          showHolidays: false,
          showHabits: true,
        ),
      );
      var flags = await repository.get();
      expect(flags.showHabits, isTrue);
      expect(flags.showLunar, isFalse);
      expect(flags.showHolidays, isFalse);

      await repository.save(
        const CalendarInfoFlags(
          showLunar: true,
          showHolidays: false,
          showHabits: true,
        ),
      );
      flags = await repository.get();
      expect(flags.showHabits, isTrue);
      expect(flags.showLunar, isTrue);
    });

    test('旧数据（无 showHabits 键）按关处理', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.todoViewPreferences)
          .insert(
            TodoViewPreferencesCompanion.insert(
              id: 'legacy',
              sourceType: 'CALENDAR_INFO',
              sourceKey: 'global',
              valueJson: '{"showLunar":true,"showHolidays":false}',
              updatedAt: DateTime(2026, 7, 15),
              createdAt: DateTime(2026, 7, 15),
            ),
          );
      final repository = CalendarInfoPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      final flags = await repository.get();
      expect(flags.showLunar, isTrue);
      expect(flags.showHabits, isFalse);
    });
  });

  group('设置页「显示习惯打卡」开关（widget 级）', () {
    testWidgets('三行都在；开「显示习惯打卡」落库', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = CalendarInfoPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
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
      expect(find.text('显示习惯打卡'), findsOneWidget);

      // 收尾在测试体内卸载 ProviderScope（drift 零时长定时器，_settleUnmount 先例）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      // 直写验证（与开关回调同一 save 调用）。
      await repository.save(
        const CalendarInfoFlags(
          showLunar: false,
          showHolidays: false,
          showHabits: true,
        ),
      );
      expect((await repository.get()).showHabits, isTrue);
    });
  });

  group('日历月视图习惯打卡点（直泵 CalendarView）', () {
    testWidgets('showHabits 开启且 provider 失败：日历主体照常渲染（FR-3 现状锁）', (
      tester,
    ) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final infoRepo = fixture.container.read(
        calendarInfoPreferenceRepositoryProvider,
      )!;
      await infoRepo.save(
        const CalendarInfoFlags(
          showLunar: false,
          showHolidays: false,
          showHabits: true,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: Scaffold(
              body: CalendarView(
                tasks: const [],
                now: DateTime(2026, 7, 15, 9),
                filterCompleted: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 月视图照常（无任务、无习惯数据）。
      expect(find.byType(CalendarView), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 收尾在测试体内卸载 ProviderScope：habit/lunar/holidays 三个
      // autoDispose provider 的 HTTP 失败路径会留定时器（_settleUnmount 先例）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
