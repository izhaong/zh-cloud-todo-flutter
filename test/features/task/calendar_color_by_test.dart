import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/timeline_color.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/124 · 日历任务块按清单/标签/优先级着色（矩阵 #31「清单自定义颜色」档）。
///
/// 判据源《02-功能指南/02-日历/08-常见问题.md》:58——
/// 「点击日历视图右上方『···』-『显示设置』-『颜色』-『显示方式』，
/// 即可选择任务块按照清单、优先级或者是标签显示颜色」。
void main() {
  group('日历显示设置：颜色轴（页面级）', () {
    testWidgets('显示设置抽屉有「颜色」三档；选「按清单」保存后重进仍是按清单', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = fixture.container.read(taskViewActionRepositoryProvider)!;
      // 先建一条任务把收集箱落库（工作区可达前提）。
      await fixture.container
          .read(taskRepositoryProvider)!
          .create(listId: TodoVisualFixture.inboxListId, title: '种子任务');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(
              body: TasksByListPage(
                initialListId: TodoVisualFixture.inboxListId,
                lockedListId: true,
                hideAppBar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 切到日历视图。
      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日历').last);
      await tester.pumpAndSettle();

      // 打开显示设置。
      await tester.tap(find.byKey(const Key('calendar-display-settings')));
      await tester.pumpAndSettle();

      expect(find.text('颜色'), findsOneWidget);
      expect(find.text('按优先级'), findsOneWidget);
      expect(find.text('按清单'), findsOneWidget);
      expect(find.text('按标签'), findsOneWidget);

      // 选「按清单」→ 抽屉即回（RadioGroup onChanged pop）。
      await tester.tap(find.byKey(const Key('calendar-color-by-list')));
      await tester.pumpAndSettle();

      // 偏好落库（saveCalendarDisplay 的 colorBy 键）。
      final saved = await repo.getCalendarDisplay();
      expect(saved.calendarColorBy, 'list');
    });

    testWidgets('重进日历：颜色轴回读为上次所选（跨会话）', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = fixture.container.read(taskViewActionRepositoryProvider)!;
      await fixture.container
          .read(taskRepositoryProvider)!
          .create(listId: TodoVisualFixture.inboxListId, title: '种子任务');
      await repo.saveCalendarDisplay(
        viewMode: 'month',
        showCompletedTasks: false,
        showHeatmap: false,
        colorBy: 'tag',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(
              body: TasksByListPage(
                initialListId: TodoVisualFixture.inboxListId,
                lockedListId: true,
                hideAppBar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日历').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar-display-settings')));
      await tester.pumpAndSettle();

      final group = tester.widget<RadioGroup<TimelineColorBy>>(
        find.byType(RadioGroup<TimelineColorBy>),
      );
      expect(group.groupValue, TimelineColorBy.tag);
    });

    testWidgets('非法档在仓储归一化为 priority（不抛错）', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      final repo = fixture.container.read(taskViewActionRepositoryProvider)!;
      await repo.saveCalendarDisplay(
        viewMode: 'month',
        showCompletedTasks: false,
        showHeatmap: false,
        colorBy: 'hacked',
      );
      expect((await repo.getCalendarDisplay()).calendarColorBy, 'priority');
    });
  });
}
