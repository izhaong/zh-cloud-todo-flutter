import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/timeline_color.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/timeline_view.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/121 · 时间线「显示设置」＋任务条三轴着色（矩阵 #16 面 ⑦）。
///
/// 判据源《03-时间线视图：项目管理的必备神器.md》:95——
/// 「跟日历视图一样，可以在『显示设置』中根据清单、标签以及优先级的颜色显示」。
void main() {
  final now = DateTime(2026, 7, 15, 9);

  TodoTask task(String id, {int priority = 0, String listId = 'list-inbox'}) =>
      TodoTask(
        id: id,
        listId: listId,
        title: '任务-$id',
        completed: false,
        cancelled: false,
        allDay: false,
        fixedTimezone: false,
        timeMode: 0,
        priority: priority,
        isPinned: false,
        sortOrder: 0,
        updatedAt: now,
        createdAt: now,
        // 连续任务条只画有起止/截止的任务：给当天 10:00-12:00 的时间段
        // （与 task_workable_views_test 的 _viewTask 同形：dueAt 跟 endAt）。
        startAt: DateTime(now.year, now.month, now.day, 10),
        endAt: DateTime(now.year, now.month, now.day, 12),
        dueAt: DateTime(now.year, now.month, now.day, 12),
      );

  group('timelineTaskColor 轴解析（纯函数）', () {
    test('优先级轴返回 null：交给现有 priority switch（现状锁）', () {
      expect(
        timelineTaskColor(task('t1'), colorBy: TimelineColorBy.priority),
        isNull,
      );
    });

    test('按清单：hex 解析成色；无色（null/空）回退优先级轴（null）', () {
      final result = timelineTaskColor(
        task('t1'),
        colorBy: TimelineColorBy.list,
        listColorHexOf: (_) => '#FF0000',
      );
      expect(result, const Color(0xFFFF0000));

      expect(
        timelineTaskColor(
          task('t2'),
          colorBy: TimelineColorBy.list,
          listColorHexOf: (_) => null,
        ),
        isNull,
        reason: '清单没配色就回退优先级轴，不造灰色',
      );
      expect(
        timelineTaskColor(
          task('t3'),
          colorBy: TimelineColorBy.list,
          listColorHexOf: (_) => '',
        ),
        isNull,
      );
    });

    test('按标签：有 hex 解析成色；没挂色标签回退优先级轴（null，不是灰）', () {
      final result = timelineTaskColor(
        task('t1'),
        colorBy: TimelineColorBy.tag,
        tagColorHexOf: (_) => '#00FF00',
      );
      expect(result, const Color(0xFF00FF00));

      expect(
        timelineTaskColor(
          task('t2'),
          colorBy: TimelineColorBy.tag,
          tagColorHexOf: (_) => null,
        ),
        isNull,
        reason:
            'parseHexColor 对 null 给灰——那是「有 hex 解析不出」的兜底，'
            '没标签必须回退优先级轴',
      );
    });

    test('timelineColorByFromWire：未知档退回优先级', () {
      expect(timelineColorByFromWire(null), TimelineColorBy.priority);
      expect(timelineColorByFromWire('list'), TimelineColorBy.list);
      expect(timelineColorByFromWire('tag'), TimelineColorBy.tag);
      expect(timelineColorByFromWire('whatever'), TimelineColorBy.priority);
    });

    test('saveTimelineColorBy 落库回读；非法档写不进去', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
      const sourceKey = 'list:inbox';

      await repository.saveTimelineColorBy(
        sourceKey: sourceKey,
        colorBy: 'list',
      );
      expect(
        (await repository.getTaskWorkspacePreference(
          sourceKey: sourceKey,
        )).timelineColorBy,
        'list',
      );

      await repository.saveTimelineColorBy(
        sourceKey: sourceKey,
        colorBy: 'hacked',
      );
      expect(
        (await repository.getTaskWorkspacePreference(
          sourceKey: sourceKey,
        )).timelineColorBy,
        'priority',
        reason: '非法档写不进去（仓储归一化成 priority）',
      );
    });
  });

  group('TimelineView 显示设置与着色（widget）', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<TodoTask> tasks,
      TimelineColorBy colorBy = TimelineColorBy.priority,
      String? Function(TodoTask)? listColorHexOf,
      String? Function(TodoTask)? tagColorHexOf,
      Future<void> Function(TimelineColorBy)? onColorByChanged,
    }) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineView(
              tasks: tasks,
              now: now,
              scale: TimelineScale.week,
              colorBy: colorBy,
              listColorHexOf: listColorHexOf,
              tagColorHexOf: tagColorHexOf,
              onColorByChanged: onColorByChanged,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('有轴回调才有「显示设置」入口；无回调不渲染（默认用例不受影响）', (tester) async {
      await pump(tester, tasks: [task('a')], onColorByChanged: (_) async {});
      expect(
        find.byKey(const Key('timeline-display-settings')),
        findsOneWidget,
      );

      await pump(tester, tasks: [task('a')]);
      expect(find.byKey(const Key('timeline-display-settings')), findsNothing);
    });

    testWidgets('抽屉三档可选，选「按清单」回传该档', (tester) async {
      TimelineColorBy? picked;
      await pump(
        tester,
        tasks: [task('a')],
        colorBy: TimelineColorBy.priority,
        onColorByChanged: (mode) async => picked = mode,
      );

      await tester.tap(find.byKey(const Key('timeline-display-settings')));
      await tester.pumpAndSettle();
      expect(find.text('按优先级'), findsOneWidget);
      expect(find.text('按清单'), findsOneWidget);
      expect(find.text('按标签'), findsOneWidget);

      await tester.tap(find.byKey(const Key('timeline-color-by-list')));
      await tester.pumpAndSettle();
      expect(picked, TimelineColorBy.list);
    });

    testWidgets('按清单轴：有色的任务条用清单色', (tester) async {
      await pump(
        tester,
        tasks: [task('a')],
        colorBy: TimelineColorBy.list,
        listColorHexOf: (_) => '#FF0000',
        onColorByChanged: (_) async {},
      );
      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('timeline-continuous-bar-a')),
      );
      final decoration = box.decoration;
      // 描边是 accent 的 0.5 透明度：红 #FFFF0000 → 0x80FFFF00 前后字节序见断言。
      expect(
        (decoration as BoxDecoration).border,
        isA<Border>().having(
          (b) => (b.top).color,
          'top border color',
          const Color(0xFFFF0000).withValues(alpha: 0.5),
        ),
      );
    });

    testWidgets('按清单轴：无色回退优先级轴（priority=3 ⇒ 红）', (tester) async {
      await pump(
        tester,
        tasks: [task('a', priority: 3)],
        colorBy: TimelineColorBy.list,
        listColorHexOf: (_) => null,
        onColorByChanged: (_) async {},
      );
      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('timeline-continuous-bar-a')),
      );
      final decoration = box.decoration;
      expect(
        (decoration as BoxDecoration).border,
        isA<Border>().having(
          (b) => (b.top).color,
          'top border color',
          Colors.red.withValues(alpha: 0.5),
        ),
      );
    });
  });

  group('页面级：偏好跨会话回读（AC-3）', () {
    testWidgets('选「按标签」→ 重进页面仍是按标签', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = fixture.container.read(taskViewActionRepositoryProvider)!;
      await repo.saveTimelineColorBy(
        sourceKey: 'list:${TodoVisualFixture.inboxListId}',
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

      // 切到时间线视图，打开显示设置：当前档应是「按标签」。
      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('时间线').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timeline-display-settings')));
      await tester.pumpAndSettle();

      // RadioGroup 持有当前档（新 SDK 的推荐用法，雷达瓦片不再带 groupValue）。
      final group = tester.widget<RadioGroup<TimelineColorBy>>(
        find.byType(RadioGroup<TimelineColorBy>),
      );
      expect(group.groupValue, TimelineColorBy.tag);
    });
  });
}
