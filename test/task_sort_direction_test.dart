import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/view_mode.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_workspace_header.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_sort_preference_repository.dart';

import 'support/todo_visual_fixture.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/03-用分组和排序管理任务》（develop 镜像 292 行）：
/// `:169`「## 按创建时间排序（新增）」→ `:173-176`「支持：- 从旧到新；- 从新到旧。」；
/// `:186`「## 按修改时间排序（新增）」同样给两个方向（`:192-193`）；`:219` 场景写「排序：创建时间（从新到旧）」。
/// `:143`「按时间排序」与 `:156`「按优先级排序」两节**没有**方向 ⇒ 方向只属于这两档时间轴。
///
/// develop 上方向是写死的降序（`task_query_repository.dart:36-37`：
/// `TaskSort.createdAt => right.createdAt.compareTo(left.createdAt)` 与同形的 `updatedAt` 一条），
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
      reason: '措辞照《…03-用分组和排序管理任务》:176/:219，不写「倒序」「降序」',
    );
    expect(
      TaskSortDirection.oldestFirst.label,
      '从旧到新',
      reason: '同上 :175，不写「升序」「正序」',
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
      reason: '嘀嗒 :175 给了「从旧到新」这一档 ⇒ 切方向必须真的反序',
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
    void Function(TaskSort)? onSort,
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
            onSortChanged: onSort ?? (_) {},
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
        reason: '${timeSort.name} 档按嘀嗒 :173-176 有方向可选，菜单里找不到这一行',
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

  testWidgets('320px + 1.3 倍：方向行排得下、各自可命中，「当前方向」随方向换行', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 两个方向各跑一轮。只跑 `newestFirst` 时，把勾写死成 `candidate == newestFirst`
    // （探针 PJ）也全绿 ⇒ 那条断言钉的是"这行永远有勾"，不是"勾跟着状态走"。
    for (final current in TaskSortDirection.values) {
      // 弹层是独立路由且 `pumpWidget` 复用 Navigator 的 State ⇒ 不真卸载的话，
      // 这一轮读到的是上一轮那张开着的、按旧方向构建的菜单。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpHeaderWithOpenMenu(
        tester,
        sort: TaskSort.createdAt,
        direction: current,
        onDirection: (_) {},
      );

      expect(
        MediaQuery.textScalerOf(tester.element(find.text('从旧到新'))).scale(10),
        closeTo(13, 0.001),
        reason: '菜单是独立路由，档位要在它自己的 context 上复检',
      );
      // 「读屏能分辨当前方向」（Issue #320 四件套第 2 条）。
      // 判据要正负各一条：只断"有一处当前方向"会在两行都打标时照样绿。
      for (final candidate in TaskSortDirection.values) {
        final marking = find.descendant(
          of: find.byKey(Key('todo-sort-direction-${candidate.name}')),
          matching: find.bySemanticsLabel(RegExp('当前方向')),
        );
        if (candidate == current) {
          expect(
            marking,
            findsOneWidget,
            reason:
                'direction=$current 时「${candidate.label}」这一行没有可读标记 ⇒ '
                '读屏只知道有两行，不知道现在是哪一行',
          );
        } else {
          expect(marking, findsNothing, reason: '两行都标"当前方向"等于没标 ⇒ 勾没跟着状态走');
        }
      }
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
      expect(
        tester.takeException(),
        isNull,
        reason: '多两行方向后窄屏大字体下菜单溢出（direction=$current）',
      );
    }
  });

  testWidgets('工作区列表真的按方向反序（页面级：只钉仓储不等于界面接上了）', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.empty,
    );
    addTearDown(fixture.dispose);
    final base = fixture.fixedNow;
    await fixture.database.batch((batch) {
      batch.insertAll(fixture.database.todoTasks, [
        TodoTasksCompanion.insert(
          id: 'page-older',
          listId: 'inbox',
          title: '页面里早创建的',
          createdAt: base.subtract(const Duration(days: 5)),
          updatedAt: base,
        ),
        TodoTasksCompanion.insert(
          id: 'page-newer',
          listId: 'inbox',
          title: '页面里晚创建的',
          createdAt: base,
          updatedAt: base.subtract(const Duration(days: 5)),
        ),
      ]);
    });

    Future<void> pumpWorkspace() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<double> rowTop(String id) async {
      final finder = find.byKey(Key('task-row-surface-$id'));
      expect(
        finder,
        findsOneWidget,
        reason: '这一行不在屏上 ⇒ 比几何位置没有意义（列表被筛选掉了会假通过）',
      );
      return tester.getRect(finder).top;
    }

    await pumpWorkspace();
    final seededRows = await fixture.database
        .select(fixture.database.todoTasks)
        .get();
    expect(
      seededRows.where((task) => task.serverId == null),
      hasLength(2),
      reason:
          'Issue #320 验收④ 讲的是"未同步的任务不阻塞切换" ⇒ 种成已同步就测不到那一格。'
          '夹具本身也不通网（`todo_visual_fixture.dart` 的 `_NoNetworkApiClient` 对任何'
          '非预期请求直接回 error），所以这条用例能跑完就等于是"切方向一次请求都没发"',
    );
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建时间'));
    await tester.pumpAndSettle();

    // 默认「从新到旧」：晚创建的在上。
    expect(
      await rowTop('page-newer'),
      lessThan(await rowTop('page-older')),
      reason: '没切方向之前就该是既有行为（降序）',
    );

    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从旧到新'));
    await tester.pumpAndSettle();

    expect(
      await rowTop('page-older'),
      lessThan(await rowTop('page-newer')),
      reason: '仓储排对了但页面没接上方向 ⇒ 用户在界面上看不到这一档',
    );

    // 方向要跟着偏好走：重进清单（**新的 State**）不该弹回降序。
    // 必须先真的卸载：`pumpWidget` 复用同类型同位置的 State ⇒ 不卸载就等于
    // 没重进，探针 PG（回读时把方向写死成 newestFirst）在补这句之前是绿的。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpWorkspace();
    expect(
      await rowTop('page-older'),
      lessThan(await rowTop('page-newer')),
      reason: '重启即丢方向 = 每次都得重选一遍',
    );
    final preference = await fixture.database
        .select(fixture.database.todoViewPreferences)
        .getSingle();
    expect(
      preference.valueJson,
      allOf(contains('createdAt'), contains('oldestFirst')),
      reason: '上送与重启都靠这一列，缺 direction 键就是没存住',
    );

    // 验收③：切方向不许动其它视图的既有顺序。看板按优先级分列、时间线按日期分组，
    // 都不该读到这个方向参数（`compareTodoTasks` 在本仓只有列表铺平与仓储 filter 两处调用）。
    for (final modeLabel in const ['看板', '时间线']) {
      await tester.tap(find.byKey(const Key('todo-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(modeLabel));
      await tester.pumpAndSettle();

      final olderTop = tester.getRect(find.text('页面里早创建的').first).top;
      final newerTop = tester.getRect(find.text('页面里晚创建的').first).top;
      expect(
        find.text('页面里早创建的'),
        findsWidgets,
        reason: '$modeLabel 视图里连卡片都没渲染 ⇒ 这条对比是空的',
      );

      await tester.tap(find.byKey(const Key('todo-sort-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从新到旧'));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('页面里早创建的').first).top,
        olderTop,
        reason: '$modeLabel 的顺序被方向带跑了（它有自己的分组轴）',
      );
      expect(tester.getRect(find.text('页面里晚创建的').first).top, newerTop);
    }
  });

  testWidgets('方向保存失败：界面仍是刚选的方向、有可见提示，且偏好不落半条（四件套第 3 条）', (tester) async {
    // 让**入队**失败，而不是替换掉仓储：`save` 的写库与入队在同一个 `_db.transaction` 里，
    // 所以这条用例同时测到"失败不留半条偏好行"（探针 PN 摘掉事务就会红）。
    late _ThrowingEnqueueQueue queue;
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.empty,
      overridesBuilder: (database) {
        queue = _ThrowingEnqueueQueue(database);
        return [syncChangeQueueProvider.overrideWithValue(queue)];
      },
    );
    addTearDown(fixture.dispose);
    final base = fixture.fixedNow;
    await fixture.database.batch((batch) {
      batch.insertAll(fixture.database.todoTasks, [
        TodoTasksCompanion.insert(
          id: 'fail-older',
          listId: 'inbox',
          title: '失败态早创建的',
          createdAt: base.subtract(const Duration(days: 5)),
          updatedAt: base,
        ),
        TodoTasksCompanion.insert(
          id: 'fail-newer',
          listId: 'inbox',
          title: '失败态晚创建的',
          createdAt: base,
          updatedAt: base.subtract(const Duration(days: 5)),
        ),
      ]);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建时间'));
    await tester.pumpAndSettle();
    // 选档那一次点击走的是同一条保存、报的是同一句提示：先把它的 SnackBar 收掉，
    // 否则最后那句「有可见失败提示」可能测的是上一次点击的失败，方向这条分支
    // 摘掉 catch 也照样绿。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text('排序偏好保存失败，请稍后重试'),
      findsNothing,
      reason: '选档那次的提示没收起 ⇒ 后面的失败提示分不清是哪一次点击的',
    );
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从旧到新'));
    await tester.pumpAndSettle();

    // 调用边界：先证"页面确实带着新方向去存了"，再谈失败后的界面行为。
    // 记的是**真实** `save` 交给队列的 `valueJson`，不是我自己造的参数 —— 所以这条
    // 同时钉住了"档位没被弄丢、方向带上了"。
    expect(
      queue.valueJsons,
      [
        '{"sort":"createdAt","direction":"newestFirst"}',
        '{"sort":"createdAt","direction":"oldestFirst"}',
      ],
      reason:
          '选档与选方向各应落到入队一次，且第二次带上新方向；'
          '少了任何一条 ⇒ 界面点了但没走保存，本用例的判据错位',
    );
    final storedPreferences = await fixture.database
        .select(fixture.database.todoViewPreferences)
        .get();
    expect(
      storedPreferences,
      isEmpty,
      reason:
          '入队失败必须连偏好写入一起回滚 ⇒ 留下半条（界面一个方向、库里另一个方向）'
          '会让下次重进清单跳到一个用户没选过的档位',
    );

    expect(
      find.text('排序偏好保存失败，请稍后重试'),
      findsOneWidget,
      reason: '写失败被 catch 吞掉 ⇒ 用户以为方向存住了，重启后弹回原样',
    );
    expect(
      tester.getRect(find.byKey(const Key('task-row-surface-fail-older'))).top,
      lessThan(
        tester
            .getRect(find.byKey(const Key('task-row-surface-fail-newer')))
            .top,
      ),
      reason: '保存失败就回滚界面 ⇒ 用户刚做的选择被吃掉',
    );

    // 菜单里那一行也得跟着：`sortDirection` 若没接到 header，页面顺序对了也白搭。
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('todo-sort-direction-oldestFirst')),
        matching: find.bySemanticsLabel(RegExp('当前方向')),
      ),
      findsOneWidget,
      reason: '重开菜单显示的还是旧方向 ⇒ 界面自相矛盾',
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    // SnackBar 自带 4s 定时收起：不推过它，用例会以"仍有 pending Timer"收场。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  group('标签档（嘀嗒《用标签管理任务》:122「在任务列表『···』-『排序』中，将任务按标签进行排序」）', () {
    // 种子刻意让「兜底键（sortOrder）顺序」与「标签位次顺序」互逆：
    //   task-a     挂 tag-second（位次 1），sortOrder 0
    //   task-b     挂 tag-first （位次 0），sortOrder 1
    //   task-multi 挂两个标签（最小位次 0），sortOrder 2
    //   task-none  无标签（末位哨兵），sortOrder 3
    // ⇒ 标签档期望 [task-b, task-multi, task-a, task-none]；
    //   比较器被摘成 `=> 0` 时兜底会排出 [task-a, task-b, task-multi, task-none]，断言不假绿。
    //   侧栏顺序 = isPinned DESC, sortOrder DESC, createdAt ASC（与 TagRepository.watchAll 同序）。
    Future<AppDatabase> seededTagDb() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final base = DateTime.utc(2026, 9, 1, 9);
      await db.batch((batch) {
        batch.insertAll(db.todoTags, [
          TodoTagsCompanion.insert(
            id: 'tag-first',
            name: '工作',
            sortOrder: const Value(2),
            createdAt: base,
            updatedAt: base,
          ),
          TodoTagsCompanion.insert(
            id: 'tag-second',
            name: '生活',
            sortOrder: const Value(1),
            createdAt: base,
            updatedAt: base,
          ),
        ]);
        batch.insertAll(db.todoTaskTags, [
          TodoTaskTagsCompanion.insert(taskId: 'task-a', tagId: 'tag-second'),
          TodoTaskTagsCompanion.insert(taskId: 'task-b', tagId: 'tag-first'),
          TodoTaskTagsCompanion.insert(
            taskId: 'task-multi',
            tagId: 'tag-first',
          ),
          TodoTaskTagsCompanion.insert(
            taskId: 'task-multi',
            tagId: 'tag-second',
          ),
        ]);
        batch.insertAll(db.todoTasks, [
          TodoTasksCompanion.insert(
            id: 'task-a',
            listId: 'inbox',
            title: '甲 挂生活',
            sortOrder: const Value(0),
            createdAt: base,
            updatedAt: base,
          ),
          TodoTasksCompanion.insert(
            id: 'task-b',
            listId: 'inbox',
            title: '乙 挂工作',
            sortOrder: const Value(1),
            createdAt: base,
            updatedAt: base,
          ),
          TodoTasksCompanion.insert(
            id: 'task-multi',
            listId: 'inbox',
            title: '丙 两个都挂',
            sortOrder: const Value(2),
            createdAt: base,
            updatedAt: base,
          ),
          TodoTasksCompanion.insert(
            id: 'task-none',
            listId: 'inbox',
            title: '丁 无标签',
            sortOrder: const Value(3),
            createdAt: base,
            updatedAt: base,
          ),
        ]);
      });
      return db;
    }

    test('按标签排序跟随侧栏顺序（取最小位次）；无标签排最后', () async {
      final db = await seededTagDb();
      expect(
        await orderOf(db, TaskSort.tag, TaskSortDirection.newestFirst),
        ['task-b', 'task-multi', 'task-a', 'task-none'],
        reason:
            'tag-first 在侧栏领前 ⇒ 挂它的 task-b 与 task-multi（取两标签最小位次）领头，'
            '两者并列后按手工顺序分先后；无标签的 task-none 用末位哨兵，不许当位次 0',
      );
    });

    test('标签档没有方向一说，切方向不改变结果', () async {
      final db = await seededTagDb();
      expect(
        await orderOf(db, TaskSort.tag, TaskSortDirection.oldestFirst),
        await orderOf(db, TaskSort.tag, TaskSortDirection.newestFirst),
        reason: '嘀嗒原文没给标签档方向 ⇒ 方向参数对它必须是 no-op',
      );
    });

    test('置顶优先压过标签档（既有前置键不许被新档位顶掉）', () async {
      final db = await seededTagDb();
      final base = DateTime.utc(2026, 9, 1, 9);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-pinned',
              listId: 'inbox',
              title: '置顶但无标签',
              sortOrder: const Value(4),
              isPinned: const Value(true),
              createdAt: base,
              updatedAt: base,
            ),
          );
      final rows = await orderOf(
        db,
        TaskSort.tag,
        TaskSortDirection.newestFirst,
      );
      expect(
        rows.first,
        'task-pinned',
        reason: 'compareTodoTasks 的置顶键在所有档位之前，标签档也不例外',
      );
      expect(rows, hasLength(5));
    });

    test('位次表缺该标签 ⇒ 与无标签同哨兵；两表未到位 ⇒ 全并列退回手工顺序', () async {
      final db = await seededTagDb();
      final rows = await TaskQueryRepository(
        db,
      ).filter(const TaskQueryFilter());
      final byId = {for (final task in rows) task.id: task};
      final left = byId['task-a']!;
      final right = byId['task-none']!;
      expect(
        compareTodoTasks(
          left,
          right,
          TaskSort.tag,
          taskTags: {
            'task-a': {'ghost'},
          },
          tagRank: const {},
        ),
        lessThan(0),
        reason:
            'task-a 挂的标签不在位次表 ⇒ 与无标签同哨兵 ⇒ 回落 sortOrder（0 < 3）。'
            '若缺失被当 0 处理，它会插队到所有任务前面',
      );
      expect(
        compareTodoTasks(left, right, TaskSort.tag),
        lessThan(0),
        reason: '两张表都没到位（页面索引未就位）时全并列 ⇒ 兜底键接管，不许抛错',
      );
    });

    testWidgets('排序菜单含「标签」档、不给方向行；点击带出 TaskSort.tag', (tester) async {
      TaskSort? tapped;
      await pumpHeaderWithOpenMenu(
        tester,
        sort: TaskSort.tag,
        direction: TaskSortDirection.newestFirst,
        onSort: (next) => tapped = next,
      );
      expect(find.text('标签'), findsOneWidget, reason: '菜单缺「标签」档 ⇒ 用户选不到这一档');
      expect(
        find.text('从旧到新'),
        findsNothing,
        reason: '嘀嗒没给标签档方向 ⇒ 多出方向行就是自创交互',
      );
      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();
      expect(tapped, TaskSort.tag, reason: '点了没把档位带出来 ⇒ 菜单是装饰');
    });

    testWidgets('页面级：标签档真的按侧栏顺序重排（种子偏好直读，绕开「标签」文案与快速添加栏撞车）', (tester) async {
      final fixture = await TodoVisualFixture.create(
        set: TodoVisualFixtureSet.empty,
      );
      addTearDown(fixture.dispose);
      final base = fixture.fixedNow;
      await fixture.database.batch((batch) {
        batch.insertAll(fixture.database.todoTags, [
          TodoTagsCompanion.insert(
            id: 'tag-first',
            name: '工作',
            sortOrder: const Value(2),
            createdAt: base,
            updatedAt: base,
          ),
          TodoTagsCompanion.insert(
            id: 'tag-second',
            name: '生活',
            sortOrder: const Value(1),
            createdAt: base,
            updatedAt: base,
          ),
        ]);
        batch.insertAll(fixture.database.todoTaskTags, [
          TodoTaskTagsCompanion.insert(
            taskId: 'page-tag-a',
            tagId: 'tag-second',
          ),
          TodoTaskTagsCompanion.insert(
            taskId: 'page-tag-b',
            tagId: 'tag-first',
          ),
        ]);
        batch.insertAll(fixture.database.todoTasks, [
          TodoTasksCompanion.insert(
            id: 'page-tag-a',
            listId: 'inbox',
            title: '标签档页面甲',
            sortOrder: const Value(0),
            createdAt: base,
            updatedAt: base,
          ),
          TodoTasksCompanion.insert(
            id: 'page-tag-b',
            listId: 'inbox',
            title: '标签档页面乙',
            sortOrder: const Value(1),
            createdAt: base,
            updatedAt: base,
          ),
          TodoTasksCompanion.insert(
            id: 'page-tag-none',
            listId: 'inbox',
            title: '标签档页面丁',
            sortOrder: const Value(2),
            createdAt: base,
            updatedAt: base,
          ),
        ]);
        batch.insert(
          fixture.database.todoViewPreferences,
          TodoViewPreferencesCompanion.insert(
            id: 'seed-tag-sort',
            sourceType: 'TASK_SORT',
            sourceKey: 'inbox',
            valueJson: jsonEncode({'sort': 'tag', 'direction': 'newestFirst'}),
            createdAt: base,
            updatedAt: base,
          ),
        );
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<double> rowTop(String id) async {
        final finder = find.byKey(Key('task-row-surface-$id'));
        expect(finder, findsOneWidget, reason: '这一行不在屏上 ⇒ 比几何位置没有意义');
        return tester.getRect(finder).top;
      }

      expect(
        await rowTop('page-tag-b'),
        lessThan(await rowTop('page-tag-a')),
        reason: '侧栏 tag-first 在前 ⇒ 挂它的任务在上；偏好里存了 tag 档却没生效 ⇒ 穿线断了',
      );
      expect(
        await rowTop('page-tag-a'),
        lessThan(await rowTop('page-tag-none')),
        reason: '无标签任务落末位',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}

/// 让入队必然失败，并记下真实 `save` 交进来的 `valueJson`。
///
/// 只替换队列、不替换仓储：偏好写入 + 入队同在 `_db.transaction` 里，
/// 队列抛错才能连带着验证"事务回滚 ⇒ 不留半条偏好"（探针 PN）。
class _ThrowingEnqueueQueue extends SyncChangeQueue {
  _ThrowingEnqueueQueue(super.database);

  final List<String> valueJsons = [];

  @override
  Future<void> enqueue({
    required String entity,
    required String op,
    String? localId,
    int? serverId,
    String? clientMutationId,
    required Map<String, dynamic> payload,
  }) async {
    valueJsons.add('${payload['valueJson']}');
    throw StateError('模拟同步入队失败');
  }
}
