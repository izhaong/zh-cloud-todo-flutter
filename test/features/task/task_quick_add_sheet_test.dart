import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';

import '../../support/todo_visual_fixture.dart';

void main() {
  testWidgets('跨清单父任务被拒绝时快速添加保留表单并显示原因', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    final now = fixture.fixedNow;
    await fixture.database
        .into(fixture.database.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'other-list-parent',
            listId: TodoVisualFixture.workListId,
            title: '其他清单父任务',
            updatedAt: now,
            createdAt: now,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskQuickAddSheet(
              listId: TodoVisualFixture.inboxListId,
              parentTaskId: 'other-list-parent',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '不应创建的子任务');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskQuickAddSheet), findsOneWidget);
    expect(find.text('父任务必须属于同一清单'), findsOneWidget);
    expect(
      await (fixture.database.select(
        fixture.database.todoTasks,
      )..where((row) => row.title.equals('不应创建的子任务'))).get(),
      isEmpty,
    );
    expect(
      await fixture.database.select(fixture.database.todoSyncChanges).get(),
      isEmpty,
    );
  });
}
