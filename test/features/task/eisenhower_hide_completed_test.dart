import 'dart:async';

// 只借 Value：整包导入会让 isNull / isNotNull 与 matcher 撞名。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_workspace_header.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

/// 嘀嗒《02-功能指南/03-四象限/02-如何编辑四象限规则.md》`::132`
/// 「在四象限页面，点击右上角「...」- 隐藏已完成。」⇒ 入口在页面右上角「...」里，
/// 菜单项字面就是「隐藏已完成」。develop 现状是已完成被无条件丢掉（三处），
/// 所以本轮的真实增量是**能显示已完成**，不是把已有的开关换个地方放。
final _now = DateTime(2026, 6, 20, 12);

const _hideCompletedKey = Key('todo-quadrant-hide-completed');

TodoTask _task({
  required String id,
  bool completed = false,
  int priority = 0,
  DateTime? dueAt,
}) {
  return TodoTask(
    id: id,
    listId: '1',
    allDay: false,
    fixedTimezone: false,
    title: '任务 $id',
    completed: completed,
    cancelled: false,
    priority: priority,
    isPinned: false,
    sortOrder: 0,
    dueAt: dueAt,
    updatedAt: _now,
    createdAt: _now,
  );
}

/// 写偏好失败要回退并给可见提示 ⇒ 需要一个会抛的仓储。
class _ThrowingRepository extends TaskViewActionRepository {
  _ThrowingRepository(super.db, super.queue);

  @override
  Future<void> saveQuadrantDisplay({required bool showCompletedTasks}) async {
    throw Exception('离线写入失败');
  }
}

/// 偏好读取挂起时用户可能已经切过开关 ⇒ 用于验证迟到的旧值不回滚新状态。
class _SlowRepository extends TaskViewActionRepository {
  _SlowRepository(super.db, super.queue);

  final Completer<void> release = Completer<void>();

  @override
  Future<TaskWorkspacePreference> getQuadrantDisplay() async {
    await release.future;
    return const TaskWorkspacePreference(showCompletedTasks: false);
  }
}

/// 记录调用次数：置灰的那一项"点了没反应"只有计数能证明。
class _RecordingHeaderRepository extends TaskViewActionRepository {
  _RecordingHeaderRepository(super.db, super.queue);

  final List<bool> saved = [];

  @override
  Future<void> saveQuadrantDisplay({required bool showCompletedTasks}) async {
    saved.add(showCompletedTasks);
    await super.saveQuadrantDisplay(showCompletedTasks: showCompletedTasks);
  }
}

/// 象限格子自带 `ValueKey('quadrant-q1'..'q4')` ⇒ 按"某格子里有没有这条任务"下断言，
/// 不靠全树找文字（全树找会被别处的同名文字满足）。
Finder _inQuadrant(Quadrant quadrant, String title) {
  return find.descendant(
    of: find.byKey(ValueKey('quadrant-${quadrant.name}')),
    matching: find.text(title),
  );
}

Future<void> _pumpView({
  required WidgetTester tester,
  required List<TodoTask> tasks,
  bool showCompletedTasks = false,
  Size? surface,
  double textScale = 1.0,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: EisenhowerView(
              tasks: tasks,
              now: _now,
              showCompletedTasks: showCompletedTasks,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer? _lastContainer;

/// 收尾约定（同 `task_section_workspace_test.dart:87-90`）：先把页面从树上摘掉让 StreamBuilder 退订，
/// 再跑掉 Drift 关流时那个零延时定时器，最后关库。少这一步 fake_async 判"仍有定时器待触发"。
Future<void> _finishPage(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  _lastContainer?.dispose();
  _lastContainer = null;
  await tester.pump(Duration.zero);
  await db.close();
}

Future<void> _pumpPage({
  required WidgetTester tester,
  required TaskViewActionRepository? repository,
  required AppDatabase db,
  required List<TodoTask> tasks,
  bool? initialCompleted,
  String? selectedTaskId,
  ValueChanged<String>? onSelectionInvalidated,
  Size? surface,
  double textScale = 1.0,
  Object pageKey = 'a',
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final queue = SyncChangeQueue(db);
  final container = ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(TaskRepository(db, queue)),
      taskViewActionRepositoryProvider.overrideWithValue(repository),
      currentDateTimeProvider.overrideWithValue(() => _now),
    ],
  );
  // 同一个用例里第二次进页要先把上一个容器收掉，否则它会活到测试结束都没人释放。
  _lastContainer?.dispose();
  _lastContainer = container;
  // 换 key 强制重建：State 复用会让 initState 的偏好读取不再跑第二次，"恢复"这条路径根本不被执行。
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: Scaffold(
          body: TasksByListPage(
            key: ValueKey<Object>(pageKey),
            initialListId: '1',
            lockedListId: true,
            hideAppBar: true,
            initialCompleted: initialCompleted,
            selectedTaskId: selectedTaskId,
            onSelectionInvalidated: onSelectionInvalidated,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> _switchToQuadrant(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-view-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(TaskViewMode.eisenhower.label).last);
  await tester.pumpAndSettle();
}

Future<void> _openSortMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-sort-menu')));
  await tester.pumpAndSettle();
}

Future<void> _seedListAndTasks(AppDatabase db, List<TodoTask> tasks) async {
  await db
      .into(db.todoLists)
      .insert(
        TodoListsCompanion.insert(
          id: '1',
          name: '清单 1',
          updatedAt: _now,
          createdAt: _now,
        ),
      );
  for (final task in tasks) {
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: task.id,
            listId: task.listId,
            title: task.title,
            completed: Value(task.completed),
            cancelled: const Value(false),
            allDay: const Value(false),
            fixedTimezone: const Value(false),
            priority: Value(task.priority),
            isPinned: const Value(false),
            sortOrder: Value(task.sortOrder),
            dueAt: Value(task.dueAt),
            updatedAt: _now,
            createdAt: _now,
          ),
        );
  }
}

void main() {
  group('两道闸的取数规则（spec §三 2 方案 A）', () {
    test('清单没钉完成态时，隐藏开关说了算', () {
      expect(quadrantShowsCompleted(hideCompleted: true), isFalse);
      expect(quadrantShowsCompleted(hideCompleted: false), isTrue);
    });

    test('清单已钉完成态时以筛选为准，不再叠第二道闸（叠了就是空板）', () {
      // 筛「已完成」+ 四象限仍隐藏 ⇒ 象限全空，用户看到的是"筛选坏了"。
      expect(
        quadrantShowsCompleted(hideCompleted: true, listFilterCompleted: true),
        isTrue,
        reason: '清单筛出已完成、四象限又全隐藏，板子会空得没有解释',
      );
      expect(
        quadrantShowsCompleted(hideCompleted: true, listFilterCompleted: false),
        isTrue,
      );
    });
  });

  group('视图层', () {
    testWidgets('默认隐藏已完成（与 develop 现状一致，防回归）', (tester) async {
      await _pumpView(
        tester: tester,
        tasks: [
          _task(id: 'open'),
          _task(id: 'done', completed: true),
        ],
      );
      expect(find.text('任务 open'), findsOneWidget);
      expect(find.text('任务 done'), findsNothing);
    });

    testWidgets('打开显示后已完成落在 Q4，且未完成任务的象限归属一格都没动', (tester) async {
      final tasks = [
        _task(id: 'open'),
        _task(
          id: 'urgent-important',
          priority: 3,
          dueAt: DateTime(2026, 6, 20, 18),
        ),
        _task(id: 'done', completed: true),
      ];

      await _pumpView(tester: tester, tasks: tasks);
      expect(_inQuadrant(Quadrant.q4, '任务 done'), findsNothing);
      final beforeQ1 = _inQuadrant(Quadrant.q1, '任务 urgent-important');
      expect(beforeQ1, findsOneWidget);

      await _pumpView(tester: tester, tasks: tasks, showCompletedTasks: true);
      expect(
        _inQuadrant(Quadrant.q4, '任务 done'),
        findsOneWidget,
        reason: 'classifyEisenhower 的既有约定是已完成归 Q4（:375 注释），本轮不改它',
      );
      expect(
        _inQuadrant(Quadrant.q1, '任务 urgent-important'),
        findsOneWidget,
        reason: '显示已完成不能把未完成任务挪格子',
      );
      expect(_inQuadrant(Quadrant.q4, '任务 open'), findsOneWidget);
    });

    testWidgets('320px + 1.3 倍字号：显示已完成这一档不溢出，卡片读屏语义仍在', (tester) async {
      await _pumpView(
        tester: tester,
        tasks: [
          _task(id: 'open'),
          _task(id: 'done', completed: true),
          _task(
            id: 'urgent-important',
            priority: 3,
            dueAt: DateTime(2026, 6, 20, 18),
          ),
        ],
        showCompletedTasks: true,
        surface: const Size(320, 700),
        textScale: 1.3,
      );
      // 溢出在 widget 测试里以异常形式抛出 ⇒ 没有异常才算没溢出。
      expect(tester.takeException(), isNull);
      expect(find.text('任务 done'), findsOneWidget);
    });
  });

  group('入口与偏好（真实页面：右上角「...」）', () {
    testWidgets('菜单项只在四象限出现，其余视图没有它（正向对照：菜单确实展开了）', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      await _pumpPage(
        tester: tester,
        db: db,
        repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
        tasks: [],
      );

      await _openSortMenu(tester);
      expect(find.text('批量编辑'), findsOneWidget, reason: '列表视图下菜单没打开，负向断言不成立');
      expect(
        find.byKey(_hideCompletedKey),
        findsNothing,
        reason: '「隐藏已完成」是四象限这一面的开关，不该常驻共用菜单',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await _switchToQuadrant(tester);
      await _openSortMenu(tester);
      expect(find.text('批量编辑'), findsOneWidget);
      expect(
        find.byKey(_hideCompletedKey),
        findsOneWidget,
        reason: '嘀嗒 `:132` 写在四象限页面右上角「...」里',
      );
      await _finishPage(tester, db);
    });

    testWidgets('点一次「隐藏已完成」：已完成进格子，偏好落库并登记 outbox', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final queue = SyncChangeQueue(db);
      final repository = _RecordingHeaderRepository(db, queue);
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      await _pumpPage(
        tester: tester,
        db: db,
        repository: repository,
        tasks: [],
      );
      await _switchToQuadrant(tester);
      expect(find.text('任务 done'), findsNothing);

      await _openSortMenu(tester);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();

      expect(
        _inQuadrant(Quadrant.q4, '任务 done'),
        findsOneWidget,
        reason: '菜单挂上了但显示没跟着变，就是换皮零增量',
      );
      expect(repository.saved, [true]);
      final queued = await db.select(db.todoSyncChanges).get();
      // 「切到四象限」那一下已经写过一条 task_view 偏好并入了队 ⇒ 整表计数不是判据，
      // 只数这一面自己那条（按 payload 里的 sourceType 认）。
      expect(
        queued.where((row) => row.payloadJson.contains('quadrant_view')).length,
        1,
        reason: '离线优先链路：本地写与 outbox 同一事务',
      );
      await _finishPage(tester, db);
    });

    testWidgets('重进页面仍是上次的选择（读偏好，不回到默认）', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
      await _pumpPage(
        tester: tester,
        db: db,
        repository: repository,
        tasks: [],
        pageKey: 'first',
      );
      await _switchToQuadrant(tester);
      await _openSortMenu(tester);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();

      await _pumpPage(
        tester: tester,
        db: db,
        repository: repository,
        tasks: [],
        pageKey: 'second',
      );
      await _switchToQuadrant(tester);
      expect(
        _inQuadrant(Quadrant.q4, '任务 done'),
        findsOneWidget,
        reason: '开关状态没持久化，用户每次进来看不到已完成',
      );
      await _finishPage(tester, db);
    });

    testWidgets('清单已按完成态筛过：菜单项置灰、点它不写状态，且给得出原因', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final queue = SyncChangeQueue(db);
      final repository = _RecordingHeaderRepository(db, queue);
      await _seedListAndTasks(db, [_task(id: 'done', completed: true)]);
      await _pumpPage(
        tester: tester,
        db: db,
        repository: repository,
        tasks: [],
        initialCompleted: true,
      );
      await _switchToQuadrant(tester);

      expect(
        find.text('任务 done'),
        findsOneWidget,
        reason: '筛选要已完成、四象限又全隐藏的话，这里会空得没有解释',
      );

      await _openSortMenu(tester);
      expect(find.byKey(_hideCompletedKey), findsOneWidget);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();

      expect(repository.saved, isEmpty, reason: '置灰项点了不该产生一次写，也不该改状态');
      expect(
        find.textContaining('清单筛选'),
        findsWidgets,
        reason: '置灰必须说清为什么不能点，读屏才念得出原因',
      );
      await _finishPage(tester, db);
    });

    testWidgets('写偏好失败：回退开关并给可见提示，异常不外泄', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      await _pumpPage(
        tester: tester,
        db: db,
        repository: _ThrowingRepository(db, SyncChangeQueue(db)),
        tasks: [],
      );
      await _switchToQuadrant(tester);

      await _openSortMenu(tester);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();

      expect(
        _inQuadrant(Quadrant.q4, '任务 done'),
        findsNothing,
        reason: '没落库却停在"已显示"，下次进来就消失了',
      );
      expect(find.textContaining('隐藏已完成'), findsWidgets);
      expect(tester.takeException(), isNull);
      final rows = await db.select(db.todoViewPreferences).get();
      // 切视图本身就会落一行 task_view 偏好（既有行为）⇒ 判据只能是"没有象限那一行"。
      expect(rows.where((row) => row.sourceType == 'quadrant_view'), isEmpty);
      await _finishPage(tester, db);
    });

    testWidgets('偏好读取在途时用户已切换：迟到的旧值不回滚新状态', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      final repository = _SlowRepository(db, SyncChangeQueue(db));
      await _pumpPage(
        tester: tester,
        db: db,
        repository: repository,
        tasks: [],
      );
      await _switchToQuadrant(tester);

      await _openSortMenu(tester);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();
      expect(_inQuadrant(Quadrant.q4, '任务 done'), findsOneWidget);

      // 迟到的读结果（showCompletedTasks=false ⇒ 隐藏）此时才落地。
      repository.release.complete();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        _inQuadrant(Quadrant.q4, '任务 done'),
        findsOneWidget,
        reason: '先发的读请求后到，把用户刚做的选择盖掉了',
      );
      await _finishPage(tester, db);
    });

    testWidgets('未配置仓储时开关仍然生效，只是不持久化，也不崩', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      await _pumpPage(tester: tester, db: db, repository: null, tasks: []);
      await _switchToQuadrant(tester);

      await _openSortMenu(tester);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();

      expect(_inQuadrant(Quadrant.q4, '任务 done'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final rows = await db.select(db.todoViewPreferences).get();
      // 切视图本身就会落一行 task_view 偏好（既有行为）⇒ 判据只能是"没有象限那一行"。
      expect(rows.where((row) => row.sourceType == 'quadrant_view'), isEmpty);
      await _finishPage(tester, db);
    });

    testWidgets('选中态失效判定跟着同一把尺：显示已完成期间不该把选中的已完成任务报成失效', (tester) async {
      // 这是 spec §二 1 数的第 3 处硬丢（宿主 `visibleTasks` 那层）。
      // 摘掉它的判据由反向探针 P4 提供：改回"一律丢已完成"时，第三条 expect 会红。
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      final invalidated = <String>[];
      await _pumpPage(
        tester: tester,
        db: db,
        repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
        tasks: const [],
        selectedTaskId: 'done',
        onSelectionInvalidated: invalidated.add,
      );
      await _switchToQuadrant(tester);
      expect(invalidated, [
        'done',
      ], reason: '默认隐藏时选中的已完成任务不在格子里，该报失效（develop 既有口径）');

      await _openSortMenu(tester);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();
      expect(_inQuadrant(Quadrant.q4, '任务 done'), findsOneWidget);
      expect(invalidated.length, 1, reason: '已经显示出来了，不该在此刻又报一次失效');

      await _openSortMenu(tester);
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();
      expect(invalidated.length, 2, reason: '重新隐藏后应再报一次；少了这条说明失效判定没跟着开关走');
      await _finishPage(tester, db);
    });

    testWidgets('入口是独立读屏节点，念得出「隐藏已完成」与当前档位', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [_task(id: 'open')]);
      await _pumpPage(
        tester: tester,
        db: db,
        repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
        tasks: [],
      );
      final semantics = tester.ensureSemantics();
      try {
        await _switchToQuadrant(tester);
        await _openSortMenu(tester);
        // 量的是带档位那句整体，不是"哪里出现过这几个字"：摘掉 label 就 0 命中。
        expect(
          find.bySemanticsLabel(RegExp('隐藏已完成，当前已隐藏')),
          findsOneWidget,
          reason: '只有文字没有档位，读屏用户不知道自己当前是隐藏还是显示',
        );
      } finally {
        semantics.dispose();
      }
      await _finishPage(tester, db);
    });

    testWidgets('320px + 1.3 倍字号：菜单项在四象限这一屏不溢出', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedListAndTasks(db, [
        _task(id: 'open'),
        _task(id: 'done', completed: true),
      ]);
      await _pumpPage(
        tester: tester,
        db: db,
        repository: TaskViewActionRepository(db, SyncChangeQueue(db)),
        tasks: [],
        surface: const Size(320, 700),
        textScale: 1.3,
      );
      await _switchToQuadrant(tester);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(EisenhowerView)),
        ).scale(10),
        closeTo(13, 0.001),
        reason: '档位没进到四象限自己的 context 就等于整条用例在 1.0 上排版',
      );
      await _openSortMenu(tester);
      expect(find.byKey(_hideCompletedKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finishPage(tester, db);
    });
  });

  group('组件层：置灰态本身', () {
    testWidgets('给了 blocked 原因时项不可点，没给时可点（同一条数据的正反对照）', (tester) async {
      var toggles = 0;
      Future<void> pump({String? hint}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: Scaffold(
              body: TaskWorkspaceHeader(
                title: '任务',
                taskCount: 1,
                mode: TaskViewMode.eisenhower,
                sort: TaskSort.smart,
                filterActive: false,
                onModeChanged: (_) {},
                onSortChanged: (_) {},
                onFilterPressed: () {},
                hideCompleted: true,
                hideCompletedHint: hint,
                onToggleHideCompleted: () => toggles++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('todo-sort-menu')));
        await tester.pumpAndSettle();
      }

      await pump();
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();
      expect(toggles, 1, reason: '没置灰时这一项必须点得动，否则整条路径是死的');

      toggles = 0;
      await pump(hint: '清单筛选已指定完成态');
      await tester.tap(find.byKey(_hideCompletedKey));
      await tester.pumpAndSettle();
      expect(toggles, 0);
      expect(find.text('清单筛选已指定完成态'), findsOneWidget);
    });
  });
}
