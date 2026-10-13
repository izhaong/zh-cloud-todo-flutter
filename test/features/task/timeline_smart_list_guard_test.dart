import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/122 · 时间线档对智能清单收敛（矩阵 #16 面 ⑧）。
///
/// 判据源《03-时间线视图：项目管理的必备神器.md》:10——
/// 「所有、收集箱、今天、最近7天 等智能清单不支持时间线视图」。
void main() {
  Future<void> pump(
    WidgetTester tester,
    TodoVisualFixture fixture, {
    String? initialListId,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: Scaffold(
            body: TasksByListPage(
              initialListId: initialListId,
              lockedListId: initialListId != null,
              hideAppBar: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<Set<String>> visibleViewModes(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-view-menu')));
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toSet();
    // 关掉菜单再断言，避免影响后续步骤。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    return labels;
  }

  testWidgets('智能清单：视图菜单不出现「时间线」（AC-1）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await pump(tester, fixture);

    final labels = await visibleViewModes(tester);
    expect(
      labels.contains(TaskViewMode.timeline.label),
      isFalse,
      reason: '嘀嗒 :10 明说智能清单不支持时间线',
    );
    // 其他档仍在（不是把菜单清空）。
    expect(labels.contains(TaskViewMode.list.label), isTrue);
  });

  testWidgets('真实清单：视图菜单有「时间线」（AC-2）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    // 先建一条任务把收集箱落库，再切到清单工作区。
    final repo = fixture.container.read(taskRepositoryProvider)!;
    await repo.create(listId: TodoVisualFixture.inboxListId, title: '种子任务');
    await pump(tester, fixture, initialListId: TodoVisualFixture.inboxListId);

    final labels = await visibleViewModes(tester);
    expect(labels.contains(TaskViewMode.timeline.label), isTrue);
  });

  testWidgets('偏好把智能清单落在 timeline ⇒ 恢复成列表（AC-3）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    // 智能清单工作区的 sourceKey 是 `smart:all`（见 _viewPreferenceSourceKey）；
    // 另一台设备把它的 viewType 留在 timeline。直接写偏好行模拟。
    final db = fixture.database;
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'smart-all-pref',
            sourceType: 'task_view',
            sourceKey: 'smart:all',
            valueJson:
                '{"sourceType":"task_view","sourceKey":"smart:all",'
                '"viewType":"timeline","valueJson":"{}"}',
            updatedAt: DateTime(2026, 7, 15),
            createdAt: DateTime(2026, 7, 15),
          ),
        );
    await pump(tester, fixture);

    // 恢复侧应退回列表档而不是停在 timeline：时间线专属的时间比例选择器
    // 不该出现（列表工作区没有它）。
    expect(find.byKey(const Key('timeline-scale-selector')), findsNothing);
  });
}
