import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md》
/// `:6`「为任务添加「时间」、「标签」、「优先级」等属性，方便过滤器进行多维度筛选」、
/// `:61`「高级筛选通过逻辑词：“或”、“且”以及清单、日期、优先级、标签等筛选条件可以进行多语句查询」
/// —— 工作区这张「高级筛选」对话框里今天没有「标签」这一条筛选条件（FL Issue #420）。
final _t = DateTime(2026, 7, 11, 9);

const _tagSectionKey = Key('task-filter-tag-section');

Future<void> _openAdvancedDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-filter-menu')));
  await tester.pumpAndSettle();
  final advanced = find.byKey(const Key('todo-filter-advanced'));
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
  final chip = find.widgetWithText(FilterChip, name);
  expect(chip, findsOneWidget, reason: '「标签」小节里没有名为「$name」的选项');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

String _panelTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('task-filter-advanced-preview-panel')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .join('｜');
}

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  List<Override> Function(AppDatabase database)? overridesBuilder,
  Size? surface,
  double textScale = 1,
}) async {
  final fixture = await TodoVisualFixture.create(
    overridesBuilder: overridesBuilder,
  );
  addTearDown(fixture.dispose);
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: TasksByListPage(hideAppBar: true)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  testWidgets('高级筛选对话框里有「标签」小节，选项来自标签列表', (tester) async {
    await _pump(tester);
    await _openAdvancedDialog(tester);

    expect(
      find.byKey(_tagSectionKey),
      findsOneWidget,
      reason: '嘀嗒《05-过滤器》`:6`/`:61` 把「标签」列为筛选条件之一 —— 这张对话框里没有这一格',
    );
    for (final name in const ['专注', '评审', '跟进', '协作']) {
      expect(
        find.widgetWithText(FilterChip, name),
        findsOneWidget,
        reason: '「$name」是 fixture 里已存在的标签，小节应把它列成可选项',
      );
    }
  });

  testWidgets('选标签后预览按「且」算，取消选择回到原状', (tester) async {
    await _pump(tester);
    await _openAdvancedDialog(tester);
    await _enablePreview(tester);

    await _tapTag(tester, '专注');
    expect(
      _panelTexts(tester),
      contains('命中 1 项'),
      reason: '只有 metadata 那条带「专注」',
    );

    await _tapTag(tester, '评审');
    expect(
      _panelTexts(tester),
      contains('命中 1 项'),
      reason: '缺省按「且」⇒ 要同时带这两个标签，只剩 metadata 一条',
    );

    await _tapTag(tester, '专注');
    expect(
      _panelTexts(tester),
      contains('命中 2 项'),
      reason: '只剩「评审」⇒ metadata 与 long-content 两条都命中',
    );
  });

  testWidgets('应用带标签的条件后，筛选条上能看见它已生效', (tester) async {
    await _pump(tester);
    await _openAdvancedDialog(tester);
    await _tapTag(tester, '专注');

    await tester.tap(find.text('应用高级筛选'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('todo-filter-advanced')),
        matching: find.text('标签'),
      ),
      findsOneWidget,
      reason: '标签条件没写进 TaskFilter，或高级筛选入口的标签没跟着显示',
    );
  });

  testWidgets('四件套①：320 宽 + 1.3 倍字号在对话框自己的 context 里不溢出', (tester) async {
    await _pump(tester, surface: const Size(320, 600), textScale: 1.3);
    await _openAdvancedDialog(tester);

    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byKey(_tagSectionKey)),
    );
    expect(
      scaler.scale(10),
      closeTo(13, 0.001),
      reason: '档位没进到这张对话框自己的 context',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('四件套②：每个标签选项有独立的读屏语义与选中态', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await _openAdvancedDialog(tester);

    expect(
      find.bySemanticsLabel('标签 专注，未选中'),
      findsOneWidget,
      reason: '读屏要能单独念出这条标签和它的选中态，不能只靠 chip 里的文字',
    );
    await _tapTag(tester, '专注');
    expect(find.bySemanticsLabel('标签 专注，已选中'), findsOneWidget);
    // 句柄要在测试体里收尾（`addTearDown` 太晚：绑定在测试体结束时就把未 dispose 的句柄判失败）
    handle.dispose();
  });

  testWidgets('四件套③：标签读不出来要给可见提示，且别的条件不丢', (tester) async {
    var errored = false;
    await _pump(
      tester,
      overridesBuilder: (database) => [
        tagsStreamProvider.overrideWith((ref) {
          errored = true;
          return Stream<List<TodoTag>>.error(StateError('标签读不出来'));
        }),
      ],
    );
    await _openAdvancedDialog(tester);

    expect(errored, isTrue, reason: '没把标签流换成错误分支就是假测');
    expect(
      find.descendant(
        of: find.byKey(_tagSectionKey),
        matching: find.textContaining('标签暂不可用'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('task-filter-keyword')),
      '写进关键词',
    );
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('task-filter-keyword')),
    );
    expect(field.controller!.text, '写进关键词', reason: '标签读失败不该把这张对话框里已填的条件一起清掉');
    expect(tester.takeException(), isNull);
  });

  testWidgets('四件套④：标签流后到一次，不该清掉已选中的标签', (tester) async {
    final controller = StreamController<List<TodoTag>>();
    addTearDown(controller.close);
    await _pump(
      tester,
      overridesBuilder: (database) => [
        tagsStreamProvider.overrideWith((ref) => controller.stream),
      ],
    );
    controller.add([
      TodoTag(
        id: 'tag-a',
        name: '甲',
        color: '#888888',
        isPinned: false,
        updatedAt: _t,
        createdAt: _t,
      ),
    ]);
    await _openAdvancedDialog(tester);
    await _tapTag(tester, '甲');

    controller.add([
      TodoTag(
        id: 'tag-a',
        name: '甲',
        color: '#888888',
        isPinned: false,
        updatedAt: _t,
        createdAt: _t,
      ),
      TodoTag(
        id: 'tag-b',
        name: '乙',
        color: '#999999',
        isPinned: false,
        updatedAt: _t,
        createdAt: _t,
      ),
    ]);
    await tester.pumpAndSettle();

    final chip = find.widgetWithText(FilterChip, '甲');
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
  });
}
