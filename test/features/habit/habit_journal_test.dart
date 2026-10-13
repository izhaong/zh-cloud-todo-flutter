import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/habit/habit_journal.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/131 · 习惯打卡心情与日志（矩阵 #45 面 ④）。
///
/// 判据源《02-更好地完成习惯.md》:55-:60——
/// 「你能够记录每天，完成习惯的心情以及日志，方便回顾」。
void main() {
  group('HabitCheckInEntry.moodAndJournal 拆分约定', () {
    test('首行 emoji 五档之一 ⇒ (mood, journal)', () {
      final entry = HabitCheckInEntry(
        id: 1,
        checkedAt: DateTime(2026, 7, 15, 9),
        note: '😊\n今天状态不错，背了 20 页',
      );
      final pair = entry.moodAndJournal!;
      expect(pair.$1, '😊');
      expect(pair.$2, '今天状态不错，背了 20 页');
    });

    test('纯 emoji（无日志）⇒ journal 为 null', () {
      final entry = HabitCheckInEntry(
        id: 1,
        checkedAt: DateTime(2026, 7, 15, 9),
        note: '🤩',
      );
      final pair = entry.moodAndJournal!;
      expect(pair.$1, '🤩');
      expect(pair.$2, isNull);
    });

    test('无 emoji 的日志 ⇒ mood 为 null、journal 透传', () {
      final entry = HabitCheckInEntry(
        id: 1,
        checkedAt: DateTime(2026, 7, 15, 9),
        note: '只写了日志',
      );
      final pair = entry.moodAndJournal!;
      expect(pair.$1, isNull);
      expect(pair.$2, '只写了日志');
    });

    test('空 note ⇒ null（不渲染）', () {
      final entry = HabitCheckInEntry(
        id: 1,
        checkedAt: DateTime(2026, 7, 15, 9),
      );
      expect(entry.moodAndJournal, isNull);
    });

    test('fromJson：epoch 毫秒与 note/amount 透传', () {
      final entry = HabitCheckInEntry.fromJson({
        'id': 7,
        'checkedAt': 1784086800000,
        'note': '😤\n状态一般',
        'amount': 3,
      });
      expect(entry.id, 7);
      expect(entry.amount, 3);
      expect(entry.moodAndJournal!.$1, '😤');
      expect(entry.moodAndJournal!.$2, '状态一般');
    });
  });

  group('打卡弹层（widget 级）', () {
    testWidgets('弹层交互可达：标题/心情节/日志输入框/五档按钮', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showHabitCheckInSheet(context, habitId: 1),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('打卡'), findsWidgets);
      expect(find.text('心情'), findsOneWidget);
      expect(find.text('日志'), findsOneWidget);
      expect(find.byKey(const Key('habit-journal-input')), findsOneWidget);
      for (var i = 0; i < habitMoodChoices.length; i++) {
        expect(find.byKey(Key('habit-mood-$i')), findsOneWidget);
      }
    });
  });

  group('打卡日志时间轴（HabitJournalSection）', () {
    HabitCheckInEntry entry(int id, String? note) => HabitCheckInEntry(
      id: id,
      checkedAt: DateTime(2026, 7, 10 + id, 21, 5),
      note: note,
    );

    Widget pumpSection(WidgetTester tester, List<HabitCheckInEntry> entries) {
      return UncontrolledProviderScope(
        container: ProviderContainer(
          overrides: [
            habitJournalFutureProvider(
              7,
            ).overrideWith((ref) => Future.value(entries)),
          ],
        ),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HabitJournalSection(habitId: 7)),
          ),
        ),
      );
    }

    testWidgets('有条目：渲染标题与各条目的日期/心情/日志', (tester) async {
      await tester.pumpWidget(
        pumpSection(tester, [entry(1, '😊\n今天状态不错'), entry(2, '补记日志')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('打卡日志'), findsOneWidget);
      expect(find.text('07-11 21:05'), findsOneWidget);
      expect(find.text('07-12 21:05'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('今天状态不错'), findsOneWidget);
      expect(find.text('补记日志'), findsOneWidget);
    });

    testWidgets('空日志：整段不渲染', (tester) async {
      await tester.pumpWidget(pumpSection(tester, []));
      await tester.pumpAndSettle();
      expect(find.text('打卡日志'), findsNothing);
    });
  });
}
