import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/calendar_info_preference_repository.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_smart_list_visibility.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/habit_smart_list_preference_repository.dart';

/// specs/130 · 智能清单显示习惯（矩阵 #45 面 ⑤）。
///
/// 判据源《02-更好地完成习惯.md》:66——
/// 「可在习惯页面右上角点击管理图标，选择『在“今天”、“最近7天”中显示』」。
void main() {
  group('HabitSmartListPreferenceRepository 持久化', () {
    test('默认关；开/关往返一致', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = HabitSmartListPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );

      expect(await repository.get(), isFalse);
      await repository.save(true);
      expect(await repository.get(), isTrue);
      await repository.save(false);
      expect(await repository.get(), isFalse);
    });

    test('旧数据/损坏 JSON 安全降级为关', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.todoViewPreferences)
          .insert(
            TodoViewPreferencesCompanion.insert(
              id: 'broken',
              sourceType: 'HABIT_SMART_LIST',
              sourceKey: 'global',
              valueJson: 'not-json',
              updatedAt: DateTime(2026, 7, 15),
              createdAt: DateTime(2026, 7, 15),
            ),
          );
      final repository = HabitSmartListPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      expect(await repository.get(), isFalse);
    });

    test('save 同步入箱（view_preference 通道）', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = HabitSmartListPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      await repository.save(true);
      final changes = await db.select(db.todoSyncChanges).get();
      expect(changes, hasLength(1));
      expect(changes.single.entity, 'view_preference');
    });
  });

  group('习惯页管理入口（widget 级）', () {
    testWidgets('习惯页右上角有「在“今天”、“最近7天”中显示」入口，点开切换落库', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = HabitSmartListPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(SyncChangeQueue(db)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(body: HabitSmartListVisibilityAction()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 入口存在；点开切换（toggle 语义：开→关→开）。
      expect(find.byKey(const Key('habit-smart-list-entry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('habit-smart-list-entry')));
      await tester.pumpAndSettle();
      expect(await repository.get(), isTrue);

      await tester.tap(find.byKey(const Key('habit-smart-list-entry')));
      await tester.pumpAndSettle();
      expect(await repository.get(), isFalse);
    });
  });

  group('与日历开关的隔离（specs/125 vs 130）', () {
    test('两面偏好互不影响（cursor-agent 交叉验证的偏好归属收紧）', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final smartRepo = HabitSmartListPreferenceRepository(
        db,
        SyncChangeQueue(db),
      );
      final calRepo = CalendarInfoPreferenceRepository(db, SyncChangeQueue(db));

      await smartRepo.save(true);
      expect((await calRepo.get()).showHabits, isFalse);
      await calRepo.save(
        const CalendarInfoFlags(
          showLunar: false,
          showHolidays: false,
          showHabits: true,
        ),
      );
      expect(await smartRepo.get(), isTrue);
    });
  });
}
