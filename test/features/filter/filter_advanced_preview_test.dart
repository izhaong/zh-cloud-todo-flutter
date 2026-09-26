import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《05-过滤器》`:65`「如果不确定自己的筛选条件设置的是否合理，也可以点击「预览模式」
/// 查看显示效果哦」——本面挂在既有的「高级筛选」对话框里（`:57` 起的小节）。
const _previewToggleKey = Key('task-filter-advanced-preview');
const _previewPanelKey = Key('task-filter-advanced-preview-panel');

Future<void> _openAdvancedDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-filter-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('todo-filter-advanced')));
  await tester.pumpAndSettle();
}

Future<void> _setToggle(WidgetTester tester, bool value) async {
  final toggle = find.byKey(_previewToggleKey);
  expect(
    toggle,
    findsOneWidget,
    reason: '「预览模式」开关不存在 —— 嘀嗒《05-过滤器》`:65` 那一面没落地',
  );
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  if (tester.widget<Switch>(toggle).value != value) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
}

/// 预览区里所有可见文案拼成一条串，用来判"预览算的是条件，不是把列表抄一遍"。
String _panelTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(_previewPanelKey),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .join('｜');
}

Future<int> _syncChangeCount(TodoVisualFixture fixture) async =>
    (await fixture.database.select(fixture.database.todoSyncChanges).get())
        .length;

void main() {
  Future<TodoVisualFixture> pumpWorkspace(WidgetTester tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
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
    return fixture;
  }

  testWidgets('高级筛选默认不开预览模式，也不显示预览区', (tester) async {
    await pumpWorkspace(tester);
    await _openAdvancedDialog(tester);

    final toggle = find.byKey(_previewToggleKey);
    expect(toggle, findsOneWidget, reason: '`:65`「预览模式」这一格应存在');
    expect(tester.widget<Switch>(toggle).value, isFalse, reason: '默认应为关');
    expect(
      find.byKey(_previewPanelKey),
      findsNothing,
      reason: '关的时候不该先摆一个空的预览区',
    );
  });

  testWidgets('开预览后只显示命中的任务，且不改写生效中的筛选', (tester) async {
    final semantics = tester.ensureSemantics();
    final fixture = await pumpWorkspace(tester);
    await _openAdvancedDialog(tester);
    final changesBefore = await _syncChangeCount(fixture);

    await _setToggle(tester, true);
    expect(find.byKey(_previewPanelKey), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('task-filter-keyword')),
      '视觉评审',
    );
    await tester.pumpAndSettle();

    // R2：预览区只列命中的那条；不命中的那条不进预览区。
    final texts = _panelTexts(tester);
    expect(texts, contains('命中 1 项'), reason: 'R6 读屏语义的落点：命中数要念得出');
    expect(texts, contains('完成 Todo 工作区视觉评审'));
    expect(
      texts,
      isNot(contains('准备项目周会材料')),
      reason: '不命中的任务不该进预览区 ⇒ 预览真在算条件，不是把整列表抄一遍',
    );

    // R3/R4：预览只算不套——承载生效值的那格文案仍是未设高级筛选时的
    // `_advancedFilterLabel` 空态名（'高级'），不是设了关键词后的 '关键词'。
    expect(
      find.descendant(
        of: find.byKey(const Key('todo-filter-advanced')),
        matching: find.text('高级'),
      ),
      findsOneWidget,
      reason: '关键词不该在预览态就爬上生效中的筛选格',
    );
    expect(
      await _syncChangeCount(fixture),
      changesBefore,
      reason: '预览不产生任何同步 outbox 写入',
    );

    // R6：开关自身有读屏语义。
    expect(
      find.bySemanticsLabel(RegExp('预览模式')),
      findsWidgets,
      reason: '开关要念得出「预览模式」',
    );
    semantics.dispose();
  });

  testWidgets('关掉预览再打开，先前输入的草稿仍在', (tester) async {
    await pumpWorkspace(tester);
    await _openAdvancedDialog(tester);

    await _setToggle(tester, true);
    await tester.enterText(
      find.byKey(const Key('task-filter-keyword')),
      '视觉评审',
    );
    await tester.pumpAndSettle();
    expect(_panelTexts(tester), contains('命中 1 项'));

    await _setToggle(tester, false);
    expect(find.byKey(_previewPanelKey), findsNothing);

    await _setToggle(tester, true);
    expect(
      _panelTexts(tester),
      contains('命中 1 项'),
      reason: '预览开关不该吞掉用户已填的草稿（关掉再开还是同一套条件）',
    );
  });
}
