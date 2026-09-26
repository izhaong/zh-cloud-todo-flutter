import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/template_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 把 `create` 挂起的假仓储：用来制造「请求在飞、用户先把模板弹层滑掉」这一窗口。
class _BlockingTaskRepository extends TaskRepository {
  _BlockingTaskRepository(super.db, super.queue);

  final Completer<TodoTask> gate = Completer<TodoTask>();

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
    int timeMode = 0,
    String? parentTaskId,
    bool isPinned = false,
  }) {
    return gate.future;
  }
}

/// 嘀嗒《01-任务/02-任务详情》「如何使用任务模板？」移动端原文：
/// 「添加任务时，点击任务输入弹窗下方的「...」按钮，选择「模板」即可从模板添加任务。」
/// 本文件钉的就是这一条主路：弹窗下方的「...」→「模板」→ 即刻建任务。
void main() {
  Future<TodoVisualFixture> pumpSheet(
    WidgetTester tester, {
    String? parentTaskId,
    String? listId,
    bool withTemplates = true,
    bool signedIn = true,
    List<Override> Function(AppDatabase db)? repoOverrides,
  }) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (db) {
        final overrides = <Override>[];
        if (!signedIn) {
          overrides.add(templateRepositoryProvider.overrideWithValue(null));
        }
        if (repoOverrides != null) overrides.addAll(repoOverrides(db));
        return overrides;
      },
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
              listId: listId ?? TodoVisualFixture.inboxListId,
              parentTaskId: parentTaskId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  /// 提示必须落在弹窗自己的子树里：生产里弹窗是 `showModalBottomSheet` 的一层路由，
  /// 挂在根 `ScaffoldMessenger` 上的 SnackBar 会被弹窗自己盖住（等于没有反馈）。
  Finder sheetMessage(Pattern text) {
    return find.descendant(
      of: find.byKey(const Key('todo-quick-add-sheet')),
      matching: find.textContaining(text),
      matchRoot: true,
    );
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
      // ensureSemantics() 只打开开关，语义节点要下一帧才生成：不 pump 的话
      // bySemanticsLabel 恒 0 命中，这条断言就成了空转（本仓踩过同源的坑）。
      await tester.pump();
      expect(
        find.bySemanticsLabel('更多'),
        findsOneWidget,
        reason:
            '「...」按钮用 child: 传图标时 tooltip 进不了语义节点，读屏只会念出一个无标签按钮，'
            '用户不知道那里有「模板」这一档（四件套里的「独立可读屏语义」）',
      );

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
      sheetMessage('已应用模板“周报流程”'),
      findsOneWidget,
      reason:
          '措辞沿用任务详情里已验收的那条提示，不另起同义词；且必须落在弹窗自己的子树里 —— '
          '生产里弹窗是一层 modal 路由，挂在根 ScaffoldMessenger 上的 SnackBar 会被弹窗盖住',
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
      sheetMessage('请先登录'),
      findsOneWidget,
      reason:
          '仓储为 null 时静默 return 会让用户以为按钮坏了（详情页同一措辞先例）；'
          '同样要落在弹窗子树里，SnackBar 在这层路由下面看不见',
    );
    expect(
      find.byKey(const Key('todo-quick-add-template-sheet')),
      findsNothing,
      reason: '未登录应该早退，不该再开一层空弹层让用户以为有模板',
    );
    expect(
      (await fixture.database.select(fixture.database.todoSyncChanges).get()),
      isEmpty,
      reason:
          '提示失败路径不该留下半条 outbox。注意这条断言在本用例里近乎恒真：'
          '未登录时 templateRepositoryProvider 为 null，saveTask 根本没跑过，'
          '它只能挡住「以后有人往这条路径上加写库」的回归，不能当正向证据',
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
      sheetMessage('父任务必须属于同一清单'),
      findsOneWidget,
      reason: '要给出可复现的原因，而不是通用「请稍后重试」，且原因得看得见',
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

  /// 模板行是 `Row(Expanded(Column(名称, 同步状态)) + TextButton(添加))`，
  /// 按名字定位到自己那一行的「添加」，不然两条模板时 find.text('添加') 会撞多命中。
  Finder addButtonFor(String templateName) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(templateName),
        matching: find.byType(Row),
      ),
      matching: find.text('添加'),
    );
  }

  testWidgets('模板内容坏了要说清原因，并且不能把入口永久卡死', (tester) async {
    // contentJson 是服务端 pull 时原样落库的字符串，非对象 JSON 是可达状态；
    // taskSeed 里 `as Map<String, dynamic>` 会抛 TypeError —— 复核第 2 条实测。
    final fixture = await pumpSheet(tester);
    final source =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();
    await fixture.database
        .into(fixture.database.todoTemplates)
        .insert(
          TodoTemplatesCompanion.insert(
            id: 'broken-template',
            name: '坏模板',
            contentJson: 'null',
            updatedAt: fixture.fixedNow,
            createdAt: fixture.fixedNow,
          ),
        );
    await tester.pumpAndSettle();

    await openTemplatePicker(tester);
    await tester.tap(addButtonFor('坏模板'));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: '解析模板内容必须在 try 内，否则异常逃到框架、用户只看到点了没反应',
    );
    expect(
      sheetMessage('保存任务失败'),
      findsOneWidget,
      reason: '坏数据也要给可见原因（FR-4），不能静默',
    );

    await openTemplatePicker(tester);
    await tester.tap(addButtonFor('周报流程'));
    await tester.pumpAndSettle();

    expect(
      await createdTasks(fixture, source.title, exceptId: source.id),
      hasLength(1),
      reason: '一条坏模板不能把整个入口锁死：守卫必须在 finally 里复位',
    );
  });

  testWidgets('用户先把模板弹层滑掉、请求随后才回来时，不许顺手关掉宿主快速添加弹窗', (tester) async {
    _BlockingTaskRepository? blocking;
    final fixture = await pumpSheet(
      tester,
      repoOverrides: (db) {
        final repo = _BlockingTaskRepository(db, SyncChangeQueue(db));
        blocking = repo;
        return [taskRepositoryProvider.overrideWithValue(repo)];
      },
    );
    final source =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();

    await openTemplatePicker(tester);
    await tester.tap(find.text('添加'));
    await tester.tapAt(const Offset(10, 10));
    // 关闭动画还没跑一帧：此刻弹层元素仍 mounted，只有路由已经不是当前路由。
    blocking!.gate.complete(source);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('todo-quick-add-sheet')),
      findsOneWidget,
      reason:
          '复核第 3 条：光看 sheetContext.mounted 挡不住 —— 反向动画期间它仍是 true，'
          '这句 pop 会打到下一层路由，把用户正在输入的宿主弹窗关掉',
    );
  });

  testWidgets('弹窗开在别的清单时，模板建出的任务落进那个清单', (tester) async {
    // 复核探针 PG（见 tasks.md「反向探针（第 2 次）」表）：生产里把 listId 换成字面量 'inbox' 时原 8 例全绿 ——
    // 因为每条用例都 pump 收集箱，而模板来源任务本身也在收集箱，等于没测这一维。
    final fixture = await pumpSheet(
      tester,
      listId: TodoVisualFixture.workListId,
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
      created.single.listId,
      TodoVisualFixture.workListId,
      reason: '落点必须是弹窗自己的目标清单；模板来源任务在另一个清单，才区分得出这两者',
    );
  });

  testWidgets('同一个弹窗里连挑两次模板，两条都建得出来', (tester) async {
    // 复核探针 PB：删掉守卫复位那一行，原 8 例全绿 —— 早退守卫只测了「挡住第二次」，
    // 没测「成功之后要把门打开」。FR-2 要的正是「点某一条即建一条」。
    final fixture = await pumpSheet(tester);
    final source =
        await (fixture.database.select(fixture.database.todoTasks)
              ..where((row) => row.id.equals(TodoVisualFixture.metadataTaskId)))
            .getSingle();

    await openTemplatePicker(tester);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await openTemplatePicker(tester);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(
      await createdTasks(fixture, source.title, exceptId: source.id),
      hasLength(2),
      reason: '第一次成功后守卫必须复位，否则第二次点「添加」静默早退',
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

    // 反馈行会让宿主弹窗多占一行：排版必须在它出现之后复测，不能只量初始态。
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(sheetMessage('已应用模板'), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('todo-quick-add-sheet'))),
      ).scale(10),
      closeTo(13, 0.001),
    );
    expect(tester.takeException(), isNull, reason: '多一行「...」与一行反馈后，窄屏大字体下溢出');
  });
}
