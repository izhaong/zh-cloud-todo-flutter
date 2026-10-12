import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》里矩阵 #23 还欠的两面：
/// - desktop 方式二 `:51`「右键单击任务，选择「添加子任务」。」
/// - mobile `:15`「你可以在输入完第一个子任务之后点击「纸飞机」图标完成创建，或者点击键盘左下角的
///   「换行」来完成创建当前子任务，并且可以继续创建第二个同级的子任务，如此往复。」
///   与 desktop tab `:56`「点击「Enter」来继续创建第二个同级的子任务，如此往复。」
///
/// 两个 tab 的页码都写在这份注释里，是因为这页是 `tabContainer [mobile|desktop]`：
/// 同一件事在两处各有一句，实现只有一份。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<AppDatabase> newDb() async =>
      AppDatabase.forTesting(NativeDatabase.memory());

  /// 收尾先拆树再把时间推过 SnackBar / 同步队列的去抖窗口，
  /// 否则报 "A Timer is still pending even after the widget tree was disposed."
  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  }

  Future<TodoTask> seedParent(
    AppDatabase db,
    SyncChangeQueue queue, {
    String title = '写周报',
  }) async {
    final list = await ListRepository(db, queue).create(name: '工作');
    return TaskRepository(db, queue).create(listId: list.id, title: title);
  }

  Future<List<TodoTask>> rowsOf(AppDatabase db) =>
      db.select(db.todoTasks).get();

  /// 直接在库里串父子关系：`reparentTask` 自己有「不能超过五级」的校验，
  /// 而这里要造的就是"已经到顶"的那棵树，所以绕过校验写 parentTaskId。
  Future<TodoTask> seedDeepChain(
    AppDatabase db,
    SyncChangeQueue queue, {
    required int levels,
  }) async {
    final list = await ListRepository(db, queue).create(name: '深层');
    TodoTask? previous;
    for (var i = 1; i <= levels; i++) {
      final task = await TaskRepository(
        db,
        queue,
      ).create(listId: list.id, title: 'L$i');
      if (previous != null) {
        await (db.update(db.todoTasks)..where((t) => t.id.equals(task.id)))
            .write(TodoTasksCompanion(parentTaskId: Value(previous.id)));
      }
      previous = task;
    }
    final repo = TaskRepository(db, queue);
    final deepest = await (db.select(
      db.todoTasks,
    )..where((t) => t.title.equals('L$levels'))).getSingle();
    // 种子的深度必须真的是 levels-1，否则第 6 条用例测的是另一件事。
    expect(await repo.depthOf(deepest.id), levels - 1);
    return deepest;
  }

  Future<TodoTask> pumpRow(
    WidgetTester tester, {
    required AppDatabase db,
    required SyncChangeQueue queue,
    required TodoTask task,
    Size viewport = const Size(1280, 900),
    double textScale = 1,
  }) async {
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.binding.setSurfaceSize(viewport);
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
                width: viewport.width,
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

  /// 把快速添加表按生产方式挂进一棵树（`parentTaskId` 决定它是"建子任务"那张还是主建表）。
  Future<void> pumpSheet(
    WidgetTester tester, {
    required AppDatabase db,
    required SyncChangeQueue queue,
    required String listId,
    String? parentTaskId,
    Size viewport = const Size(1280, 900),
    double textScale = 1,
  }) async {
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.binding.setSurfaceSize(viewport);
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
            body: TaskQuickAddSheet(listId: listId, parentTaskId: parentTaskId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeTitle(WidgetTester tester, String title) async {
    await tester.enterText(
      find.byKey(const Key('todo-quick-add-title-field')),
      title,
    );
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
  }

  Future<List<TodoTask>> childrenOf(AppDatabase db, String parentId) async =>
      (await rowsOf(db)).where((t) => t.parentTaskId == parentId).toList();

  group('右键任务 →「添加子任务」（desktop 方式二 :51）', () {
    testWidgets('右键菜单里有这一档，且排在「标签」之后', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final task = await seedParent(db, queue);
      await pumpRow(tester, db: db, queue: queue, task: task);

      await rightClickRow(tester);

      expect(
        find.byKey(const Key('todo-task-context-add-child')),
        findsOneWidget,
        reason: ':51 要的就是右键菜单里有这一档',
      );
      expect(find.text('标签'), findsOneWidget, reason: '既有那档不许被挤掉');
      expect(find.text('更多操作'), findsOneWidget);
      await settleTimers(tester);
    });

    testWidgets('点「添加子任务」弹出的是同一张建子任务的表（标题「新建子任务」）', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final task = await seedParent(db, queue);
      await pumpRow(tester, db: db, queue: queue, task: task);

      await rightClickRow(tester);
      await tester.tap(find.byKey(const Key('todo-task-context-add-child')));
      await tester.pumpAndSettle();

      expect(
        find.byType(TaskQuickAddSheet),
        findsOneWidget,
        reason: '与详情层 :13/:33 同一张表，不做第二个界面',
      );
      expect(find.text('新建子任务'), findsOneWidget);
      await settleTimers(tester);
    });

    testWidgets('已经到第 6 层的任务上点它 ⇒ 只给「已达最大嵌套层数」，不开表', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final deepest = await seedDeepChain(db, queue, levels: 6);
      final before = (await rowsOf(db)).length;
      await pumpRow(tester, db: db, queue: queue, task: deepest);

      await rightClickRow(tester);
      await tester.tap(find.byKey(const Key('todo-task-context-add-child')));
      await tester.pump();

      expect(
        find.byType(TaskQuickAddSheet),
        findsNothing,
        reason: '守卫要在开表之前，开了表再拒就是让人白填一遍',
      );
      expect(find.text('已达最大嵌套层数（5），无法继续添加子任务'), findsOneWidget);
      expect((await rowsOf(db)).length, before, reason: '被拒绝这一次不该留下任务');
      await settleTimers(tester);
    });
  });

  group('子任务连续创建（mobile :15 / desktop :56）', () {
    testWidgets('保存第一条后表还留着：标题清空、库里多一条同级、反馈说得出刚建的是哪条', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final parent = await seedParent(db, queue);
      await pumpSheet(
        tester,
        db: db,
        queue: queue,
        listId: parent.listId,
        parentTaskId: parent.id,
      );

      await typeTitle(tester, '第一步');
      await tapSave(tester);

      expect(
        find.byType(TaskQuickAddSheet),
        findsOneWidget,
        reason: ':15「可以继续创建第二个同级的子任务」= 这张表不能关',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('todo-quick-add-title-field')),
            )
            .controller!
            .text,
        isEmpty,
        reason: '标题不清空，下一次保存会把两条写成同一条',
      );
      final first = await childrenOf(db, parent.id);
      expect(first, hasLength(1));
      expect(first.single.title, '第一步');
      expect(
        find.text('已添加子任务「第一步」，可以继续输入下一个'),
        findsOneWidget,
        reason: '表还开着 ⇒ 没有"保存成功"那种关闭反馈，必须在这一行里给可见回执',
      );

      await typeTitle(tester, '第二步');
      await tapSave(tester);

      final both = await childrenOf(db, parent.id);
      expect(
        both.map((t) => t.title).toSet(),
        {'第一步', '第二步'},
        reason:
            '第二次保存必须真建第二条：`_savedTaskId` 没复位的话，第二次只会给第一条补提醒（反向探针 P-a 量到的就是这条）',
      );
      expect(both, hasLength(2));
      expect(both.every((t) => t.listId == parent.listId), isTrue);
      await settleTimers(tester);
    });

    testWidgets('键盘「换行」= 建一条并继续（:15 的「换行」、:56 的 Enter）', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final parent = await seedParent(db, queue);
      await pumpSheet(
        tester,
        db: db,
        queue: queue,
        listId: parent.listId,
        parentTaskId: parent.id,
      );

      await typeTitle(tester, '靠键盘建');
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();

      final created = await childrenOf(db, parent.id);
      expect(created, hasLength(1), reason: '换行那一下必须真的落库一条');
      expect(
        find.byType(TaskQuickAddSheet),
        findsOneWidget,
        reason: '建完还要能继续，所以表留着',
      );
      await settleTimers(tester);
    });

    testWidgets('建子任务时手选的优先级，连续建第二条不会被抹回默认', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final parent = await seedParent(db, queue);
      await pumpSheet(
        tester,
        db: db,
        queue: queue,
        listId: parent.listId,
        parentTaskId: parent.id,
      );

      // 优先级那格是 DropdownButtonFormField（它的 key 是 ValueKey(当前值)，会随值漂），
      // 所以按类型点整格：点标签文字会报 "hit test ... did not find the widget"
      // 那种 warnIfMissed 警告 —— 警告不阻断断言，一次"蹭对了"的点击随时能在下一轮变成没点到。
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(
        find.text('高'),
        findsOneWidget,
        reason: '菜单没开就是 0 命中；开出两个同名字段也是事故，先数一次再点',
      );
      await tester.tap(find.text('高'));
      await tester.pumpAndSettle();
      await typeTitle(tester, '重要的一');
      await tapSave(tester);
      await typeTitle(tester, '重要的二');
      await tapSave(tester);

      final both = await childrenOf(db, parent.id);
      expect(both, hasLength(2));
      expect(
        both.map((t) => t.priority).toSet(),
        {3},
        reason: '优先级是人在这张表上手选的，"如此往复"不包括把人刚选的值清掉',
      );
      await settleTimers(tester);
    });

    testWidgets('主建表（无 parentTaskId）保存后照旧关闭：这一句原文没提"如此往复"', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final parent = await seedParent(db, queue);
      await pumpSheet(tester, db: db, queue: queue, listId: parent.listId);

      await typeTitle(tester, '普通任务');
      await tapSave(tester);

      expect(
        find.byType(TaskQuickAddSheet),
        findsNothing,
        reason: '收集箱/清单的快速添加不能被本面顺手改成连续档',
      );
      final rows = await rowsOf(db);
      expect(rows.where((t) => t.title == '普通任务'), hasLength(1));
      expect(rows.where((t) => t.title == '普通任务').single.parentTaskId, isNull);
      await settleTimers(tester);
    });

    testWidgets('320px + 1.3 倍字号：连建两条不溢出、回执行查得到', (tester) async {
      final db = await newDb();
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final parent = await seedParent(db, queue, title: '长标题的父任务用来挤字号');
      await pumpSheet(
        tester,
        db: db,
        queue: queue,
        listId: parent.listId,
        parentTaskId: parent.id,
        viewport: const Size(320, 720),
        textScale: 1.3,
      );

      await typeTitle(tester, '窄屏里的第一条子任务标题稍微长一点');
      await tapSave(tester);

      expect(tester.takeException(), isNull, reason: '溢出就是缺陷，不能被吞');
      final feedback = find.byKey(const Key('todo-quick-add-feedback'));
      expect(
        feedback,
        findsOneWidget,
        reason: '这张表是 reverse 滚动，回执行被裁到视口外就连都查不到',
      );
      expect(
        tester.getRect(feedback).bottom,
        lessThanOrEqualTo(720),
        reason: '回执行必须在可见区内',
      );

      await typeTitle(tester, '第二条');
      await tapSave(tester);
      expect(tester.takeException(), isNull);
      expect(await childrenOf(db, parent.id), hasLength(2));
      await settleTimers(tester);
    });
  });

  group('详情层那条路没被抽函数弄坏', () {
    testWidgets('任务详情的「添加子任务」仍开同一张表', (tester) async {
      final fixture = await TodoVisualFixture.create();
      addTearDown(fixture.dispose);
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: themed(),
            home: Scaffold(
              body: TaskDetailPane(
                taskId: TodoVisualFixture.pinnedTaskId,
                embedded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byTooltip('添加子任务');
      // 详情正文是 ListView(children:) ⇒ 视口外的节点压根没建，只能"滚着找"。
      // 而 scrollUntilVisible 默认取 `find.byType(Scrollable)` 并要求它唯一：
      // 这棵树里嵌了并列层时不止一个 ⇒ 必须显式交 scrollable。
      // （上一版把它省略了，抛的是 Iterable.single —— 那句读起来像"入口不存在"，
      // 其实连入口有没有开始找都没判到，别把它当成缺口证据。）
      final scrollable = find
          .descendant(
            of: find.byType(TaskDetailPane),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(button, 200, scrollable: scrollable);
      expect(
        button,
        findsOneWidget,
        reason: ':13「进入任务详情页弹窗点击右上角「...」，选择「添加子任务」」的入口要在',
      );
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        find.byType(TaskQuickAddSheet),
        findsOneWidget,
        reason: ':13 与 :33 那两句走的还是这张表（守卫只是搬进了共享函数）',
      );
      await settleTimers(tester);
    });
  });
}
