import 'package:drift/drift.dart' show Value;
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zh_cloud_todo_flutter/core/settings/quick_add_action_bar_setting.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';

import '../../support/todo_visual_fixture.dart';

/// FL #344 面①：快速添加底部功能栏（产品裁决：默认序 日期→优先级→标签→清单，可调序）。
///
/// 判据源《01-添加任务.md》`:17`（四属性）+ `:24`（顺序支持自定义）。
/// v1（opencode 交叉验证的降面积路线）：渲染**从配置读**（读不到=默认序），
/// 编辑入口放第二步 —— 但路径必须走配置，硬编码会把"推迟"变成"返工"。
void main() {
  /// ⚠️ 不用 pumpAndSettle：sheet 里 SharedPreferences 读取 + NLP listener
  /// 会让"静止"永远等不到（既有 quick_add_save_reentry_test 全部用固定步 pump ——
  /// 本文件第一版用 pumpAndSettle 直接 10 分钟超时）。
  Future<void> pumpSheet(WidgetTester tester, TodoVisualFixture fixture) async {
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
    // 给 initState 里的两次 read().then 留时间
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 弹层操作：tap → 逐步 pump（showModalBottomSheet 进出场动画 + NLP）。
  Future<void> pumpSteps(WidgetTester tester, {int n = 14}) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 收尾（subtask 测试同款）：先拆树再推过 SnackBar/去抖窗口。
  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
  }

  testWidgets('默认序四个功能位都在，顺序为 日期→优先级→标签→清单', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await pumpSheet(tester, fixture);

    expect(find.byKey(const Key('todo-quick-add-bar-date')), findsOneWidget);
    expect(
      find.byKey(const Key('todo-quick-add-bar-priority')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('todo-quick-add-bar-tag')), findsOneWidget);
    expect(find.byKey(const Key('todo-quick-add-bar-list')), findsOneWidget);
    // 顺序：底栏四个位的横向顺序必须等于配置序
    final xs = <double>[];
    for (final key in const [
      'todo-quick-add-bar-date',
      'todo-quick-add-bar-priority',
      'todo-quick-add-bar-tag',
      'todo-quick-add-bar-list',
    ]) {
      final box = tester.renderObject<RenderBox>(find.byKey(Key(key)));
      xs.add(box.localToGlobal(Offset.zero).dx);
    }
    expect(
      xs,
      orderedEquals(xs..sort()),
      reason:
          '配置序（渲染从配置读）必须在屏上保持单调递增 —— '
          '错序=渲染没走配置路径',
    );

    await settleTimers(tester);
  });

  // setting 层判据用普通 test（不需要 widget 环境 —— testWidgets 里挂
  // SharedPreferences 会让收尾的 pending-timer 检查误伤；本文件已有 10 分钟超时的前科）。
  test('配置：默认读回默认序；写侧校验缺项/重复拒收', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final setting = QuickAddActionBarSetting();
    expect(await setting.read(), QuickAddActionBarSetting.defaultOrder);
    // 写一个合法序，读回来
    await setting.write(['tag', 'date', 'list', 'priority']);
    expect(await setting.read(), [
      'tag',
      'date',
      'list',
      'priority',
    ], reason: '合法的自定义序必须能存取 —— v1 不给编辑入口，但路径必须走配置');
    // 缺项拒收
    expect(
      () => setting.write(['date', 'priority', 'tag']),
      throwsArgumentError,
      reason: '写侧必须校验（不重复、不缺项、只认已知 id）—— 坏数据会让底栏少按钮',
    );
    expect(
      () => setting.write(['date', 'date', 'tag', 'list']),
      throwsArgumentError,
    );
    expect(
      () => setting.write(['date', 'priority', 'tag', 'list', 'bogus']),
      throwsArgumentError,
      reason: '未知 id 拒收（id 用稳定 wire 名，不认界面文案）',
    );
    // reset 回默认
    await setting.reset();
    expect(await setting.read(), QuickAddActionBarSetting.defaultOrder);
  });

  testWidgets('手选日期压着 NLP 识别（用户最后的动作最大）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await pumpSheet(tester, fixture);

    // 手选「明天」
    await tester.tap(find.byKey(const Key('todo-quick-add-bar-date')));
    await pumpSteps(tester);
    await tester.tap(find.text('明天'));
    await pumpSteps(tester);

    // 再输入一个 NLP 会识别出时间的标题
    await tester.enterText(find.byType(TextField), '明天 9 点开会');
    await pumpSteps(tester);

    // 手选过 ⇒ 识别行不出现（手选压着识别），日期 chip 高亮
    expect(
      find.byKey(const Key('todo-quick-add-recognized-date')),
      findsNothing,
      reason: '手选日期后识别行不该出现 —— 手选（用户最后的动作）最大',
    );
    expect(
      find.text('已选日期'),
      findsOneWidget,
      reason: '手选过日期 ⇒ chip 文案变为「已选日期」（高亮的可见形态）',
    );

    // 保存 ⇒ dueAt 是手选的那个（不是 NLP 解析的时刻）。
    // create 有两级 await（defaults + repo.create），多给几步 pump。
    await tester.tap(find.text('保存'));
    await pumpSteps(tester, n: 30);
    final rows = await (fixture.database.select(
      fixture.database.todoTasks,
    )..where((r) => r.title.equals('明天 9 点开会'))).get();
    expect(rows, hasLength(1), reason: 'fixture 有种子任务 —— 按标题过滤');
    final manualDay = DateTime.now().add(const Duration(days: 1));
    expect(
      rows.single.dueAt?.year == manualDay.year &&
          rows.single.dueAt?.month == manualDay.month &&
          rows.single.dueAt?.day == manualDay.day,
      isTrue,
      reason: 'dueAt 必须是手选的「明天」那一天（NLP 的 9 点不该赢过手选）',
    );

    await settleTimers(tester);
  });

  testWidgets('长按日期 chip 清除手选（与桌面底栏逐字对齐）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await pumpSheet(tester, fixture);

    await tester.tap(find.byKey(const Key('todo-quick-add-bar-date')));
    await pumpSteps(tester);
    await tester.tap(find.text('明天'));
    await pumpSteps(tester);
    expect(find.text('已选日期'), findsOneWidget);

    await tester.longPress(find.byKey(const Key('todo-quick-add-bar-date')));
    await pumpSteps(tester);
    expect(
      find.text('已选日期'),
      findsNothing,
      reason: '长按=清除（桌面底栏口径）⇒ chip 文案回到「日期」',
    );

    await settleTimers(tester);
  });

  testWidgets('切清单联动清空 sectionId（分区属于原清单）', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    // 造第二个清单
    final now = DateTime.now();
    await fixture.database
        .into(fixture.database.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-other',
            name: '另一个清单',
            sortOrder: const Value(2),
            updatedAt: now,
            createdAt: now,
          ),
        );
    await pumpSheet(tester, fixture);

    // 切到另一个清单
    await tester.tap(find.byKey(const Key('todo-quick-add-bar-list')));
    await pumpSteps(tester, n: 30);
    final otherList = find.text('另一个清单');
    await tester.ensureVisible(otherList);
    await tester.tap(otherList);
    await pumpSteps(tester);

    await tester.enterText(find.byType(TextField), '在别的清单建');
    await tester.tap(find.text('保存'));
    await pumpSteps(tester, n: 30);

    final rows = await (fixture.database.select(
      fixture.database.todoTasks,
    )..where((r) => r.title.equals('在别的清单建'))).get();
    expect(rows, hasLength(1), reason: 'fixture 有种子任务 —— 按标题过滤');
    expect(rows.single.listId, 'list-other');
    expect(
      rows.single.sectionId,
      isNull,
      reason:
          'FL #344：切清单必须清空 sectionId —— 分区属于原清单，'
          '保留会撞 _requireSectionInList 直接抛 StateError',
    );

    await settleTimers(tester);
  });

  // ── FL #344 第二步：顺序编辑器（`:24`「点击「...」-「设置」」）──

  // ⚠️ 不用 pumpAndSettle：sheet 的 SharedPreferences/NLP listener 让"静止"
  // 等不到（specs/164 教训 —— 本文件曾有 10 分钟超时前科）。
  Future<void> openEditorFromBar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-quick-add-bar-edit-order')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> closeEditorAndSettle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('「...」打开顺序编辑器：上移保存 ⇒ 底栏顺序真的变了（`:24`）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await pumpSheet(tester, fixture);

    // 默认序：日期 → 优先级 → 标签 → 清单（屏幕坐标单调递增）
    final before = tester
        .getTopLeft(find.byKey(const Key('todo-quick-add-bar-date')))
        .dx;
    final before2 = tester
        .getTopLeft(find.byKey(const Key('todo-quick-add-bar-tag')))
        .dx;
    expect(before2, greaterThan(before));

    await openEditorFromBar(tester);
    expect(
      find.byKey(const Key('todo-bar-order-row-tag')),
      findsOneWidget,
      reason: '编辑器要列出全部四个功能位',
    );

    // 把「标签」上移一位（date → tag → priority → list）
    await tester.tap(find.byKey(const Key('todo-bar-order-up-tag')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('todo-bar-order-save')));
    await closeEditorAndSettle(tester);

    // 底栏顺序真的变了：tag 在 date 前面
    // 底栏顺序真的变了：一次「上移」= 上移一位（date,tag,priority,list）
    // ⇒ tag 落第二位：在 date 之后、priority 之前。
    // 探针已证写侧（E saved=date,tag,priority,list），这条咬渲染。
    final afterTag = tester
        .getTopLeft(find.byKey(const Key('todo-quick-add-bar-tag')))
        .dx;
    final afterPriority = tester
        .getTopLeft(find.byKey(const Key('todo-quick-add-bar-priority')))
        .dx;
    expect(
      afterTag,
      lessThan(afterPriority),
      reason: '保存后底栏必须按新序渲染（渲染从配置读 —— specs/164 的 v1 路径）',
    );

    await settleTimers(tester);
  });

  testWidgets('编辑器「恢复默认」⇒ 回默认序且落库', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    // 先写一个非默认序
    await QuickAddActionBarSetting().write(['tag', 'date', 'list', 'priority']);
    await pumpSheet(tester, fixture);

    await openEditorFromBar(tester);
    await tester.tap(find.byKey(const Key('todo-bar-order-reset')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('todo-bar-order-save')));
    await closeEditorAndSettle(tester);

    final saved = await QuickAddActionBarSetting().read();
    expect(saved, QuickAddActionBarSetting.defaultOrder);
    // 底栏回默认：date 在 tag 前
    final dateX = tester
        .getTopLeft(find.byKey(const Key('todo-quick-add-bar-date')))
        .dx;
    final tagX = tester
        .getTopLeft(find.byKey(const Key('todo-quick-add-bar-tag')))
        .dx;
    expect(dateX, lessThan(tagX));

    await settleTimers(tester);
  });
}
