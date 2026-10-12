import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';

/// FL Issue #524（矩阵 #22 面 ⑥）第三刀：跨条件的「且 / 或」要能在面板里选。
///
/// 门槛抄服务端 `TodoFilterServiceImpl.java:644-660`：词只能挂在**已启用**且**非第一条**的条件上，
/// 所以小节只在已启用条件 ≥2 条时出现，并且第一条（按 `CONDITION_ORDER` 排）根本不给开关 ——
/// 摆一个服务端会整份拒绝的档位，等于给用户一个按下去就存不进去的按钮。
const _sectionKey = Key('task-filter-condition-logic');

Future<void> _pump(WidgetTester tester) async {
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
}

/// 面板是 showModalBottomSheet：套用后对话框关闭、面板仍开着；再点图标会被模态遮罩吃掉并关掉面板。
Future<void> _openAdvanced(WidgetTester tester) async {
  if (find.byKey(const Key('todo-filter-advanced')).evaluate().isEmpty) {
    final menu = find.byKey(const Key('todo-filter-menu'));
    expect(menu, findsOneWidget, reason: '头部找不到筛选入口');
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }
  final advanced = find.byKey(const Key('todo-filter-advanced'));
  expect(advanced, findsOneWidget, reason: '筛选面板里没有「高级」这条条件');
  await tester.ensureVisible(advanced);
  await tester.pumpAndSettle();
  await tester.tap(advanced);
  await tester.pumpAndSettle();
}

Future<void> _typeKeyword(WidgetTester tester, String value) async {
  final field = find.widgetWithText(TextField, '关键词（标题或正文）');
  expect(field, findsOneWidget, reason: '高级筛选里没有关键词输入框');
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _selectTag(WidgetTester tester, String name) async {
  final chip = find.descendant(
    of: find.byKey(const Key('task-filter-tag-section')),
    matching: find.widgetWithText(FilterChip, name),
  );
  expect(chip, findsOneWidget, reason: '「标签」小节里没有名为「$name」的选项');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _enablePreview(WidgetTester tester) async {
  final toggle = find.byKey(const Key('task-filter-advanced-preview'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  if (!tester.widget<Switch>(toggle).value) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
}

Future<void> _tapLogic(WidgetTester tester, String key, String label) async {
  final chip = find.descendant(
    of: find.byKey(Key('task-filter-condition-logic-$key')),
    matching: find.widgetWithText(ChoiceChip, label),
  );
  expect(chip, findsOneWidget, reason: '「$key」那一档没有「$label」开关');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

bool _isSelected(WidgetTester tester, String key, String label) => tester
    .widget<ChoiceChip>(
      find.descendant(
        of: find.byKey(Key('task-filter-condition-logic-$key')),
        matching: find.widgetWithText(ChoiceChip, label),
      ),
    )
    .selected;

int _hits(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('task-filter-advanced-preview-panel')),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .join('｜');
  final match = RegExp(r'命中 (\d+) 项').firstMatch(texts);
  expect(match, isNotNull, reason: '预览面板里没有可解析的「命中 N 项」：$texts');
  return int.parse(match!.group(1)!);
}

void main() {
  testWidgets('不足两条已启用条件时不给跨条件开关：一条条件切「且/或」没有可观察差异', (tester) async {
    await _pump(tester);
    await _openAdvanced(tester);
    expect(
      find.byKey(_sectionKey),
      findsNothing,
      reason: '空条件时摆一个逻辑词小节毫无意义，还会让断言恒真',
    );

    await _typeKeyword(tester, '跨端');
    expect(
      find.byKey(_sectionKey),
      findsNothing,
      reason: '只启用一条条件（关键词）时，它前面没有条件可连',
    );
  });

  testWidgets('两条已启用条件才出现开关，且第一条按 CONDITION_ORDER 不给开关', (tester) async {
    await _pump(tester);
    await _openAdvanced(tester);
    await _typeKeyword(tester, '跨端');
    await _selectTag(tester, '专注');

    expect(find.byKey(_sectionKey), findsOneWidget);
    // CONDITION_ORDER：tagIds 在 keyword 之前 ⇒ 词只能挂给 keyword。
    expect(
      find.byKey(const Key('task-filter-condition-logic-tagIds')),
      findsNothing,
      reason: '第一条已启用条件前面没有条件可连，服务端会整份拒绝',
    );
    expect(
      find.byKey(const Key('task-filter-condition-logic-keyword')),
      findsOneWidget,
    );
  });

  testWidgets('切到「或」真的改预览命中数，切回「且」能复原', (tester) async {
    await _pump(tester);
    await _openAdvanced(tester);
    await _enablePreview(tester);
    await _typeKeyword(tester, '跨端');
    await _selectTag(tester, '专注');

    // 夹具里「专注」只挂在「准备项目周会材料」上，「跨端」只出现在「整理跨端交互验收反馈」标题里
    // ⇒ 两条同时成立的一条都没有，任一成立则有两条：0 → 2 → 0 才叫真的跟着档位走。
    expect(_hits(tester), 0, reason: '且：标签与关键词要同时成立');
    await _tapLogic(tester, 'keyword', '或');
    expect(_hits(tester), 2, reason: '或：任一成立即命中');
    await _tapLogic(tester, 'keyword', '且');
    expect(_hits(tester), 0, reason: '切回来要能复原，档位不是单向的');
  });

  testWidgets('应用后重开对话框仍是那一档，开关也有读屏名', (tester) async {
    await _pump(tester);
    await _openAdvanced(tester);
    await _typeKeyword(tester, '跨端');
    await _selectTag(tester, '专注');
    await _tapLogic(tester, 'keyword', '或');
    await tester.tap(find.text('应用高级筛选'));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    await _openAdvanced(tester);
    expect(find.byKey(_sectionKey), findsOneWidget);
    expect(
      _isSelected(tester, 'keyword', '或'),
      isTrue,
      reason: '档位要跟着筛选态，重开读得回',
    );
    expect(_isSelected(tester, 'keyword', '且'), isFalse);
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('task-filter-condition-logic-keyword-or')),
          )
          .label,
      contains('关键词'),
      reason: '每一档要念得出它连的是哪条条件',
    );
    handle.dispose();
  });
}
