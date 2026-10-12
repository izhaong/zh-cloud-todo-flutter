import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/04-用标签管理任务.md》:61（desktop tab 方式二）
/// 「创建任务时输入「#」**或在任务详情中输入「#」**快速创建标签。」
///
/// :48 的移动端半面已在 `test/features/shell/quick_add_hash_tag_test.dart` 落地，
/// 词法本身在 `test/features/tag/hash_tag_input_test.dart`。
/// 这一层钉的是**详情面**：在任务详情的标题里打 `#名称` 并按保存，标签要真的落到那张任务上。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<AppDatabase> newDb() async =>
      AppDatabase.forTesting(NativeDatabase.memory());

  /// TaskRepository.create 会先 `_requireWritableList`（lib/state/repositories/task_repository.dart:651），
  /// 所以种子必须先有一张真清单，不能塞一个假 listId。
  Future<TodoTask> seedTask(AppDatabase db, SyncChangeQueue queue) async {
    final list = await ListRepository(db, queue).create(name: '工作');
    return TaskRepository(db, queue).create(listId: list.id, title: '写周报');
  }

  /// 起一个真的详情面板：库与同步队列走 provider 覆盖，其余按 develop 上的接线原样跑。
  Future<TodoTask> pumpDetail(
    WidgetTester tester, {
    required AppDatabase db,
    required SyncChangeQueue queue,
    double width = 1280,
    double textScale = 1.0,
  }) async {
    final task = await seedTask(db, queue);
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
        ],
        child: MaterialApp(
          theme: themed(),
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: Scaffold(
              body: TaskDetailPane(taskId: task.id, embedded: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return task;
  }

  /// 标题框按"当前值等于任务标题"定位，不去猜第几个 TextField。
  Finder titleField(String value) => find.descendant(
    of: find.byType(TaskDetailPane),
    matching: find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == value,
      description: '标题输入框（当前值 $value）',
    ),
  );

  Future<void> save(WidgetTester tester) async {
    final button = find.descendant(
      of: find.byType(TaskDetailPane),
      matching: find.text('保存'),
    );
    expect(button, findsWidgets, reason: '详情面里有「保存」这一档');
    await tester.tap(button.first);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// 收尾先拆树再把时间推过 SnackBar / 同步队列的去抖窗口，
  /// 否则报 "A Timer is still pending even after the widget tree was disposed."（实测两条计时器来源）。
  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  }

  Future<String> titleInDb(AppDatabase db, String taskId) async {
    final q = db.select(db.todoTasks)..where((t) => t.id.equals(taskId));
    final row = await q.getSingle();
    return row.title;
  }

  Future<List<String>> tagNamesOf(
    AppDatabase db,
    SyncChangeQueue queue,
    String taskId,
  ) async {
    final repo = TagRepository(db, queue);
    final ids = await repo.tagIdsOf(taskId);
    final all = await repo.getAll();
    return all.where((tag) => ids.contains(tag.id)).map((t) => t.name).toList()
      ..sort();
  }

  testWidgets('详情标题里的「#周会」变成标签，标题不落井号原文', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await pumpDetail(tester, db: db, queue: queue);

    await tester.enterText(titleField(task.title), '写周报 #周会');
    await save(tester);

    expect(await titleInDb(db, task.id), '写周报');
    expect(await tagNamesOf(db, queue, task.id), ['周会']);
    await settleTimers(tester);
  });

  testWidgets('已有同名标签就复用它，不新建第二条', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final known = await TagRepository(db, queue).create(name: '周会');
    final task = await pumpDetail(tester, db: db, queue: queue);

    await tester.enterText(titleField(task.title), '写周报 #周会');
    await save(tester);

    expect(await tagNamesOf(db, queue, task.id), ['周会']);
    await settleTimers(tester);
    expect((await TagRepository(db, queue).getAll()).length, 1);
    expect(known.id, isNotEmpty);
  });

  testWidgets('标题不含井号 ⇒ 不动标签表（回归护栏：现在也是绿的）', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await pumpDetail(tester, db: db, queue: queue);

    await tester.enterText(titleField(task.title), '写周报 明天再谈');
    await save(tester);

    expect(await titleInDb(db, task.id), '写周报 明天再谈');
    expect(await TagRepository(db, queue).getAll(), isEmpty);
    expect(await tagNamesOf(db, queue, task.id), isEmpty);
    await settleTimers(tester);
  });

  testWidgets('标签写入失败 ⇒ 任务仍保存成功，失败提示在详情内可见', (tester) async {
    final db = await newDb();
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final task = await seedTask(db, queue);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
          tagRepositoryProvider.overrideWithValue(
            FailingTagRepository(db, queue),
          ),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(body: TaskDetailPane(taskId: task.id, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(titleField(task.title), '写周报 #周会');
    await save(tester);

    // 已加载的数据不能被失败带走：标题的剥井号结果可以回退，但任务本体必须已保存。
    expect(await titleInDb(db, task.id), isNot(isEmpty));
    // ScaffoldMessenger 是排队播放：先播「已保存」4 秒，失败那条要等它退场才上屏。
    // 只 pumpAndSettle 不会推进这段假时钟 ⇒ 必须显式 pump 过隐藏时长。
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsWidgets, reason: '先确认「已保存」那条确实在播');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SnackBar, '标签保存失败，任务已保存'),
      findsOneWidget,
      reason: '失败提示要看得见，不能只进日志',
    );
    await settleTimers(tester);
    expect(tester.takeException(), isNull);
  });
}

/// 让「建标签」这一步抛错，专门证失败面：任务保存与标签落地是两次写，不能被并成一次静默早退。
class FailingTagRepository extends TagRepository {
  FailingTagRepository(super.db, super.queue);

  @override
  Future<TodoTag> create({
    required String name,
    String? color,
    String? parentId,
  }) async {
    throw StateError('离线建标签失败');
  }
}
