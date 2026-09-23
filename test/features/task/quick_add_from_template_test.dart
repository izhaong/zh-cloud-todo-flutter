import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/template_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《01-任务/02-任务详情》「如何使用任务模板？」移动端原文：
/// 「添加任务时，点击任务输入弹窗下方的「...」按钮，选择「模板」即可从模板添加任务。」
/// 本文件钉的就是这一条主路：弹窗下方的「...」→「模板」→ 即刻建任务。
void main() {
  Future<TodoVisualFixture> pumpSheet(
    WidgetTester tester, {
    String? parentTaskId,
    bool withTemplates = true,
    bool signedIn = true,
  }) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: signedIn
          ? null
          : (db) => [templateRepositoryProvider.overrideWithValue(null)],
    );
    addTearDown(fixture.dispose);

    if (withTemplates) {
      final templates = TemplateRepository(
        fixture.database,
        SyncChangeQueue(fixture.database),
      );
      await templates.saveTask(
        task:
            await (fixture.database.select(fixture.database.todoTasks)..where(
                  (row) => row.id.equals(TodoVisualFixture.metadataTaskId),
                ))
                .getSingle(),
        name: '周报流程',
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          home: Scaffold(
            body: TaskQuickAddSheet(
              key: const Key('quick-add-harness'),
              listId: TodoVisualFixture.inboxListId,
              parentTaskId: parentTaskId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<void> openTemplatePicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-quick-add-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模板'));
    await tester.pumpAndSettle();
  }

  /// 模板的来源任务本身就叫这个名字，按标题查必须把它排除掉，
  /// 否则「建出了一条」会被数成两条 —— 那是一条断言自己的假阳性。
  Future<List<TodoTask>> createdTasks(
    TodoVisualFixture fixture,
    String title, {
    required String exceptId,
  }) async {
    final query = fixture.database.select(fixture.database.todoTasks)
      ..where((row) => row.title.equals(title));
    final rows = await query.get();
    return rows.where((row) => row.id != exceptId).toList();
  }

  testWidgets('弹窗下方有「...」，展开后能看到嘀嗒措辞的「模板」项', (tester) async {
    await pumpSheet(tester);

    expect(
      find.byKey(const Key('todo-quick-add-more')),
      findsOneWidget,
      reason: '嘀嗒把入口写在「输入弹窗下方的「...」按钮」，弹窗里找不到就等于走不到',
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.tap(find.byKey(const Key('todo-quick-add-more')));
      await tester.pumpAndSettle();

      expect(
        find.text('模板'),
        findsOneWidget,
        reason: '菜单项措辞必须照嘀嗒（移动端那一档就叫「模板」，不叫「从模板添加」）',
      );
      expect(
        find.bySemanticsLabel('模板'),
        findsWidgets,
        reason: '菜单项只有文字没有语义节点时读屏念不出这一档',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('选「模板」并挑一条即建任务：标题/说明/优先级与目标清单都来自模板', (tester) async {
    final fixture = await pumpSheet(tester);
    final source =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();

    await openTemplatePicker(tester);
    expect(
      find.text('周报流程'),
      findsOneWidget,
      reason: '弹层没列出本地模板就等于「选择「模板」」这一步断在半路',
    );

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    final created = await createdTasks(
      fixture,
      source.title,
      exceptId: source.id,
    );
    expect(created, hasLength(1), reason: '嘀嗒原文是「即可从模板添加任务」，点了就该建出来');
    expect(
      created.single.listId,
      TodoVisualFixture.inboxListId,
      reason: '必须落在弹窗自己的目标清单，而不是模板来源任务的清单',
    );
    expect(
      created.single.description,
      source.description,
      reason: '模板的说明丢了就等于静默丢数据（本弹窗没有「说明」字段，更不能吞）',
    );
    expect(created.single.priority, source.priority);
    expect(
      find.text('已应用模板“周报流程”'),
      findsOneWidget,
      reason: '措辞沿用任务详情里已验收的那条提示，不另起同义词',
    );
  });

  testWidgets('子任务弹窗里选模板，新建的任务仍挂在同一父任务下', (tester) async {
    final fixture = await pumpSheet(
      tester,
      parentTaskId: TodoVisualFixture.todayTaskId,
    );
    final source =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();

    await openTemplatePicker(tester);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    final created = await createdTasks(
      fixture,
      source.title,
      exceptId: source.id,
    );
    expect(created, hasLength(1));
    expect(
      created.single.parentTaskId,
      TodoVisualFixture.todayTaskId,
      reason: '弹窗是「新建子任务」时，模板建出来的也得是同一个父任务的子任务',
    );
  });

  testWidgets('一个模板都没有时显示「暂无本地模板」，并且不建任何任务', (tester) async {
    final fixture = await pumpSheet(tester, withTemplates: false);
    final before =
        (await fixture.database.select(fixture.database.todoTasks).get())
            .length;

    await openTemplatePicker(tester);

    expect(find.text('暂无本地模板'), findsOneWidget, reason: '空态要与详情页同措辞');
    expect(find.text('添加'), findsNothing, reason: '空列表里不该还能点添加');
    expect(
      (await fixture.database.select(fixture.database.todoTasks).get()).length,
      before,
      reason: '走到空态不该顺手建东西',
    );
  });

  testWidgets('未登录（模板仓储不可用）要给「请先登录」，不能点了没反应', (tester) async {
    final fixture = await pumpSheet(
      tester,
      withTemplates: false,
      signedIn: false,
    );

    await openTemplatePicker(tester);

    expect(
      find.text('请先登录'),
      findsOneWidget,
      reason: '仓储为 null 时静默 return 会让用户以为按钮坏了（详情页同一措辞先例）',
    );
    expect(
      (await fixture.database.select(fixture.database.todoSyncChanges).get()),
      isEmpty,
      reason: '提示失败路径不该留下半条 outbox',
    );
  });

  testWidgets('建任务失败时：弹窗不关、已输入的标题不丢、说清原因', (tester) async {
    // 父任务属于另一个清单 ⇒ repo.create 必然拒绝，用来验「失败保留已加载数据」。
    final fixture = await pumpSheet(
      tester,
      parentTaskId: TodoVisualFixture.metadataTaskId,
    );
    await fixture.database
        .into(fixture.database.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'foreign-parent-list',
            name: '另一个清单',
            updatedAt: fixture.fixedNow,
            createdAt: fixture.fixedNow,
          ),
        );
    final parent =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((row) => row.id.equals(parent.id)))
        .write(const TodoTasksCompanion(listId: Value('foreign-parent-list')));

    await tester.enterText(find.byType(TextField).first, '手输的标题不能丢');
    await openTemplatePicker(tester);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(
      find.byType(TaskQuickAddSheet),
      findsOneWidget,
      reason: '失败就把弹窗留着，别把用户正在输入的表单关掉',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '手输的标题不能丢',
      reason: '模板建失败不该清掉用户已经打进去的标题',
    );
    expect(
      find.textContaining('父任务必须属于同一清单'),
      findsOneWidget,
      reason: '要给出可复现的原因，而不是通用「请稍后重试」',
    );
  });

  testWidgets('连点两次「添加」只建一条任务', (tester) async {
    final fixture = await pumpSheet(tester);
    final source =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();

    await openTemplatePicker(tester);
    final addButton = find.text('添加');
    await tester.tap(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(
      await createdTasks(fixture, source.title, exceptId: source.id),
      hasLength(1),
      reason: '没有早退守卫时同帧两次 tap 会建出两条重复任务',
    );
  });

  testWidgets('320px + 1.3 倍字体：弹窗与模板弹层都排得下且不溢出', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSheet(tester);

    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('todo-quick-add-sheet'))),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '档位没传到弹窗自己的 context 就等于这条用例在 1.0 上排版',
    );

    await openTemplatePicker(tester);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('todo-quick-add-template-sheet'))),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '弹层是新表面，必须用它自己的 context 复检，不能只测宿主弹窗',
    );
    expect(tester.takeException(), isNull, reason: '多一行「...」后窄屏大字体下溢出');
  });
}
