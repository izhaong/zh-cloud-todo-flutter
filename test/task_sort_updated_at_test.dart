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

/// 嘀嗒《01-任务/09-如何管理海量任务/03-用分组和排序管理任务》「如何使用排序」：
/// 四种排序方式里含「按修改时间排序」。本端只有创建时间档 ⇒ 本轮补「修改时间」。
void main() {
  /// 不用编译期常量引用新档：这样缺档时是**运行时的明确失败信息**，
  /// 而不是整个文件编译不过（看不出到底缺哪一档）。
  TaskSort sortByName(String name) => TaskSort.values.firstWhere(
    (candidate) => candidate.name == name,
    orElse: () => throw StateError('TaskSort 里没有「$name」这一档'),
  );

  test('排序档位里有「修改时间」，文案照嘀嗒不发明同义词', () {
    expect(
      TaskSort.values.map((sort) => sort.name),
      contains('updatedAt'),
      reason: '嘀嗒排序列表有「按修改时间排序」，本端枚举里没有这一档',
    );
    expect(
      sortByName('updatedAt').label,
      '修改时间',
      reason: '措辞要贴嘀嗒，不写「更新时间」「最近修改」',
    );
    // 菜单项由 `TaskSort.values` 生成（`task_workspace_header.dart` 的 itemBuilder 遍历 values），
    // 所以「紧跟创建时间 + 不重排既有档位」这条 FR-1 判据落在声明顺序上才是可证的。
    expect(
      TaskSort.values.map((sort) => sort.name).toList(),
      [
        'smart',
        'priorityDesc',
        'dueDate',
        'title',
        'createdAt',
        'updatedAt',
        // 标签档（specs/090）追加在末尾：偏好按 name 序列化，重排/插队会让已存偏好的语义位移。
        'tag',
      ],
      reason: '「修改时间」必须在「创建时间」之后，且既有档位顺序不动（重排会让已存偏好的语义位移）',
    );
  });

  test('修改时间档按 updatedAt 从新到旧，且与创建时间档排出来确实不同', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final base = DateTime.utc(2026, 9, 1, 9);
    // 兜底键（sortOrder、id）必须与 updatedAt 的方向**相反**：否则把比较器摘成
    // `=> 0` 时，兜底链会恰好排出同样的顺序，用例照样绿（探针 PA 实测过）。
    await db.batch((batch) {
      batch.insert(
        db.todoTasks,
        TodoTasksCompanion.insert(
          id: 'recently-touched',
          listId: 'inbox',
          title: '刚改过、但创建得早',
          sortOrder: const Value(1),
          createdAt: base.subtract(const Duration(days: 10)),
          updatedAt: base,
        ),
      );
      batch.insert(
        db.todoTasks,
        TodoTasksCompanion.insert(
          id: 'recently-created',
          listId: 'inbox',
          title: '刚创建、但很久没改',
          sortOrder: const Value(0),
          createdAt: base,
          updatedAt: base.subtract(const Duration(days: 10)),
        ),
      );
    });
    final repository = TaskQueryRepository(db);

    final byUpdated = await repository.filter(
      TaskQueryFilter(sort: sortByName('updatedAt')),
    );
    expect(
      byUpdated.map((task) => task.id),
      ['recently-touched', 'recently-created'],
      reason: '修改时间档必须按 updatedAt 降序，而不是沿用 createdAt 的顺序',
    );

    final byCreated = await repository.filter(
      const TaskQueryFilter(sort: TaskSort.createdAt),
    );
    expect(byCreated.map((task) => task.id), [
      'recently-created',
      'recently-touched',
    ], reason: '正对照：两档数据是反着种的，若两档结果相同就说明新档没接上字段');
  });

  test('修改时间档能存能读，不会被静默退回智能排序', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final repository = TaskSortPreferenceRepository(db, queue);

    await repository.save('inbox', sortByName('updatedAt'));

    expect(
      (await repository.get('inbox')).sort,
      sortByName('updatedAt'),
      reason: '偏好按 TaskSort.name 编解码；新档存进去读回来必须还是它',
    );
  });

  test('sync pull 的嵌套包装能读出修改时间档；未知档位名退回智能排序', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskSortPreferenceRepository(db, SyncChangeQueue(db));
    final now = DateTime.utc(2026, 9, 23);

    // 第二设备不是走 save()，而是服务端实体落库：排序在**字符串化的 valueJson 里**
    // （`task_sort_preference_repository.dart` 的嵌套分支）。只认本地扁平形状会静默退回智能排序。
    Future<void> seed(String sourceKey, Object valueJson) => db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion(
            id: Value('sort-$sourceKey'),
            sourceType: const Value('TASK_SORT'),
            sourceKey: Value(sourceKey),
            valueJson: Value(jsonEncode(valueJson)),
            updatedAt: Value(now),
            createdAt: Value(now),
          ),
        );

    await seed('from-sync', {
      'valueJson': jsonEncode({'sort': 'updatedAt'}),
    });
    expect(
      (await repository.get('from-sync')).sort,
      sortByName('updatedAt'),
      reason: 'sync pull 的包装形状读不出 updatedAt，就等于跨端不生效',
    );

    await seed('other-list', {'sort': 'updatedAtDesc'});
    expect(
      (await repository.get('other-list')).sort,
      TaskSort.smart,
      reason: '未知档位名必须退回 smart（本仓既有断言只覆盖「无行」那一支，未覆盖这一支）',
    );
  });

  testWidgets('排序菜单里的「修改时间」在 320px + 1.3 倍字体下可见可选且不溢出', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TaskSort? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TaskWorkspaceHeader(
                title: '收件箱',
                taskCount: 3,
                mode: TaskViewMode.list,
                sort: TaskSort.smart,
                filterActive: false,
                onModeChanged: (_) {},
                onSortChanged: (sort) => changed = sort,
                onFilterPressed: () {},
                // 生产里 onBatchPressed 常驻、onCreateSection 条件出现（`tasks_by_list_page.dart:191-204`）
                // ⇒ 两个都传，溢出判据才落在「6 档 + 2 分隔线 + 2 命令项」的最长菜单上。
                onBatchPressed: () {},
                onCreateSection: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('todo-task-workspace-header'))),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '档位没传进 header 就等于这条用例在 1.0 上排版',
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.tap(find.byKey(const Key('todo-sort-menu')));
      await tester.pumpAndSettle();

      expect(
        find.text('创建时间'),
        findsOneWidget,
        reason: '菜单没展开的话下面的负向/正向断言都不成立',
      );
      expect(find.text('修改时间'), findsOneWidget, reason: '嘀嗒的第四种排序方式在菜单里找不到');
      expect(
        find.bySemanticsLabel(RegExp('修改时间')),
        findsOneWidget,
        reason: '菜单项只有文字没有语义节点时读屏念不出这一档',
      );

      await tester.tap(find.text('修改时间'));
      await tester.pumpAndSettle();
      expect(changed?.name, 'updatedAt', reason: '点了档位但回调没把这一档带出来');
      expect(tester.takeException(), isNull, reason: '多一行档位后窄屏 + 大字体下菜单溢出');
    } finally {
      semantics.dispose();
    }
  });
}
