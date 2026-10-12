import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/105 / FL #340 的入口形态：嘀嗒《02-用清单管理任务》:96
/// 「进入你想设置的清单详情页，点击右上角的「...」-「背景」」。
///
/// 第 282 轮把弹层做在侧栏清单动作表，本轮把它接到详情页右上角那枚「...」。
/// 收集箱（:20）与智能清单浏览（没选中具体清单）都不给入口——仓储 setBackground
/// 里还有一道显式拒绝，这里是"入口也不出现"。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<TodoVisualFixture> pumpPage(
    WidgetTester tester, {
    required String? initialListId,
    bool lockedListId = true,
  }) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: themed(),
          home: TasksByListPage(
            initialListId: initialListId,
            lockedListId: lockedListId,
            hideAppBar: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    return fixture;
  }

  Future<void> openSortMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    // 正对照：菜单真的展开了才继续，否则下面的 findsNothing 是空转。
    expect(find.text('批量编辑'), findsOneWidget, reason: '「...」菜单没打开，负向断言不成立');
  }

  testWidgets('选中普通清单：详情层「...」里有「背景」，点开进四样式弹层', (tester) async {
    await pumpPage(tester, initialListId: TodoVisualFixture.workListId);
    await openSortMenu(tester);

    expect(find.text('背景'), findsOneWidget, reason: '嘀嗒 :96 的入口在详情页右上角「...」里');

    await tester.tap(find.text('背景'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('todo-list-background-theme')),
      findsOneWidget,
      reason: '点「背景」要打开四样式弹层，不是只收起菜单',
    );
  });

  testWidgets('收集箱：不给「背景」入口', (tester) async {
    await pumpPage(tester, initialListId: 'inbox');
    await openSortMenu(tester);
    expect(find.text('背景'), findsNothing);
  });

  testWidgets('智能清单浏览（未选中清单）：不给「背景」入口', (tester) async {
    await pumpPage(tester, initialListId: null, lockedListId: false);
    await openSortMenu(tester);
    expect(find.text('背景'), findsNothing);
  });
}
