import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/kanban_view.dart';

void main() {
  testWidgets('看板拖到进行中列会请求共享任务写操作', (tester) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final task = TodoTask(
      id: 'task-1',
      listId: 'list-inbox',
      title: '待移动任务',
      completed: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      updatedAt: now,
      createdAt: now,
    );
    (String, int, bool)? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: [task],
            onTaskMove: (moved, priority, completed) async {
              request = (moved.id, priority, completed);
            },
          ),
        ),
      ),
    );

    final source = find.text('待移动任务');
    final target = find.text('空').first;
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(request, ('task-1', 1, false));
  });
}
