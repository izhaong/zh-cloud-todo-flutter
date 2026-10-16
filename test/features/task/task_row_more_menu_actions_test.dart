import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/features/tag/batch_tag_picker_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// FL #604：`task_row_host.dart` 的 `_showMoreMenu`（桌面右键「更多操作」弹出那张表）
/// 里原本有**四颗只 `Navigator.pop`、不写库的死钮**：
/// 「删除」「移动到清单」「设置提醒」「编辑标签」。
/// 用户点开它们看到的是「菜单关了，什么都没发生」。
///
/// 这四条要的行为在左滑动作表里已经各自实现过，所以修法是**转调同一份实现**，
/// 不是新造第二份口径。本文件逐条量「点下去真的写了库」。
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

  /// 收尾先拆树再把时间推过 SnackBar / 同步队列去抖窗口，
  /// 否则报 "A Timer is still pending even after the widget tree was disposed."
  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  }

  /// 打开这张表：桌面档的「更多」按钮是**悬停才出现**的
  /// （见 `task_row_hover_test.dart`：不悬停 byTooltip('更多') 找不到）。
  Future<void> openMoreMenu(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(TaskRowHost)));
    await tester.pumpAndSettle();
    addTearDown(mouse.removePointer);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
  }

  Future<TodoTask> pumpRow(
    WidgetTester tester, {
    required AppDatabase db,
    required SyncChangeQueue queue,
    List<TodoList>? lists,
  }) async {
    final task = await seed(db, queue);
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
          if (lists != null)
            listsStreamProvider.overrideWith((ref) => Stream.value(lists)),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1280,
                // 真机时序：上层（侧栏等）已订阅 `listsStreamProvider`，
                // 所以 `_pickSwipeTargetList` 里那次 `ref.read` 能拿到值。
                // 单测没有那层 ⇒ 显式 watch 一次来预热，见下方 `_prewarmLists`。
                child: _prewarmLists(
                  child: TaskRowHost(task: task, desktopMode: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return task;
  }

  testWidgets('「更多操作」表里的四颗钮都带得动的 key（死钮回归哨）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await pumpRow(tester, db: db, queue: queue);

    await openMoreMenu(tester);

    // 这四条是 FL #604 点名的死钮；key 在 ⇒ 后面的用例能逐颗点。
    for (final key in [
      'todo-task-more-delete-${task.id}',
      'todo-task-more-move-list-${task.id}',
      'todo-task-more-reminder-${task.id}',
      'todo-task-more-tags-${task.id}',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: '缺 $key ⇒ 那颗钮没了');
    }
    await settleTimers(tester);
  });

  testWidgets('点「删除」真的删库（原为死钮）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await pumpRow(tester, db: db, queue: queue);

    await openMoreMenu(tester);
    await tester.tap(find.byKey(Key('todo-task-more-delete-${task.id}')));
    await tester.pumpAndSettle();

    // 删除先弹确认框：这是左滑删除同一份 `_confirmSwipeDelete`。
    expect(find.text('删除「写周报」？'), findsOneWidget, reason: '应复用左滑那条确认口径');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    final repo = TaskRepository(db, queue);
    expect(
      await repo.getById(task.id),
      isNull,
      reason: '确认后必须真的删掉；只关菜单不写库就是 FL #604 的症状',
    );
    await settleTimers(tester);
  });

  testWidgets('点「移动到清单」真的换清单（原为死钮）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    // 先把两份清单落库，再把同一个快照喂给 listsStreamProvider：
    // 表是在 `_pickSwipeTargetList` 里 `ref.read(...).valueOrNull` 取的，
    // 首次 read 一个 StreamProvider 只拿到 loading ⇒ 不喂就只剩硬编码「收集箱」。
    final task = await seed(db, queue);
    final source = await ListRepository(db, queue).getAll();
    final target = await ListRepository(db, queue).create(name: '个人');
    final lists = [...await ListRepository(db, queue).getAll()];
    expect(lists.map((l) => l.id), contains(target.id));
    expect(source.map((l) => l.id), contains(task.listId));

    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
          listsStreamProvider.overrideWith((ref) => Stream.value(lists)),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1280,
                // 真机时序：上层（侧栏等）已订阅 `listsStreamProvider`，
                // 所以 `_pickSwipeTargetList` 里那次 `ref.read` 能拿到值。
                // 单测没有那层 ⇒ 显式 watch 一次来预热，见下方 `_prewarmLists`。
                child: _prewarmLists(
                  child: TaskRowHost(task: task, desktopMode: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openMoreMenu(tester);
    await tester.tap(find.byKey(Key('todo-task-more-move-list-${task.id}')));
    await tester.pumpAndSettle();

    // 表项按 key 定位（`todo-task-swipe-move-target-<id>`），
    // 与左滑那条通道共用同一份实现。
    final targetTile = find.byKey(
      Key('todo-task-swipe-move-target-${target.id}'),
    );
    expect(
      targetTile,
      findsOneWidget,
      reason: '目标清单没出现在表里 ⇒ 这条通道没真的走 moveToList',
    );
    await tester.tap(targetTile);
    await tester.pumpAndSettle();

    final moved = await TaskRepository(db, queue).getById(task.id);
    expect(moved?.listId, target.id, reason: '选完目标清单必须落库；否则就是「菜单关了，什么都没发生」');
    await settleTimers(tester);
  });

  testWidgets('点「编辑标签」真的出选择器（原为死钮）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await pumpRow(tester, db: db, queue: queue);
    await TagRepository(db, queue).create(name: '评审');

    await openMoreMenu(tester);
    await tester.tap(find.byKey(Key('todo-task-more-tags-${task.id}')));
    await tester.pumpAndSettle();

    // 复用左滑/右键那条同一份 `_pickTags`：弹的是同一个选择器类型。
    expect(
      find.byType(BatchTagPickerSheet),
      findsOneWidget,
      reason: '要真的弹出标签选择器，不是关掉菜单',
    );
    await settleTimers(tester);
  });

  testWidgets('点「设置提醒」真的建一条提醒，而不是改截止时间（原为死钮）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await pumpRow(tester, db: db, queue: queue);
    final before = await TaskRepository(db, queue).getById(task.id);

    await openMoreMenu(tester);
    await tester.tap(find.byKey(Key('todo-task-more-reminder-${task.id}')));
    await tester.pumpAndSettle();

    // 日期 → 时间 → 确定，与详情页 ABSOLUTE 档同交互。
    // 日期选择器的确定键；用 byType(TextButton) 里最后一个「OK」，
    // 不依赖未导出的 dialog 类名。
    expect(find.text('OK'), findsWidgets, reason: '应先弹日期选择器');
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsWidgets, reason: '再弹时间选择器');
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    final reminders = await (db.select(
      db.todoReminders,
    )..where((t) => t.taskId.equals(task.id))).get();
    expect(reminders, isNotEmpty, reason: '「设置提醒」必须新建提醒；建不出东西就是死钮');
    final after = await TaskRepository(db, queue).getById(task.id);
    expect(after?.dueAt, before?.dueAt, reason: '本钮是提醒，不是改截止时间 —— 映射到改日期是错的语义');
    await settleTimers(tester);
  });
}

/// 预热 `listsStreamProvider`：`_pickSwipeTargetList` 用 `ref.read`（不订阅），
/// 首次 read 一个没人订阅的 StreamProvider 只会拿到 loading ⇒ `valueOrNull` 为 null，
/// 表里就只剩硬编码的「收集箱」。真机上上层已订阅，故这里补一次 watch 以对齐时序。
Widget _prewarmLists({required Widget child}) {
  return Consumer(
    builder: (context, ref, _) {
      ref.watch(listsStreamProvider);
      return child;
    },
  );
}
