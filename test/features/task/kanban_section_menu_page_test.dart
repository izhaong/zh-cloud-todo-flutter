import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 列头「···」→ 重命名/删除 的**页面接线**测试。
///
/// 为什么单独要这一份：`KanbanView` 只交出回调，真正决定"点的是哪一列、叫的是哪个方法"的是
/// `TasksByListPage` 里那三行传参。把 `onSectionRename:` 与 `onSectionDelete:` 对调、
/// 或者回调里取了 `sections.first`，纯视图层的用例全都还是绿的 —— 这一格就白做了。
void main() {
  Future<void> pumpKanbanWithSections(WidgetTester tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    final now = DateTime.utc(2026, 7, 15, 9);
    Future<void> seedSection(String id, String name, int sortOrder) => fixture
        .database
        .into(fixture.database.todoTaskSections)
        .insert(
          TodoTaskSectionsCompanion.insert(
            id: id,
            listId: TodoVisualFixture.inboxListId,
            name: name,
            sortOrder: Value(sortOrder),
            updatedAt: now,
            createdAt: now,
          ),
        );
    await seedSection('sec-a', 'A组', 0);
    await seedSection('sec-b', 'B组', 1);
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((row) => row.id.equals(TodoVisualFixture.todayTaskId)))
        .write(const TodoTasksCompanion(sectionId: Value('sec-a')));
    await (fixture.database.update(fixture.database.todoTasks)..where(
          (row) => row.id.equals(TodoVisualFixture.secondaryTodayTaskId),
        ))
        .write(const TodoTasksCompanion(sectionId: Value('sec-b')));

    tester.view.physicalSize = TodoVisualViewports.wide;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const Key('todo-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TaskViewMode.kanban.label).last);
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String columnKey) async {
    await tester.tap(
      find
          .descendant(
            of: find.byKey(ValueKey(columnKey)),
            matching: find.byType(PopupMenuButton<String>),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('看板第二列点「重命名」打开的是该分组的改名框，初值就是它的名字', (tester) async {
    await pumpKanbanWithSections(tester);

    expect(find.text('A组'), findsWidgets);
    await openMenu(tester, 'col-sec-b');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    expect(find.text('重命名分组'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('todo-section-name-field')),
    );
    expect(field.initialValue, 'B组');
  });

  testWidgets('看板第二列点「删除」确认框点的是 B 组，不是第一个分组', (tester) async {
    await pumpKanbanWithSections(tester);

    await openMenu(tester, 'col-sec-b');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除“B组”？'), findsOneWidget);
    expect(find.text('删除“A组”？'), findsNothing);
  });
}
