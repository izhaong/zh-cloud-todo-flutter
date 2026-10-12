import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// FL #493 的另一面：高级筛选对话框里的「标签」小节。
///
/// 批量那面改之前是同一个症状——零标签时只给一句「暂无可选择的标签」，不给就地建。
/// 判据打在对话框的小节上：零标签时必须有「新建标签」一行，建出来即选中；
/// 标签流读失败（unavailable）时不给建（读不出列表时建完也没法选）。
Future<void> _pump(WidgetTester tester, TodoVisualFixture fixture) async {
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

/// 建标签那一行在 320 宽的对话框里可能落在可视区外，直接 tap 会打到遮罩上把对话框关掉
/// —— 关掉之后「同名只有一条」这类断言会假绿，所以先 ensureVisible 再断言对话框还在。
Future<void> _createTag(WidgetTester tester, String name) async {
  final input = find.byKey(const Key('task-filter-new-tag-input'));
  await tester.ensureVisible(input);
  await tester.pumpAndSettle();
  await tester.enterText(input, name);
  final button = find.byKey(const Key('task-filter-create-tag'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(
    find.text('应用高级筛选'),
    findsOneWidget,
    reason: '点「添加」把对话框弄关了，后面的断言就不是在量这张对话框',
  );
}

Future<void> _openAdvancedDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-filter-menu')));
  await tester.pumpAndSettle();
  final advanced = find.byKey(const Key('todo-filter-advanced'));
  await tester.ensureVisible(advanced);
  await tester.pumpAndSettle();
  await tester.tap(advanced);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('零标签时高级筛选可就地建标签，建出来即为选中态', (tester) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        // 把标签流钉成空表，才能量到「零标签」这一档（fixture 本身种了 4 条）。
        tagsStreamProvider.overrideWith(
          (ref) => Stream.value(const <TodoTag>[]),
        ),
      ],
    );
    addTearDown(fixture.dispose);
    await _pump(tester, fixture);
    await _openAdvancedDialog(tester);

    expect(
      find.byKey(const Key('task-filter-new-tag-input')),
      findsOneWidget,
      reason: '对话框里没有建标签的入口，零标签时用户只能看到一句空态提示',
    );

    await _createTag(tester, '  筛选新建-判据  ');

    final created =
        (await fixture.database.select(fixture.database.todoTags).get())
            .where((tag) => tag.name == '筛选新建-判据')
            .toList();
    expect(created, hasLength(1), reason: '标签名要 trim 后落库，且只落一条');

    final chip = find.widgetWithText(FilterChip, '筛选新建-判据');
    expect(chip, findsOneWidget, reason: '建出来的标签要立刻出现在同一小节里');
    expect(
      tester.widget<FilterChip>(chip).selected,
      isTrue,
      reason: '建完即选中，不该再点一次勾选框',
    );
  });

  testWidgets('标签读不出来时只给提示，不给就地建', (tester) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        tagsStreamProvider.overrideWith(
          (ref) => Stream<List<TodoTag>>.error(StateError('标签读不出来')),
        ),
      ],
    );
    addTearDown(fixture.dispose);
    await _pump(tester, fixture);
    await _openAdvancedDialog(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('task-filter-tag-section')),
        matching: find.textContaining('标签暂不可用'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('task-filter-new-tag-input')),
      findsNothing,
      reason: '读不到标签列表时建出来的标签无法确认重名，也不给选',
    );
  });

  testWidgets('同名标签不重复建，选中已有的那一条', (tester) async {
    // 不换标签流：fixture 真往库里种了「专注」，才能量出「复用不再长一条」。
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await _pump(tester, fixture);
    await _openAdvancedDialog(tester);

    final before =
        (await fixture.database.select(fixture.database.todoTags).get())
            .where((tag) => tag.name == '专注')
            .length;
    expect(before, 1, reason: '前置：库里就一条「专注」');

    await _createTag(tester, '专注');

    final after =
        (await fixture.database.select(fixture.database.todoTags).get())
            .where((tag) => tag.name == '专注')
            .length;
    expect(after, 1, reason: '命中已有标签名时不能再插一条同名标签');

    final chip = find.widgetWithText(FilterChip, '专注');
    expect(
      tester.widget<FilterChip>(chip).selected,
      isTrue,
      reason: '命中已有标签时要把那一条选中',
    );
  });
}
