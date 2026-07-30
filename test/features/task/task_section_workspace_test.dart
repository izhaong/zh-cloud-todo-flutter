import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_section_repository.dart';

void main() {
  testWidgets('真实清单展示 Section 并可从工作区新建分组', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime(2026, 7, 30);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-a',
            name: '工作',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final queue = SyncChangeQueue(db);
    final taskRepository = TaskRepository(db, queue);
    final sectionRepository = TaskSectionRepository(db, queue);
    final section = await sectionRepository.create(
      listId: 'list-a',
      name: '本周',
    );
    await taskRepository.create(
      listId: 'list-a',
      sectionId: section.id,
      title: '完成周报',
    );
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepository),
        taskSectionRepositoryProvider.overrideWithValue(sectionRepository),
        currentDateTimeProvider.overrideWithValue(() => now),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: Scaffold(
            body: TasksByListPage(
              initialListId: 'list-a',
              lockedListId: true,
              hideAppBar: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('todo-section-manager')), findsOneWidget);
    expect(find.byKey(const Key('todo-section-create')), findsOneWidget);
    expect(find.text('本周'), findsNWidgets(2));
    expect(find.text('完成周报'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-section-create')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const Key('todo-section-name-field')),
      '下周',
    );
    await tester.tap(find.byKey(const Key('todo-section-name-confirm')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('下周'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await tester.pump(Duration.zero);
    await db.close();
  });
}
