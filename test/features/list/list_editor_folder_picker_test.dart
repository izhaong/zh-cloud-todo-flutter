import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/list/list_editor_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md》:73
/// 「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」
const folderFieldKey = Key('todo-list-editor-folder');

/// 视觉夹具里的数据（`test/support/todo_visual_fixture.dart` 的 populated 集）。
const projectsFolderId = 'visual-folder-projects';
const projectsFolderServerId = 7101;

void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  /// 夹具与"把 sheet 铺上屏幕"分开：`TodoVisualFixture.create` 每次都是
  /// 一个新的内存库（`NativeDatabase.memory()`），一个用例里 create 两次
  /// 就会出现"写进库 B、断言读库 A"的假失败。
  Future<TodoVisualFixture> createFixture({
    List<Override> Function(AppDatabase database)? overridesBuilder,
  }) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
      overridesBuilder: overridesBuilder,
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    TodoVisualFixture fixture, {
    TodoList? existing,
    String? folderLocalId,
    Size surface = const Size(1000, 900),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: themed(),
          builder: textScale == 1
              ? null
              : (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: ListEditorSheet(
              existing: existing,
              folderLocalId: folderLocalId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<TodoVisualFixture> pump(
    WidgetTester tester, {
    TodoList? existing,
    String? folderLocalId,
    List<Override> Function(AppDatabase database)? overridesBuilder,
    Size surface = const Size(1000, 900),
    double textScale = 1,
  }) async {
    final fixture = await createFixture(overridesBuilder: overridesBuilder);
    await pumpSheet(
      tester,
      fixture,
      existing: existing,
      folderLocalId: folderLocalId,
      surface: surface,
      textScale: textScale,
    );
    return fixture;
  }

  Future<TodoList?> listById(AppDatabase db, String id) async {
    return await (db.select(
      db.todoLists,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<int> syncRowCount(TodoVisualFixture fixture) async {
    return (await fixture.database
            .select(fixture.database.todoSyncChanges)
            .get())
        .length;
  }

  // 收起状态下按钮自己也挂着一个 DropdownMenuItem（当前值）⇒ 展开后按
  // byType(DropdownMenuItem) 会把"按钮里那格"也算进候选，tap 会点错地方。
  // 所以候选菜单的项一律用"不在本字段子树里"筛出来。
  List<Element> menuItems(WidgetTester tester) {
    final field = tester.element(find.byKey(folderFieldKey));
    return find.byType(DropdownMenuItem<String?>).evaluate().where((element) {
      var inside = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor == field) {
          inside = true;
          return false;
        }
        return true;
      });
      return !inside;
    }).toList();
  }

  String itemLabel(Element element) {
    return ((element.widget as DropdownMenuItem<String?>).child as Text).data!;
  }

  /// 菜单已经展开时**再点一次字段是"关掉它"**（实测：第二次 tap 后候选清空）。
  Future<void> openMenu(WidgetTester tester) async {
    if (menuItems(tester).isNotEmpty) return;
    await tester.tap(find.byKey(folderFieldKey));
    await tester.pumpAndSettle();
    expect(menuItems(tester), isNotEmpty, reason: '点字段没展开候选菜单');
  }

  Future<List<String>> optionLabels(WidgetTester tester) async {
    await openMenu(tester);
    return menuItems(tester).map(itemLabel).toList();
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await openMenu(tester);
    final target = menuItems(tester).firstWhere((e) => itemLabel(e) == label);
    // 只有一个候选时，按钮与菜单复用同一个 DropdownMenuItem 实例 ⇒ find.byWidget
    // 会歧义报"found 2"；而菜单项的框又被 _DropdownMenu 偏移过 ⇒ 用 finder 中心
    // tap 会报"would not hit test"。所以直接按该元素自己的框取点，
    // 选没选中由每条用例随后的 expectSelected / 库里读回来兜住。
    final box = target.renderObject! as RenderBox;
    await tester.tapAt(
      box.localToGlobal(Offset.zero) +
          Offset(box.size.width / 2, box.size.height / 2),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('新建：默认「无」，选「项目」后保存 ⇒ 清单落进该文件夹', (tester) async {
    final fixture = await pump(tester);
    expect(find.text('所属文件夹'), findsOneWidget);
    expectSelected(tester, '无');

    final labels = await optionLabels(tester);
    expect(
      labels,
      containsAll(<String>['无', '项目']),
      reason: 'FR-1：无 + 每个已有文件夹',
    );
    expect(labels, isNot(contains('收集箱')), reason: '取舍 2：收集箱不是清单');

    await pick(tester, '项目');
    expectSelected(tester, '项目');

    await tester.enterText(find.widgetWithText(TextField, '清单名'), '骑行');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final created = await (fixture.database.select(
      fixture.database.todoLists,
    )..where((row) => row.name.equals('骑行'))).getSingle();
    expect(created.folderLocalId, projectsFolderId);
    expect(
      created.folderId,
      projectsFolderServerId,
      reason:
          '钉的是"顺手把反范式的服务端整数一起缓存上"这条写路径：'
          '归属的真正权威是 folderLocalId（sync_coordinator 回放时按它重算 folderId）',
    );
  });

  testWidgets('嵌套文件夹在候选里念成「父 / 子」，不与子项同名', (tester) async {
    final fixture = await createFixture();
    final now = DateTime(2026, 7, 11, 8);
    final parentRows =
        await (fixture.database.update(fixture.database.todoFolders)
              ..where((row) => row.id.equals(projectsFolderId)))
            .write(TodoFoldersCompanion(name: const Value('项目父夹')));
    expect(parentRows, 1, reason: '前提不成立就别往下断（update 命中 0 行不报错）');
    await fixture.database
        .into(fixture.database.todoFolders)
        .insert(
          TodoFoldersCompanion.insert(
            id: 'r68-nested-folder',
            parentId: const Value(projectsFolderId),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await pumpSheet(tester, fixture);

    final labels = await optionLabels(tester);
    expect(labels, contains('项目父夹 / 项目'), reason: 'FR-1：只给名字会撞车，看不出层级');
    expect(labels.where((l) => l == '项目'), isEmpty, reason: '子项不能顶着一个看不出归属的名字');
  });

  testWidgets('文件夹还没同步到服务端（serverId 为空）⇒ 本地归属照样成立', (tester) async {
    final fixture = await createFixture();
    final rows =
        await (fixture.database.update(fixture.database.todoFolders)
              ..where((row) => row.id.equals(projectsFolderId)))
            .write(const TodoFoldersCompanion(serverId: Value(null)));
    expect(rows, 1, reason: '前提不成立 ⇒ 后面的断言都是空的');
    await pumpSheet(tester, fixture);

    await pick(tester, '项目');
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '本地新建');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final created = await (fixture.database.select(
      fixture.database.todoLists,
    )..where((row) => row.name.equals('本地新建'))).getSingle();
    expect(created.folderLocalId, projectsFolderId);
    expect(created.folderId, isNull, reason: '没有整数可写，别塞个 0 冒充');
  });

  testWidgets('编辑：预选当前归属，选「无」保存后真的移出，并留下同步记录', (tester) async {
    final fixture = await createFixture();
    final work = (await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    ))!;
    await pumpSheet(tester, fixture, existing: work);

    expectSelected(tester, '项目'); // FR-3：打开时必须预选当前归属
    final changesBefore = await syncRowCount(fixture);

    await pick(tester, '无');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final after = await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    );
    expect(after!.folderLocalId, isNull);
    expect(after.folderId, isNull);
    expect(
      await syncRowCount(fixture),
      greaterThan(changesBefore),
      reason: '移出必须进 outbox，否则另一台设备 pull 后组织关系不一致',
    );
  });

  testWidgets('只改名不动文件夹 ⇒ 不额外打一条移动记录', (tester) async {
    final fixture = await createFixture();
    final work = (await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    ))!;
    await pumpSheet(tester, fixture, existing: work);
    final changesBefore = await syncRowCount(fixture);

    await tester.enterText(find.widgetWithText(TextField, '清单名'), '工作改名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final after = await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    );
    expect(after!.name, '工作改名');
    expect(after.folderLocalId, projectsFolderId, reason: '归属不该被顺手改掉');
    expect(
      await syncRowCount(fixture),
      changesBefore + 1,
      reason: 'FR-4：一次改名只该有一条 outbox，不要"看着没动却同步了一次"',
    );
  });

  testWidgets('从文件夹里点新建：预选那个文件夹（隐式行为不能丢）', (tester) async {
    await pump(tester, folderLocalId: projectsFolderId);
    expectSelected(tester, '项目');
  });

  testWidgets('移动失败：弹层不关、清单名与已选归属都还在，且给可见提示', (tester) async {
    final fixture = await createFixture(
      overridesBuilder: (database) => [
        listRepositoryProvider.overrideWith(
          (ref) => _MoveFailingRepository(database, SyncChangeQueue(database)),
        ),
      ],
    );
    final work = (await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    ))!;
    await pumpSheet(tester, fixture, existing: work);

    await pick(tester, '无');
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '先别关');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      find.text('移动到文件夹失败，请重试'),
      findsOneWidget,
      reason: '静默早退等于告诉用户"保存成功了"',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '清单名'))
          .controller
          ?.text,
      '先别关',
      reason: '失败要留住已填内容',
    );
    expectSelected(tester, '无'); // 已选的归属不能被失败清空
    final after = await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    );
    expect(after!.folderLocalId, projectsFolderId, reason: '失败不能留下半改状态');
    expect(after.name, '工作', reason: '失败后也不该被顺手改名');
  });

  testWidgets('移入失败（原来没有归属）：已选的文件夹不能被失败清空', (tester) async {
    // 「移出失败」那条点的是「无」⇒ 它抓不住"失败时顺手把归属清掉"这个 bug：
    // 清空与"停在用户选的「无」"在界面上长一样（复核 P1，变异实测 10 条全绿）。
    // 这条从**无归属**的清单进入、选一个非 null 的文件夹，失败后必须还是它。
    final fixture = await createFixture(
      overridesBuilder: (database) => [
        listRepositoryProvider.overrideWith(
          (ref) => _MoveFailingRepository(database, SyncChangeQueue(database)),
        ),
      ],
    );
    final personal = (await listById(
      fixture.database,
      TodoVisualFixture.personalListId,
    ))!;
    expect(personal.folderLocalId, isNull, reason: '前提：这条清单本来不在任何文件夹里');
    await pumpSheet(tester, fixture, existing: personal);

    await pick(tester, '项目');
    expectSelected(tester, '项目');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      find.text('移动到文件夹失败，请重试'),
      findsOneWidget,
      reason: '移入与移出都是"移动"，失败都要看得见',
    );
    expectSelected(tester, '项目', reason: '失败后用户刚选的归属必须还在，不然重试要点第二遍');
    final after = await listById(
      fixture.database,
      TodoVisualFixture.personalListId,
    );
    expect(after!.folderLocalId, isNull, reason: '失败不该写库');
  });

  testWidgets('本地库还没就绪：不关弹层、给可见提示、不写库', (tester) async {
    // 复核第 2 轮 P2：FR-6 写着"仓库为 null / 移动抛错"两种失败都有提示，
    // 但 repo==null 那半句 0 覆盖（把它的 setState 摘掉，13 条全绿）。
    final fixture = await createFixture(
      overridesBuilder: (database) => [
        listRepositoryProvider.overrideWith((ref) => null),
      ],
    );
    final before = await fixture.database
        .select(fixture.database.todoLists)
        .get();
    await pumpSheet(tester, fixture);

    await pick(tester, '项目');
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '骑行');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      find.text('本地数据库尚未就绪，清单没能保存'),
      findsOneWidget,
      reason: 'provider 为 null 时原先是静默 return，用户以为保存成功',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '清单名'))
          .controller
          ?.text,
      '骑行',
      reason: '已填内容不能因为失败就没了',
    );
    expectSelected(tester, '项目', reason: '已选归属也要留着，等库就绪后直接重试');
    final after = await fixture.database
        .select(fixture.database.todoLists)
        .get();
    expect(after.length, before.length, reason: '这条路径一个字都不该写');
  });

  testWidgets('一个文件夹都没有时：只有「无」，保存照常可用', (tester) async {
    final fixture = await pump(
      tester,
      overridesBuilder: (database) => [
        foldersStreamProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );

    expectSelected(tester, '无');
    expect(await optionLabels(tester), ['无']);
    await pick(tester, '无');
    expectSelected(tester, '无', reason: '唯一候选也要真的点中，否则后面那句 isNull 是恒真的');

    await tester.enterText(find.widgetWithText(TextField, '清单名'), '读书');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final created = await (fixture.database.select(
      fixture.database.todoLists,
    )..where((row) => row.name.equals('读书'))).getSingle();
    expect(created.folderLocalId, isNull);
  });

  testWidgets('320px + 1.3 倍字号：名称、所属文件夹与按钮都排得下', (tester) async {
    await pump(
      tester,
      surface: const Size(320, 700),
      textScale: 1.3,
      folderLocalId: projectsFolderId,
    );

    expect(tester.takeException(), isNull, reason: '弹层在 320px + 1.3 下溢出');
    expect(find.text('所属文件夹'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    // openMenu 自带"菜单真的展开了"的断言：少了它，下面那句「展开的候选菜单不溢出」
    // 就永远在测收起态（删掉那次 tap 也照样 10 条全绿，实测）。
    await openMenu(tester);
    expect(tester.takeException(), isNull, reason: '展开的候选菜单在 320px + 1.3 下溢出');
    expect(find.text('项目'), findsWidgets);
  });

  testWidgets('读屏：一个节点同时念出「所属文件夹」与当前值，且仍是按钮', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    // 实测：不合并时字段自己的节点 label 只有「无」（flags 里带 isButton），
    // 读屏用户听到的是"无 按钮"，不知道什么的"无"。
    expect(
      find.bySemanticsLabel(RegExp(r'所属文件夹[\s\S]*无')),
      findsOneWidget,
      reason: '控件标签与当前值要一起被念出来',
    );
    final data = tester
        .getSemantics(find.byKey(folderFieldKey))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue, reason: '合并语义不能把"这是个按钮"丢掉');

    await pick(tester, '项目');
    expect(
      find.bySemanticsLabel(RegExp(r'所属文件夹[\s\S]*项目')),
      findsOneWidget,
      reason: '正向对照：念的要是当前值，不是固定字样',
    );
    expect(
      find.bySemanticsLabel(RegExp(r'所属文件夹[\s\S]*无')),
      findsNothing,
      reason: '改选后还念旧值 ⇒ 读屏看到的是上一个选择',
    );

    handle.dispose();
  });

  testWidgets('文件夹列表晚到：占位换成真名，之后再来一次也不覆盖已选', (tester) async {
    // 必须是 broadcast：单订阅的 `close()` 要等"有人订阅完"才回，
    // 一旦实现退化成"根本不 watch 这个 provider"（对照组 PA 就是），
    // tearDown 会永久挂住，探针报不出红只报一个文件级错误。
    final controller = StreamController<List<TodoFolder>>.broadcast();
    addTearDown(controller.close);
    final fixture = await createFixture(
      overridesBuilder: (database) => [
        foldersStreamProvider.overrideWith((ref) => controller.stream),
      ],
    );
    final folders = await fixture.database
        .select(fixture.database.todoFolders)
        .get();
    await pumpSheet(tester, fixture, folderLocalId: projectsFolderId);

    // 首帧：库里有归属，但候选还没到齐 ⇒ 不能崩，也不能显示成「无」
    expectSelected(tester, '加载中…');

    controller.add(folders);
    await tester.pumpAndSettle();
    expectSelected(tester, '项目');

    await pick(tester, '无');
    controller.add(folders);
    await tester.pumpAndSettle();
    expectSelected(tester, '无', reason: '迟到的列表只该补充候选，不该把用户刚做的选择顶回去');
  });

  testWidgets('归属指向已删除的文件夹：显示「（已删除）」而不是断言崩掉', (tester) async {
    final fixture = await createFixture(
      overridesBuilder: (database) => [
        foldersStreamProvider.overrideWith(
          (ref) => Stream<List<TodoFolder>>.value(const <TodoFolder>[]),
        ),
      ],
    );
    final work = (await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    ))!;
    await pumpSheet(tester, fixture, existing: work);

    expectSelected(tester, '（已删除）');
    expect(
      tester.takeException(),
      isNull,
      reason: 'DropdownButton 会断言"恰好一项与 value 相同"',
    );
    expect(await optionLabels(tester), ['无', '（已删除）']);
  });
}

/// 选中的值要断言"界面上那个字"，不能只断言 `value` 字段：
/// value 是文件夹 id，用户看到的是名字，两者串了才是真 bug。
void expectSelected(WidgetTester tester, String label, {String? reason}) {
  expect(
    find.descendant(of: find.byKey(folderFieldKey), matching: find.text(label)),
    findsOneWidget,
    reason: '「所属文件夹」这一格当前值要显示「$label」。${reason ?? ''}',
  );
}

/// 只让"移入/移出文件夹"失败，改名走真库 ⇒ 钉住失败那一条分支。
class _MoveFailingRepository extends ListRepository {
  _MoveFailingRepository(super.db, super.queue);

  @override
  Future<TodoList> moveToFolder(String listId, String? folderLocalId) {
    throw StateError('文件夹服务不可用');
  }
}
