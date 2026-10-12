import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《05-过滤器》`:71`「……并且，在同一个筛选条件（仅标签支持）内，也可以选择使用“且”逻辑、“或”逻辑。」
///
/// FL Issue #334 面 ①的第三刀：标签小节里要能切「且 / 或」，而且切了要真的改结果。
/// 档位只在**选了 ≥2 个标签**时出现：零个或一个标签时「且」「或」结果相同，常驻一个没意义的开关
/// 既占界面又会让断言恒真（本仓踩过「chip 标签常驻 ⇒ textContaining 恒真」的坑）。
const _tagSectionKey = Key('task-filter-tag-section');
const _tagLogicKey = Key('task-filter-tag-logic');

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

Future<void> _openAdvanced(WidgetTester tester) async {
  // 面板是 `showModalBottomSheet`：套用一个条件后对话框关闭、面板仍开着（实测 `todo-filter-advanced`
  // 还在树上）。这时再点 header 上的筛选图标会被模态遮罩吃掉、顺手把面板关掉，
  // 所以面板在就直奔「高级」那颗 chip，不在才去开面板。
  if (find.byKey(const Key('todo-filter-advanced')).evaluate().isEmpty) {
    final menu = find.byKey(const Key('todo-filter-menu'));
    expect(menu, findsOneWidget, reason: '工作区头部找不到筛选入口');
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

Future<void> _enablePreview(WidgetTester tester) async {
  final toggle = find.byKey(const Key('task-filter-advanced-preview'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  if (!tester.widget<Switch>(toggle).value) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
}

Future<void> _tapTag(WidgetTester tester, String name) async {
  final chip = find.descendant(
    of: find.byKey(_tagSectionKey),
    matching: find.widgetWithText(FilterChip, name),
  );
  expect(chip, findsOneWidget, reason: '「标签」小节里没有名为「$name」的选项');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _tapLogic(WidgetTester tester, String label) async {
  final chip = find.descendant(
    of: find.byKey(_tagLogicKey),
    matching: find.widgetWithText(ChoiceChip, label),
  );
  expect(chip, findsOneWidget, reason: '逻辑词开关里没有「$label」这一档');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

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
  testWidgets('标签不足两个时不出现逻辑词开关，选到两个才出现', (tester) async {
    await _pump(tester);
    await _openAdvanced(tester);

    expect(
      find.byKey(_tagLogicKey),
      findsNothing,
      reason: '没选标签时「且/或」没有意义，不该占一个开关',
    );

    await _tapTag(tester, '专注');
    expect(
      find.byKey(_tagLogicKey),
      findsNothing,
      reason: '只有一个标签时两档结果相同，出现开关只会让人以为切了有用',
    );

    await _tapTag(tester, '评审');
    expect(find.byKey(_tagLogicKey), findsOneWidget);

    // 反向走一遍：退回一个标签，开关要跟着收回（档位只在 ≥2 个标签时才有意义）。
    await _tapTag(tester, '评审');
    expect(
      find.byKey(_tagLogicKey),
      findsNothing,
      reason: '只剩一个标签时开关该消失，否则界面会摆一个改不动也没用的档位',
    );
  });

  testWidgets('从「且」切到「或」，预览命中数真的变，不是只有开关状态变了', (tester) async {
    await _pump(tester);
    await _openAdvanced(tester);
    await _enablePreview(tester);

    await _tapTag(tester, '专注');
    await _tapTag(tester, '评审');
    expect(_hits(tester), 1, reason: '缺省「且」：要同时带这两个标签');

    await _tapLogic(tester, '或');
    expect(_hits(tester), 2, reason: '「或」：任一带其一的都算命中');

    await _tapLogic(tester, '且');
    expect(_hits(tester), 1, reason: '切回来要能复原，档位不是单向的');
  });

  testWidgets('应用「或」档后重开对话框仍是「或」，且两档有读屏语义', (tester) async {
    await _pump(tester);
    await _openAdvanced(tester);
    await _tapTag(tester, '专注');
    await _tapTag(tester, '评审');
    await _tapLogic(tester, '或');
    await tester.tap(find.text('应用高级筛选'));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    await _openAdvanced(tester);
    expect(find.byKey(_tagLogicKey), findsOneWidget);

    // 档位是不是真的跟着 `TaskFilter`，读 chip 自己的 selected（不是只看开关出没出现）。
    bool isSelected(String label) => tester
        .widget<ChoiceChip>(
          find.descendant(
            of: find.byKey(_tagLogicKey),
            matching: find.widgetWithText(ChoiceChip, label),
          ),
        )
        .selected;
    expect(isSelected('或'), isTrue, reason: '套用「或」后重开要还是「或」，否则档位没进筛选态');
    expect(isSelected('且'), isFalse, reason: '两档互斥，不该同时选中');

    // 读屏名要挂在每档自己的节点上（全树 bySemanticsLabel 会被旁侧文案满足，量不出这一档）。
    final andLabel = tester
        .getSemantics(find.byKey(const Key('task-filter-tag-logic-and')))
        .label;
    final orLabel = tester
        .getSemantics(find.byKey(const Key('task-filter-tag-logic-or')))
        .label;
    expect(andLabel, contains('且'), reason: '「且」档念不出来：$andLabel');
    expect(orLabel, contains('或'), reason: '「或」档念不出来：$orLabel');
    expect(andLabel, contains('标签逻辑'));
    expect(orLabel, contains('标签逻辑'));
    handle.dispose();
  });
}
