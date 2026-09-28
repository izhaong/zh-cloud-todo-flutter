import 'dart:async';

// 只借 Value：整包导入会让 isNull / isNotNull 与 matcher 撞名。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/eisenhower_view.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

/// 嘀嗒《02-功能指南/03-四象限/02-如何编辑四象限规则.md》拖动那一面：
/// `:25`「拖动调整任务的象限时，任务的优先级也会发生对应的变化」（组合1 只改优先级）、
/// `:44`「拖动任务调整任务的象限时，任务的时间和优先级也会发生对应的变化」（组合2 改两栏）；
/// 具体取值由 `:39`「“今天”、“高优先级”⇒重要且紧急」与
/// `:40`「“1个月后”、“低优先级”⇒不重要不紧急」这两条例子给出。
const _dragSemantics = '拖动调整象限';

final _now = DateTime(2026, 6, 20, 12);

TodoTask _task({
  required String id,
  required int priority,
  DateTime? dueAt,
  int? serverId,
}) {
  return TodoTask(
    id: id,
    serverId: serverId,
    listId: '1',
    allDay: false,
    fixedTimezone: false,
    title: '任务 $id',
    completed: false,
    cancelled: false,
    priority: priority,
    isPinned: false,
    sortOrder: 0,
    dueAt: dueAt,
    updatedAt: _now,
    createdAt: _now,
  );
}

/// 落回原象限该不该发写请求，只有计数能证明。
class _RecordingRepository extends TaskViewActionRepository {
  _RecordingRepository(super.db, super.queue);

  final List<(String, int, DateTime?)> calls = [];
  final List<(String, int, DateTime?)> finished = [];
  bool failNext = false;
  Completer<void>? gate;

  @override
  Future<void> moveQuadrantTask(
    String taskId, {
    required int priority,
    DateTime? dueAt,
  }) async {
    calls.add((taskId, priority, dueAt));
    try {
      if (failNext) {
        failNext = false;
        throw Exception('离线写入失败');
      }
      final pending = gate;
      if (pending != null) {
        gate = null;
        await pending.future;
      }
      await super.moveQuadrantTask(taskId, priority: priority, dueAt: dueAt);
    } finally {
      finished.add((taskId, priority, dueAt));
    }
  }
}

/// 拖动落库是排队的 fire-and-forget，`pumpAndSettle` 不保证它已经跑完。
/// 只数帧不数真实时间：落不完就当场失败，不给"再多泵两下"留余地。
Future<void> _settleWrites(
  WidgetTester tester,
  _RecordingRepository repository,
) async {
  for (
    var i = 0;
    i < 40 && repository.finished.length < repository.calls.length;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(
    repository.finished.length,
    repository.calls.length,
    reason: '写操作链没跑完，后面的库内断言就没有意义',
  );
}

class _TestSessionController extends SessionController {
  @override
  TodoAuthSession? build() {
    return const TodoAuthSession(
      userId: 1,
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      tenantId: '1',
      mobile: '13800000000',
    );
  }
}

/// 清单行必须先有：`moveQuadrantTask` 走 `_requireWritableTask`，
/// 清单不存在时整笔写会抛（第一版就因此只拿到一条 snackbar，库内什么都没改）。
Future<AppDatabase> _memoryDbWithTask(
  WidgetTester tester, {
  required String taskId,
  required int priority,
  DateTime? dueAt,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
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
  await db
      .into(db.todoTasks)
      .insert(
        TodoTasksCompanion.insert(
          id: taskId,
          listId: '1',
          title: '任务 $taskId',
          priority: Value(priority),
          dueAt: Value(dueAt),
          updatedAt: _now,
          createdAt: _now,
        ),
      );
  return db;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<TodoTask> tasks,
  required TaskViewActionRepository? repository,
  QuadrantRuleDto? rule,
  Map<String, Set<int>> board = const {},
  bool provideBoard = true,
  Size? surface,
  double textScale = 1.0,
  Object scopeKey = 'a',
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final overrides = <Override>[
    taskViewActionRepositoryProvider.overrideWithValue(repository),
  ];
  if (rule != null) {
    overrides.addAll([
      sessionProvider.overrideWith(_TestSessionController.new),
      quadrantRulesProvider.overrideWith((ref) async => [rule]),
    ]);
    if (provideBoard) {
      overrides.add(
        quadrantBoardProvider(rule.id).overrideWith((ref) async => board),
      );
    }
  }
  await tester.pumpWidget(
    ProviderScope(
      // 同一个测试里换规则必须换 key：ProviderScope 只在容器创建那一次读 overrides，
      // 直接第二次 pumpWidget 会沿用旧容器，新 override 静默不生效（diag 实测）。
      key: ValueKey<Object>(scopeKey),
      overrides: overrides,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: EisenhowerView(tasks: tasks, now: _now),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 长按拖起再落到目标象限（看板用例 `task_workable_views_test.dart:42-50` 用的就是这套手势）。
Future<void> _dragToQuadrant(
  WidgetTester tester,
  String taskTitle,
  Quadrant target,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text(taskTitle).first),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(
    tester.getCenter(find.byKey(ValueKey('quadrant-${target.name}'))),
  );
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Finder _inQuadrant(Quadrant q, String title) => find.descendant(
  of: find.byKey(ValueKey('quadrant-${q.name}')),
  matching: find.text(title),
);

QuadrantRuleDto _rule(QuadrantRuleType type) => QuadrantRuleDto(
  id: 7,
  name: '规则 ${type.name}',
  type: type,
  isDefault: true,
);

void main() {
  group('quadrantDropPatch 纯函数（:25/:44 两套组合的差别）', () {
    test('组合1（象限→优先级）：只回写优先级，四档取自规则自己的键序 P3/P2/P1/P0', () {
      for (final (q, expected) in const [
        (Quadrant.q1, 3),
        (Quadrant.q2, 2),
        (Quadrant.q3, 1),
        (Quadrant.q4, 0),
      ]) {
        final patch = quadrantDropPatch(
          target: q,
          ruleType: QuadrantRuleType.priorityOnly,
          now: _now,
        );
        expect(patch, isNotNull, reason: '$q 该给得出回写值');
        expect(patch!.priority, expected, reason: '$q 的目标优先级不是规则键序里那一档');
        // :25 只说「优先级也会发生对应的变化」⇒ 时间一毫秒都不该被写。
        expect(patch.dueAt, isNull, reason: '$q 组合1 却写了 dueAt');
      }
    });

    test('组合2（象限→时间+优先级）：两栏一起写，取值照 :39/:40 的两条例子', () {
      final q1 = quadrantDropPatch(
        target: Quadrant.q1,
        ruleType: QuadrantRuleType.priorityTime,
        now: _now,
      )!;
      // :39「“今天”、“高优先级”⇒重要且紧急」
      expect(q1.priority, 3);
      expect(q1.dueAt!.day, _now.day, reason: '紧急档该落在“今天”');
      expect(q1.dueAt!.isAfter(_now), isTrue);
      expect(
        classifyEisenhower(
          _task(id: 'x', priority: q1.priority, dueAt: q1.dueAt),
          _now,
        ),
        Quadrant.q1,
        reason: '写出来的值应当就被判回 Q1，否则拖完会跳到别的象限',
      );

      final q4 = quadrantDropPatch(
        target: Quadrant.q4,
        ruleType: QuadrantRuleType.priorityTime,
        now: _now,
      )!;
      // :40「“1个月后”、“低优先级”⇒不重要不紧急」
      expect(q4.priority, 1);
      expect(q4.dueAt!.isAfter(_now.add(const Duration(days: 25))), isTrue);
      expect(
        classifyEisenhower(
          _task(id: 'y', priority: q4.priority, dueAt: q4.dueAt),
          _now,
        ),
        Quadrant.q4,
      );

      final q2 = quadrantDropPatch(
        target: Quadrant.q2,
        ruleType: QuadrantRuleType.priorityTime,
        now: _now,
      )!;
      final q3 = quadrantDropPatch(
        target: Quadrant.q3,
        ruleType: QuadrantRuleType.priorityTime,
        now: _now,
      )!;
      expect(q2.priority, 3);
      expect(q3.priority, 1);
      expect(q2.dueAt!.isAfter(q3.dueAt!), isTrue, reason: '不紧急那档的时间该更晚');
    });

    test('没有生效规则（本机分档）按组合2 回写，因为 classifyEisenhower 本身就是两轴', () {
      final patch = quadrantDropPatch(
        target: Quadrant.q1,
        ruleType: null,
        now: _now,
      )!;
      expect(patch.priority, 3);
      expect(patch.dueAt, isNotNull);
    });

    test('自定义规则不回写（源页本节没给拖动脉络）', () {
      expect(
        quadrantDropPatch(
          target: Quadrant.q1,
          ruleType: QuadrantRuleType.custom,
          now: _now,
        ),
        isNull,
      );
    });

    test('紧急档「当天」在一天里的任一时钟点都落在 classifyEisenhower 的 24h 窗口内', () {
      for (final h in [0, 8, 12, 23]) {
        for (final m in [0, 30, 59]) {
          final at = DateTime(2026, 6, 20, h, m);
          final due = quadrantDropPatch(
            target: Quadrant.q1,
            ruleType: QuadrantRuleType.priorityTime,
            now: at,
          )!.dueAt!;
          expect(
            !due.isAfter(at.add(const Duration(hours: 24))),
            isTrue,
            reason: 'now=$at 时写出的“今天”被判成不紧急：$due',
          );
        }
      }
    });

    test('1/31 这种日期加一个月不能掉回 24h 窗口（DateTime 会归一化，得验）', () {
      final at = DateTime(2026, 1, 31, 10);
      final due = quadrantDropPatch(
        target: Quadrant.q4,
        ruleType: QuadrantRuleType.priorityTime,
        now: at,
      )!.dueAt!;
      expect(
        due.isAfter(at.add(const Duration(hours: 24))),
        isTrue,
        reason: '归一化后不紧急档被压回窗口内：$due',
      );
      expect(due.isAfter(at), isTrue);
    });
  });

  testWidgets('组合2 拖到 Q1：落库改优先级与当天截止，并登记 outbox', (tester) async {
    final db = await _memoryDbWithTask(tester, taskId: 'task-1', priority: 0);
    final repository = _RecordingRepository(db, SyncChangeQueue(db));
    // priority 0 且无 dueAt ⇒ 本机分档落在 Q4。
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'task-1', priority: 0)],
    );
    expect(_inQuadrant(Quadrant.q4, '任务 task-1'), findsOneWidget);

    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q1);
    await _settleWrites(tester, repository);

    expect(repository.calls.length, 1);
    final row = await (db.select(
      db.todoTasks,
    )..where((r) => r.id.equals('task-1'))).getSingle();
    expect(row.priority, 3);
    expect(row.dueAt!.year, 2026);
    expect(row.dueAt!.day, 20);
    final queued = await db.select(db.todoSyncChanges).get();
    expect(queued.length, 1, reason: '离线优先链路：本地写与 outbox 同一事务');
  });

  testWidgets('组合1 拖到 Q2：只改优先级，dueAt 一毫秒都没动', (tester) async {
    final originalDue = DateTime(2026, 6, 20, 18);
    final db = await _memoryDbWithTask(
      tester,
      taskId: 'task-1',
      priority: 0,
      dueAt: originalDue,
    );
    final repository = _RecordingRepository(db, SyncChangeQueue(db));
    await _pump(
      tester,
      repository: repository,
      tasks: [
        _task(id: 'task-1', priority: 0, dueAt: originalDue, serverId: 101),
      ],
      rule: _rule(QuadrantRuleType.priorityOnly),
      board: const {
        'P0': {101},
      },
    );

    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q2);
    await _settleWrites(tester, repository);

    expect(repository.calls.single.$3, isNull, reason: '组合1 不该交回一个 dueAt');
    final row = await (db.select(
      db.todoTasks,
    )..where((r) => r.id.equals('task-1'))).getSingle();
    expect(row.priority, 2);
    expect(row.dueAt, originalDue);
  });

  testWidgets('降级态（组合1 规则但看板没加载）仍按 :25 只写优先级，不偷改 dueAt', (tester) async {
    // 交叉验证抓到的一例：第一版按"显示的是哪套"选回写式，
    // 看板未加载时显示退回本机两轴，于是组合1 规则下拖动会连带写出 dueAt。
    final originalDue = DateTime(2026, 6, 20, 18);
    final db = await _memoryDbWithTask(
      tester,
      taskId: 'task-1',
      priority: 0,
      dueAt: originalDue,
    );
    final repository = _RecordingRepository(db, SyncChangeQueue(db));
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'task-1', priority: 0, dueAt: originalDue)],
      rule: _rule(QuadrantRuleType.priorityOnly),
      provideBoard: false,
    );

    // 本机两轴下"今天 + priority 0"落在 Q3，所以往 Q2 拖才是换象限
    // （第一版往 Q3 拖，等于拖回原象限，测的是另一件事）。
    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q2);
    await _settleWrites(tester, repository);

    expect(repository.calls.single.$3, isNull, reason: '组合1 在降级态也不该交回 dueAt');
    final row = await (db.select(
      db.todoTasks,
    )..where((r) => r.id.equals('task-1'))).getSingle();
    expect(row.priority, 2);
    expect(row.dueAt, originalDue);
  });

  testWidgets('落回原象限不发写请求', (tester) async {
    final db = await _memoryDbWithTask(tester, taskId: 'task-1', priority: 0);
    final repository = _RecordingRepository(db, SyncChangeQueue(db));
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'task-1', priority: 0)],
    );
    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q4);
    expect(repository.calls, isEmpty);
    final queued = await db.select(db.todoSyncChanges).get();
    expect(queued, isEmpty);
  });

  testWidgets('自定义规则下卡片拖不起来；同数据在组合2 下能拖（正向对照）', (tester) async {
    final db = await _memoryDbWithTask(tester, taskId: 'task-1', priority: 0);
    final repository = _RecordingRepository(db, SyncChangeQueue(db));
    final tasks = [_task(id: 'task-1', priority: 0, serverId: 101)];

    await _pump(
      tester,
      repository: repository,
      tasks: tasks,
      rule: _rule(QuadrantRuleType.custom),
      board: const {
        'UNCLASSIFIED': {101},
      },
      scopeKey: 'custom',
    );
    expect(find.byType(LongPressDraggable<QuadrantDragMove>), findsNothing);

    await _pump(
      tester,
      repository: repository,
      tasks: tasks,
      rule: _rule(QuadrantRuleType.priorityTime),
      board: const {
        'Q4_NOT_URGENT_NOT_IMPORTANT': {101},
      },
      scopeKey: 'priorityTime',
    );
    expect(find.byType(LongPressDraggable<QuadrantDragMove>), findsOneWidget);
  });

  testWidgets('写失败：卡片留在原象限并给可见提示，异常不外泄', (tester) async {
    final db = await _memoryDbWithTask(tester, taskId: 'task-1', priority: 0);
    final repository = _RecordingRepository(db, SyncChangeQueue(db))
      ..failNext = true;
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'task-1', priority: 0)],
    );
    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q1);
    await _settleWrites(tester, repository);

    expect(
      _inQuadrant(Quadrant.q4, '任务 task-1'),
      findsOneWidget,
      reason: '写失败后不该把卡片留在目标象限',
    );
    expect(find.textContaining('四象限'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final row = await (db.select(
      db.todoTasks,
    )..where((r) => r.id.equals('task-1'))).getSingle();
    expect(row.priority, 0);
    expect(
      await db.select(db.todoSyncChanges).get(),
      isEmpty,
      reason: '写失败也不该留下一条要同步出去的记录',
    );
  });

  testWidgets('连续两次拖动：先发的请求后到也不得覆盖第二次结果', (tester) async {
    final db = await _memoryDbWithTask(tester, taskId: 'task-1', priority: 0);
    final repository = _RecordingRepository(db, SyncChangeQueue(db));
    await _pump(
      tester,
      repository: repository,
      tasks: [_task(id: 'task-1', priority: 0)],
    );

    // 第一次拖到 Q2：卡在 gate 上不返回（闸门取一次就置空，所以自己留一份引用）。
    final gate = Completer<void>();
    repository.gate = gate;
    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q2);
    expect(repository.calls.length, 1, reason: '第一次拖动该立刻进入写链');
    // 第二次拖到 Q1：必须排在第一次之后落库，不能被迟到的第一次盖掉。
    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q1);
    await tester.pump();
    // 写链是串行的：第一次没落地前，第二次的 moveQuadrantTask 连入口都进不去。
    expect(repository.calls.length, 1, reason: '第二次抢在第一次之前开始写，就成了后发先至');
    gate.complete();
    await _settleWrites(tester, repository);
    expect(repository.calls.length, 2);
    expect(repository.calls[0].$3!.month, 7, reason: '第一次是 Q2⇒1 个月后');
    expect(repository.calls[1].$3!.month, 6, reason: '第二次是 Q1⇒当天');

    final row = await (db.select(
      db.todoTasks,
    )..where((r) => r.id.equals('task-1'))).getSingle();
    // 只断言 priority 会是假绿：Q2 与 Q1 在组合2 下都写 priority 3。
    // 两档真正分开的是 dueAt —— Q1 是"当天"，Q2 是"1 个月后"。
    expect(row.dueAt!.day, 20, reason: '最终态应是第二次（Q1⇒当天），不是迟到的第一次（Q2⇒1 个月后）');
    expect(row.dueAt!.month, 6);
  });

  testWidgets('320px + 1.3 倍字号：卡片可拖且读屏念得出「拖动调整象限」，不溢出', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _memoryDbWithTask(tester, taskId: 'task-1', priority: 0);
    final repository = _RecordingRepository(db, SyncChangeQueue(db));
    await _pump(
      tester,
      repository: repository,
      tasks: [
        _task(id: 'task-1', priority: 0),
        _task(id: 'task-2', priority: 3, dueAt: DateTime(2026, 6, 20, 18)),
      ],
      surface: const Size(320, 700),
      textScale: 1.3,
    );

    // 传 String 是**全等**匹配，而卡片的读屏节点被 ListTile 合并成了
    // 「拖动调整象限\n任务 task-1」⇒ 只有 RegExp 量得到（diag 实测：String 0 命中、RegExp 2 命中）。
    expect(
      find.bySemanticsLabel(RegExp(_dragSemantics)),
      findsNWidgets(2),
      reason: '两张卡片各有一个可拖语义，少一个就是读屏念不到',
    );
    // 溢出在 widget 测试里以异常形式抛出 ⇒ 这里必须没有异常才算"没溢出"。
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('未配置仓储时拖动不崩，也不动任何数据', (tester) async {
    await _pump(
      tester,
      repository: null,
      tasks: [_task(id: 'task-1', priority: 0)],
    );
    await _dragToQuadrant(tester, '任务 task-1', Quadrant.q1);
    expect(tester.takeException(), isNull);
    expect(_inQuadrant(Quadrant.q4, '任务 task-1'), findsOneWidget);
  });
}
