import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_workspace_header.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_sort_preference_repository.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/03-用分组和排序管理任务》（develop 镜像 292 行）：
/// `:169`「## 按创建时间排序（新增）」→ `:173-176`「支持：- 从旧到新；- 从新到旧。」；
/// `:185`「## 按修改时间排序（新增）」同样给两个方向；`:203` 场景写「排序：创建时间（从新到旧）」。
/// `:141`「按时间排序」与 `:153`「按优先级排序」两节**没有**方向 ⇒ 方向只属于这两档时间轴。
///
/// develop 上方向是写死的降序（`task_query_repository.dart:38-39` 两条 `right.compareTo(left)`），
/// `lib/` 里 `从旧到新`、`ascending` 全 0 命中。本文件钉的就是"用户可切"这一格。
void main() {
  Future<AppDatabase> seededDb() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final base = DateTime.utc(2026, 9, 1, 9);
    // 兜底键（sortOrder、id）与时间方向**反着种**：否则比较器被摘成 `=> 0` 时
    // 兜底链会恰好排出同样的顺序，两个方向的断言会同时绿（specs/035 探针 PA 踩过）。
    //   older-created  ：创建早、修改晚、优先级 0、标题 z、置顶 false
    //   newer-created  ：创建晚、修改早、优先级 5、标题 a、置顶 false
    // ⇒ createdAt 与 updatedAt 两轴互逆；priority/title 两轴又与两者互逆。
    await db.batch((batch) {
      batch.insert(
        db.todoTasks,
        TodoTasksCompanion.insert(
          id: 'older-created',
          listId: 'inbox',
          title: 'zzz 早创建',
          sortOrder: const Value(1),
          priority: const Value(0),
          dueAt: Value(base.add(const Duration(days: 1))),
          createdAt: base.subtract(const Duration(days: 10)),
          updatedAt: base,
        ),
      );
      batch.insert(
        db.todoTasks,
        TodoTasksCompanion.insert(
          id: 'newer-created',
          listId: 'inbox',
          title: 'aaa 晚创建',
          sortOrder: const Value(0),
          priority: const Value(5),
          dueAt: Value(base.subtract(const Duration(days: 1))),
          createdAt: base,
          updatedAt: base.subtract(const Duration(days: 10)),
        ),
      );
    });
    return db;
  }

  Future<List<String>> orderOf(
    AppDatabase db,
    TaskSort sort,
    TaskSortDirection direction,
  ) async {
    final rows = await TaskQueryRepository(
      db,
    ).filter(TaskQueryFilter(sort: sort, sortDirection: direction));
    return rows.map((task) => task.id).toList();
  }

  test('方向有两档，文案照嘀嗒；默认是「从新到旧」（等于本轮之前的行为）', () {
    expect(
      TaskSortDirection.values.map((d) => d.name).toList(),
      ['newestFirst', 'oldestFirst'],
      reason: '两档都要有，且 newestFirst 在前 —— 它同时是默认值',
    );
    expect(
      TaskSortDirection.newestFirst.label,
      '从新到旧',
      reason: '措辞照《…03-用分组和排序管理任务》:175/:203，不写「倒序」「降序」',
    );
    expect(
      TaskSortDirection.oldestFirst.label,
      '从旧到新',
      reason: '同上 :174，不写「升序」「正序」',
    );
    const fallback = TaskQueryFilter(sort: TaskSort.createdAt);
    expect(
      fallback.sortDirection,
      TaskSortDirection.newestFirst,
      reason: '默认必须等于本轮之前的写死行为，否则未存过偏好的清单会静默换序',
    );
  });

  test('创建时间档：两个方向排出来互为逆序', () async {
    final db = await seededDb();
    expect(
      await orderOf(db, TaskSort.createdAt, TaskSortDirection.newestFirst),
      ['newer-created', 'older-created'],
      reason: '「从新到旧」是既有行为，本轮不许顺手改掉',
    );
    expect(
      await orderOf(db, TaskSort.createdAt, TaskSortDirection.oldestFirst),
      ['older-created', 'newer-created'],
      reason: '嘀嗒 :174 给了「从旧到新」这一档 ⇒ 切方向必须真的反序',
    );
  });

  test('修改时间档：两个方向互为逆序，且方向不跟随创建时间档', () async {
    final db = await seededDb();
    expect(
      await orderOf(db, TaskSort.updatedAt, TaskSortDirection.newestFirst),
      ['older-created', 'newer-created'],
      reason: '数据是反着种的：修改时间档的降序与创建时间档的降序必须不同，否则两档同源',
    );
    expect(
      await orderOf(db, TaskSort.updatedAt, TaskSortDirection.oldestFirst),
      ['newer-created', 'older-created'],
    );
  });

  test('非时间档不受方向影响（嘀嗒只给两档时间列方向）', () async {
    final db = await seededDb();
    for (final sort in const [
      TaskSort.smart,
      TaskSort.priorityDesc,
      TaskSort.dueDate,
      TaskSort.title,
    ]) {
      expect(
        await orderOf(db, sort, TaskSortDirection.oldestFirst),
        await orderOf(db, sort, TaskSortDirection.newestFirst),
        reason:
            '${sort.name} 档在嘀嗒原文里没有方向一说，切方向不该改变结果。'
            '注意本条只钉"方向不影响该档"，不钉"该档真的按自己的字段排"（后者由既有档位用例覆盖）',
      );
    }
  });

  test('方向能存能读；旧格式只存 sort 时退回「从新到旧」而不是退回智能排序', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final repository = TaskSortPreferenceRepository(db, queue);

    await repository.save(
      'list-a',
      TaskSort.createdAt,
      TaskSortDirection.oldestFirst,
    );
    final saved = await repository.get('list-a');
    expect(saved.sort, TaskSort.createdAt);
    expect(
      saved.direction,
      TaskSortDirection.oldestFirst,
      reason: '方向存不下来 = 重启就丢，用户每次都得重选',
    );

    // 本轮之前的存量行：valueJson 里根本没有 direction 这个键。
    await db.delete(db.todoViewPreferences).go();
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'legacy-row',
            sourceType: 'TASK_SORT',
            sourceKey: 'list-a',
            valueJson: jsonEncode({'sort': 'createdAt'}),
            updatedAt: DateTime.utc(2026, 9, 1),
            createdAt: DateTime.utc(2026, 9, 1),
          ),
        );
    final legacy = await repository.get('list-a');
    expect(legacy.sort, TaskSort.createdAt, reason: '旧行的档位不能被读丢');
    expect(
      legacy.direction,
      TaskSortDirection.newestFirst,
      reason: '缺键必须落到"与升级前一致"的方向，不能落进 else 分支变成别的档位',
    );

    // 未知档位名退回智能排序是既有行为；未知方向名同理退回默认，两者别互相污染。
    await db.delete(db.todoViewPreferences).go();
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'unknown-row',
            sourceType: 'TASK_SORT',
            sourceKey: 'list-a',
            valueJson: jsonEncode({
              'sort': 'createdAt',
              'direction': 'sideways',
            }),
            updatedAt: DateTime.utc(2026, 9, 1),
            createdAt: DateTime.utc(2026, 9, 1),
          ),
        );
    final unknown = await repository.get('list-a');
    expect(unknown.sort, TaskSort.createdAt, reason: '方向读不出来不该连累档位');
    expect(unknown.direction, TaskSortDirection.newestFirst);
  });

  /// 泵出 header 并展开排序菜单。方向回调由**调用方**持有：
  /// 早先的版本在 helper 里声明 `tapped` 再 `return tapped` ⇒ 返回的是取值那一刻的 null，
  /// 之后闭包写的是 helper 自己那个局部变量，调用方永远读不到（就是那次 `Actual: <null>`）。
  Future<void> pumpHeaderWithOpenMenu(
    WidgetTester tester, {
    required TaskSort sort,
    required TaskSortDirection direction,
    void Function(TaskSortDirection)? onDirection,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskWorkspaceHeader(
            title: '收件箱',
            taskCount: 3,
            mode: TaskViewMode.list,
            sort: sort,
            sortDirection: direction,
            filterActive: false,
            onModeChanged: (_) {},
            onSortChanged: (_) {},
            onSortDirectionChanged: onDirection,
            onFilterPressed: () {},
            onBatchPressed: () {},
            onCreateSection: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    // 前提断言：菜单真展开了才谈得上"这一档有没有方向行"。
    // 没有这条，上一轮菜单还没散场时的 tap 会「打空」（flutter_test 只给 warnIfMissed 警告，
    // 不会让断言变红），于是负向断言是在"菜单压根没开"上通过的。
    expect(
      find.text('智能（置顶优先）'),
      findsOneWidget,
      reason: '排序菜单没展开 ⇒ 后面的方向行断言全是空的',
    );
  }

  testWidgets('方向行只在两档时间轴下出现；点「从旧到新」能把方向带出来', (tester) async {
    for (final timeSort in const [TaskSort.createdAt, TaskSort.updatedAt]) {
      TaskSortDirection? tapped;
      await pumpHeaderWithOpenMenu(
        tester,
        sort: timeSort,
        direction: TaskSortDirection.newestFirst,
        onDirection: (next) => tapped = next,
      );
      expect(
        find.text('从旧到新'),
        findsOneWidget,
        reason: '${timeSort.name} 档按嘀嗒 :174 有方向可选，菜单里找不到这一行',
      );
      expect(find.text('从新到旧'), findsOneWidget);
      expect(tapped, isNull, reason: '只是展开菜单不该顺手改方向');

      await tester.tap(find.text('从旧到新'));
      await tester.pumpAndSettle();
      expect(
        tapped,
        TaskSortDirection.oldestFirst,
        reason: '点了方向行却没把方向带出来 ⇒ 界面是装饰',
      );
      expect(
        find.text('智能（置顶优先）'),
        findsNothing,
        reason: '菜单没收起就进下一轮，那轮的 tap 会打空（warnIfMissed 只警告不红）',
      );
    }

    for (final other in const [
      TaskSort.smart,
      TaskSort.priorityDesc,
      TaskSort.dueDate,
      TaskSort.title,
    ]) {
      await pumpHeaderWithOpenMenu(
        tester,
        sort: other,
        direction: TaskSortDirection.newestFirst,
        onDirection: (_) {},
      );
      expect(
        find.text('从旧到新'),
        findsNothing,
        reason: '${other.name} 档在嘀嗒原文里没有方向，给了就是自创交互',
      );
      // 收起菜单再进下一轮。`pumpWidget` 会**复用**同一个 Navigator 的 State，
      // 上一轮的弹层路由还挂在上面：不主动收，下一轮的 tap 打在遮罩上（只警告不红），
      // 而"这一档没有方向行"会在"菜单压根没开"上假通过 —— 实测第 2 次负向迭代就是这样。
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(
        find.text('智能（置顶优先）'),
        findsNothing,
        reason: '菜单没收掉 ⇒ 下一轮的负向断言会在"根本没展开"上通过',
      );
    }
  });

  testWidgets('320px + 1.3 倍：方向行排得下、各自可命中、有独立语义', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHeaderWithOpenMenu(
      tester,
      sort: TaskSort.createdAt,
      direction: TaskSortDirection.newestFirst,
      onDirection: (_) {},
    );

    expect(
      MediaQuery.textScalerOf(tester.element(find.text('从旧到新'))).scale(10),
      closeTo(13, 0.001),
      reason: '菜单是独立路由，档位要在它自己的 context 上复检',
    );
    for (final label in const ['从新到旧', '从旧到新']) {
      expect(
        find.text(label).hitTestable(),
        findsOneWidget,
        reason: '320px + 1.3 下这一行被挤出可视区就等于选不了',
      );
      expect(
        find.bySemanticsLabel(RegExp(label)),
        findsOneWidget,
        reason: '只有文字没有语义节点时读屏念不出这一档',
      );
    }
    expect(tester.takeException(), isNull, reason: '多两行方向后窄屏大字体下菜单溢出');
  });
}
