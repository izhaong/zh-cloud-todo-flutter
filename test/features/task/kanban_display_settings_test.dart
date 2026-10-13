import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/kanban_view.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/board_preference_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/119 · 看板「显示设置」：宽度三档 + 「显示输入框」
/// （矩阵 #15 面 ⑧；嘀嗒《02-看板视图：分类管理任务》FAQ `:209`/`:213`）。
void main() {
  group('BoardViewPreference 显示设置持久化', () {
    Future<void> seedList(AppDatabase db, String id) async {
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: id,
              name: '清单-$id',
              updatedAt: DateTime(2026, 7, 15),
              createdAt: DateTime(2026, 7, 15),
            ),
          );
    }

    test('saveDisplaySettings 落库后 get 回读一致；saveLayout 不丢显示设置', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = BoardPreferenceRepository(db, SyncChangeQueue(db));
      await seedList(db, 'list-1');

      await repository.saveDisplaySettings(
        listId: 'list-1',
        columnWidth: BoardColumnWidth.large,
        showColumnInput: true,
      );
      final saved = await repository.get('list-1');
      expect(saved.columnWidth, BoardColumnWidth.large);
      expect(saved.showColumnInput, isTrue);

      // 只改列序的旧入口不得把显示设置冲回默认（历史上它整份覆写 JSON）。
      await repository.saveLayout(
        listId: 'list-1',
        orderedColumnIds: const ['doing', 'todo', 'urgent', 'archive'],
        collapsedColumnIds: const {'archive'},
      );
      final afterLayout = await repository.get('list-1');
      expect(afterLayout.orderedColumnIds.first, 'doing');
      expect(afterLayout.columnWidth, BoardColumnWidth.large);
      expect(afterLayout.showColumnInput, isTrue);
    });

    test('旧布局 JSON（无新键）读成默认档：中 + 不显示', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = BoardPreferenceRepository(db, SyncChangeQueue(db));
      await seedList(db, 'list-1');
      await repository.save(
        listId: 'list-1',
        groupDimension: 'PRIORITY',
        columnsJson:
            '{"order":["todo","doing","urgent","archive"],"collapsed":[]}',
      );
      final decoded = await repository.get('list-1');
      expect(decoded.columnWidth, BoardColumnWidth.medium);
      expect(decoded.showColumnInput, isFalse);
    });
  });

  group('KanbanView 列宽与「显示输入框」', () {
    TodoTask task(String id, {int priority = 0}) => TodoTask(
      id: id,
      listId: 'list-inbox',
      title: '任务-$id',
      completed: false,
      cancelled: false,
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      priority: priority,
      isPinned: false,
      sortOrder: 0,
      updatedAt: DateTime(2026, 7, 15, 9),
      createdAt: DateTime(2026, 7, 15, 9),
    );

    testWidgets('宽度三档改变列宽（200/260/320）', (tester) async {
      Future<double> columnWidthOf(BoardColumnWidth width) async {
        double measured = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KanbanView(
                tasks: [task('a')],
                listId: 'list-inbox',
                columnWidth: width,
              ),
            ),
          ),
        );
        await tester.pump();
        final sized = tester.widget<SizedBox>(
          find.byKey(const Key('col-todo')),
        );
        measured = sized.width!;
        return measured;
      }

      expect(
        await columnWidthOf(BoardColumnWidth.small),
        BoardColumnWidth.small.columnWidth,
      );
      expect(
        await columnWidthOf(BoardColumnWidth.medium),
        BoardColumnWidth.medium.columnWidth,
      );
      expect(
        await columnWidthOf(BoardColumnWidth.large),
        BoardColumnWidth.large.columnWidth,
      );
    });

    testWidgets('显示输入框：输入行可见且能打字（提交走真实仓储，页面级测试覆盖）', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            home: Scaffold(
              body: KanbanView(
                tasks: [task('a', priority: 2)],
                listId: TodoVisualFixture.inboxListId,
                showColumnInput: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final field = find.byKey(const Key('kanban-inline-add-urgent'));
      expect(field, findsOneWidget);
      expect(field, findsOneWidget);
      await tester.enterText(field, '看板新任务');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 真实落库：priority 列（紧急=2）带档位建任务。
      final tasks = await (fixture.database.select(
        fixture.database.todoTasks,
      )..where((row) => row.title.equals('看板新任务'))).get();
      expect(tasks, hasLength(1));
      expect(tasks.single.priority, 2);
      expect(tasks.single.listId, TodoVisualFixture.inboxListId);
    });

    testWidgets('未开启「显示输入框」：不出输入行', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KanbanView(
              tasks: [task('a')],
              listId: 'list-inbox',
              showColumnInput: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('看板显示设置入口与保存（页面级）', () {
    testWidgets('看板模式「排序与批量编辑」菜单里有「显示设置」，保存后偏好落库', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
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

      // 先建一条任务：fixture 的「收集箱」清单是懒创建的（首条任务才落库），
      // 看板偏好的写入要求清单已存在。
      final repo = fixture.container.read(taskRepositoryProvider)!;
      await repo.create(listId: TodoVisualFixture.inboxListId, title: '种子任务');

      // 切到看板视图。
      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('看板').last);
      await tester.pumpAndSettle();

      // 打开「排序与批量编辑」菜单 →「显示设置」。
      await tester.tap(find.byKey(const Key('todo-sort-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-board-display-settings')));
      await tester.pumpAndSettle();

      // 选「大」并打开「显示输入框」，保存。
      await tester.tap(find.text('大'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('board-show-column-input')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('board-display-settings-save')));
      await tester.pumpAndSettle();

      final prefs = await fixture.container
          .read(boardPreferenceRepositoryProvider)!
          .get(TodoVisualFixture.inboxListId);
      expect(prefs.columnWidth, BoardColumnWidth.large);
      expect(prefs.showColumnInput, isTrue);
    });
  });
}
