import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/tag/batch_tag_picker_sheet.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/04-用标签管理任务.md》:57（desktop tab 方式一）
/// 「右键单击任务，选择「标签」添加已有标签或创建新标签。」
///
/// 选择器复用 `BatchTagPickerSheet`（表内含「新建标签」一行，FL #493 那套），
/// 语义与详情 `_TagChips` 一致：应用 = `setTaskTags` 全量替换，所以表要预选当前已挂标签
/// （否则只勾一个新标签就会把旧标签静默清掉）。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<AppDatabase> newDb() async =>
      AppDatabase.forTesting(NativeDatabase.memory());

  Future<TodoTask> seed(AppDatabase db, SyncChangeQueue queue) async {
    final list = await ListRepository(db, queue).create(name: '工作');
    return TaskRepository(db, queue).create(listId: list.id, title: '写周报');
  }

  /// 收尾先拆树再把时间推过 SnackBar / 同步队列的去抖窗口，
  /// 否则报 "A Timer is still pending even after the widget tree was disposed."
  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  }

  Future<TodoTask> pump(
    WidgetTester tester, {
    required AppDatabase db,
    required SyncChangeQueue queue,
  }) async {
    final task = await seed(db, queue);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1280,
                child: TaskRowHost(task: task, desktopMode: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return task;
  }

  Future<void> rightClickRow(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(TaskRowHost));
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.addPointer();
    await mouse.moveTo(center);
    await tester.pump();
    await mouse.down(center);
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
  }

  testWidgets('桌面右键菜单里有「标签」一项（:57）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    await pump(tester, db: db, queue: queue);

    await rightClickRow(tester);
    expect(find.text('标签'), findsOneWidget);
    await settleTimers(tester);
  });

  testWidgets('点「标签」弹出选择器，当前已挂标签要预选中（全量替换语义的前提）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await seed(db, queue);
    final tagRepo = TagRepository(db, queue);
    final kept = await tagRepo.create(name: '评审');
    final other = await tagRepo.create(name: '杂项');
    await tagRepo.setTaskTags(task.id, [kept.id]);

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1280,
                child: TaskRowHost(task: task, desktopMode: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await rightClickRow(tester);
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.byType(BatchTagPickerSheet), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(Key('todo-batch-tag-${kept.id}')),
          )
          .value,
      isTrue,
      reason: '任务已挂的标签必须在表里预选中，否则应用会把旧标签静默清掉',
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(Key('todo-batch-tag-${other.id}')),
          )
          .value,
      isFalse,
    );
    await settleTimers(tester);
  });

  testWidgets('勾选并应用后任务标签真的换掉（setTaskTags 全量替换落库）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await seed(db, queue);
    final tagRepo = TagRepository(db, queue);
    final kept = await tagRepo.create(name: '评审');
    final other = await tagRepo.create(name: '杂项');
    await tagRepo.setTaskTags(task.id, [kept.id]);

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1280,
                child: TaskRowHost(task: task, desktopMode: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await rightClickRow(tester);
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('todo-batch-tag-${other.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('todo-batch-apply-tags')));
    await tester.pumpAndSettle();

    expect(find.byType(BatchTagPickerSheet), findsNothing);
    expect(
      await tagRepo.tagIdsOf(task.id),
      unorderedEquals([kept.id, other.id]),
    );
    await settleTimers(tester);
  });

  testWidgets('表内新建标签后应用，新标签挂到任务上（:57「或创建新标签」）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await seed(db, queue);
    final tagRepo = TagRepository(db, queue);

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1280,
                child: TaskRowHost(task: task, desktopMode: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await rightClickRow(tester);
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-batch-new-tag-input')),
      '新标',
    );
    await tester.tap(find.byKey(const Key('todo-batch-create-tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-apply-tags')));
    await tester.pumpAndSettle();

    final ids = await tagRepo.tagIdsOf(task.id);
    expect(ids, hasLength(1));
    final tag = await (db.select(
      db.todoTags,
    )..where((t) => t.id.equals(ids.single))).getSingle();
    expect(tag.name, '新标');
    await settleTimers(tester);
  });

  testWidgets('标签仓库没就绪时给当场可见的提示，不弹空表', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    await seed(db, queue);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagRepositoryProvider.overrideWithValue(null),
          taskRepositoryProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1280,
                child: TaskRowHost(
                  task: await (db.select(db.todoTasks)..limit(1)).getSingle(),
                  desktopMode: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await rightClickRow(tester);
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();

    expect(find.byType(BatchTagPickerSheet), findsNothing);
    expect(find.text('标签暂不可用，请稍后重试'), findsOneWidget);
    await settleTimers(tester);
  });
}
