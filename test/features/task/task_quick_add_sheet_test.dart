import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_capture_defaults_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 收集默认值这一步直接抛：用来打 `catch (_)` 那条通用失败分支。
class _BrokenDefaultsRepository extends TaskCaptureDefaultsRepository {
  _BrokenDefaultsRepository(super.db, super.queue);

  @override
  Future<TaskCaptureDefaults> get() async {
    throw Exception('本地数据库被占用');
  }
}

/// 「这次点击没有发起写入」只能钉在**调用边界**上。
///
/// 查数据库（有没有空标题行、outbox 有没有多行）是假判据：`TaskRepository.create`
/// 自己在进事务前就对空标题抛 `ArgumentError`，所以摘掉弹窗里的早退守卫后，
/// 那两条断言依然绿 —— 它们咬不住 #292 要挡的那个回归。
class _RecordingTaskRepository extends TaskRepository {
  _RecordingTaskRepository(AppDatabase db) : super(db, SyncChangeQueue(db));

  final List<String> createCalls = <String>[];

  @override
  Future<TodoTask> create({
    required String listId,
    required String title,
    String? sectionId,
    String? description,
    int priority = 0,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? dueAt,
    bool allDay = false,
    String? timeZone,
    bool fixedTimezone = false,
    int? timeMode,
    String? parentTaskId,
    bool isPinned = false,
  }) async {
    createCalls.add(title);
    throw StateError('被早退守卫挡住的点击不应走到 create');
  }
}

void main() {
  /// 提示必须落在弹窗自己的子树里：生产里弹窗是 `showModalBottomSheet` 的一层路由，
  /// 挂在根 `ScaffoldMessenger` 上的 SnackBar 会被弹窗自己盖住（等于没有反馈）。
  /// 裸 `find.text` 钉不住这条 —— SnackBar 也在同一棵树里。
  Finder sheetMessage(Pattern text) {
    return find.descendant(
      of: find.byKey(const Key('todo-quick-add-sheet')),
      matching: find.textContaining(text),
      matchRoot: true,
    );
  }

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
    expect(
      sheetMessage('父任务必须属于同一清单'),
      findsOneWidget,
      reason: '原因得显示在弹窗自己的可见区域，不能交给会被弹窗盖住的 SnackBar',
    );
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

  testWidgets('非业务异常（读默认值就炸）也要在弹窗内说清，并且不关弹窗', (tester) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        taskCaptureDefaultsRepositoryProvider.overrideWith(
          (ref) => _BrokenDefaultsRepository(
            database,
            ref.watch(syncChangeQueueProvider)!,
          ),
        ),
      ],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskQuickAddSheet(listId: TodoVisualFixture.inboxListId),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '失败时不该丢的标题');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      find.byType(TaskQuickAddSheet),
      findsOneWidget,
      reason: '保存失败不能把用户正在填的表单关掉',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '失败时不该丢的标题',
    );
    expect(
      sheetMessage('保存任务失败，请稍后重试'),
      findsOneWidget,
      reason: '通用失败分支同样必须落在弹窗内；摘回 SnackBar 这条用例要红',
    );
    // 抛点在 create 之前，所以这条恒真：它只兜「异常没顺路建出任务」，
    // 失败提示本身的咬合力来自上面那条按 key 的断言，不来自这里。
    expect(
      await (fixture.database.select(
        fixture.database.todoTasks,
      )..where((row) => row.title.equals('失败时不该丢的标题'))).get(),
      isEmpty,
    );
  });

  testWidgets('生产形态（showModalBottomSheet + 键盘 + 320×568）：失败提示落在键盘上方', (
    tester,
  ) async {
    // 前两条泵的是 Scaffold.body，只证明了「在子树里」这一层结构约束。
    // 反馈行是 Column 的最后一个子节点，弹窗不滚动时溢出正好裁掉它 ⇒ 必须按生产拓扑量一次。
    // 取最坏内容：1.3 倍字体 + 标题命中 NLP（多一行「已识别截止时间」）+ 多一行反馈。
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        taskCaptureDefaultsRepositoryProvider.overrideWith(
          (ref) => _BrokenDefaultsRepository(
            database,
            ref.watch(syncChangeQueueProvider)!,
          ),
        ),
      ],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => const TaskQuickAddSheet(
                    listId: TodoVisualFixture.inboxListId,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '明天 15 点交报告');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final feedback = find.byKey(const Key('todo-quick-add-feedback'));
    expect(
      find.textContaining('已识别截止时间'),
      findsOneWidget,
      reason: '最坏内容（多一行 NLP 识别提示）必须真的在树里，否则这条量的是更短的弹窗',
    );
    expect(feedback, findsOneWidget, reason: 'plan.md 把这条 key 当契约点名，断言必须直接按它找');
    expect(tester.takeException(), isNull, reason: '弹窗排版溢出会正好裁掉最后一行反馈');
    final rect = tester.getRect(feedback);
    expect(
      rect.bottom,
      lessThanOrEqualTo(568 - 260 + 0.5),
      reason: '反馈必须落在键盘上方的可见区，被键盘或屏幕底边盖住等于没有反馈',
    );
  });

  testWidgets('未登录点保存要说「请先登录」，不能静默吞掉这一次点击', (tester) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        taskRepositoryProvider.overrideWithValue(null),
      ],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskQuickAddSheet(listId: TodoVisualFixture.inboxListId),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '未登录时敲的标题');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      sheetMessage('请先登录'),
      findsOneWidget,
      reason:
          '措辞与同文件 _addFromTemplate 的未登录分支同源；摘掉这句 _report 这条用例必须红（Issue #292）',
    );
    expect(
      find.byType(TaskQuickAddSheet),
      findsOneWidget,
      reason: '没保存成功不能关弹窗，否则用户敲的标题直接蒸发',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '未登录时敲的标题',
    );
    expect(
      await (fixture.database.select(
        fixture.database.todoTasks,
      )..where((row) => row.title.equals('未登录时敲的标题'))).get(),
      isEmpty,
      reason: 'populated 夹具本来就有任务，只能按这一条标题查有没有多出空写',
    );
  });

  testWidgets('空标题点保存：提示落在标题框自己下面，且不发任何写请求', (tester) async {
    // 生产拓扑 + 1.3 倍字体：errorText 会给标题框再加一行，必须量它是否被键盘/底边裁掉。
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    late _RecordingTaskRepository recorder;
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) {
        recorder = _RecordingTaskRepository(database);
        return [taskRepositoryProvider.overrideWithValue(recorder)];
      },
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => const TaskQuickAddSheet(
                    listId: TodoVisualFixture.inboxListId,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.errorText,
      '请输入任务标题',
      reason: '嘀嗒是「空标题不可提交」而不是「点了没反应」；提示归表单自己，不占反馈行',
    );
    expect(
      recorder.createCalls,
      isEmpty,
      reason: '被早退守卫挡住的那次点击不该触达仓库；查数据库是假判据（见 _RecordingTaskRepository 注释）',
    );
    // `sheetMessage` 只证「在弹窗这棵子树里」，而 errorText 也在那棵树里 ⇒ 按文本判不出它落在哪一行。
    // 所以这里改成按 key 判「反馈行根本没出现」。
    expect(
      find.byKey(const Key('todo-quick-add-feedback')),
      findsNothing,
      reason: '反馈行留给「保存失败/请先登录」这类结果提示，校验态不往那里挤',
    );
    expect(find.byType(TaskQuickAddSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    final error = find.text('请输入任务标题');
    // 反向滚动视图是底对齐的：字体越大，顶部被裁得越狠，而 bottom 反而更小 ⇒ 只量 bottom 恒真。
    // 必须整矩形钉在「键盘以上」才算看得见。
    const visibleAboveKeyboard = Rect.fromLTRB(0, 0, 320, 568 - 260);
    final errorRect = tester.getRect(error);
    expect(
      visibleAboveKeyboard.contains(errorRect.topLeft) &&
          visibleAboveKeyboard.contains(errorRect.bottomRight),
      isTrue,
      reason: '多出来的这行要整行看得见，被键盘或视口上沿裁掉等于没提示（实测 $errorRect）',
    );

    await tester.enterText(find.byType(TextField), '补上标题');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.errorText,
      isNull,
      reason: '校验态要在下一次输入时清掉，否则会一直挂着',
    );
  });
}
