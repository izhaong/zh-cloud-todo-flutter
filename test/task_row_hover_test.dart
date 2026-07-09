import 'package:flutter/gestures.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  testWidgets('desktop hover reveals more and drag actions', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-1',
            listId: 'list-1',
            title: '任务',
            updatedAt: DateTime(2026, 7, 8, 9),
            createdAt: DateTime(2026, 7, 8, 9),
          ),
        );
    final task = await db.select(db.todoTasks).getSingle();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tagRepositoryProvider.overrideWith((ref) => null),
        taskRepositoryProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TaskRowHost(
              task: task,
              desktopMode: true,
              enableSwipeGestures: false,
              reorderIndex: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('更多'), findsNothing);
    expect(find.byTooltip('拖动排序'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(TaskRowHost)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('更多'), findsOneWidget);
    expect(find.byTooltip('拖动排序'), findsOneWidget);
  });
}
