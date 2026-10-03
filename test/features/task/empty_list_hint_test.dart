import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// Issue #472：空态提示必须指向当前视口真实存在的添加入口。
///
/// 快速添加条只在 `width >= tabletMinWidth(600)` 出现（`tasks_by_list_page.dart:218`），
/// 但空态副标题原来无条件写「在上方输入任务并按回车。」——390×844 实测上方没有输入框，
/// 只能走右下角的 + FAB。
void main() {
  Future<void> pumpEmptyList(WidgetTester tester, Size viewport) async {
    await pumpTodoVisualScenario(
      tester,
      viewport: viewport,
      fixtureSet: TodoVisualFixtureSet.empty,
      child: const TasksByListPage(),
    );
  }

  testWidgets('手机视口：空态指向右下角按钮，不再指「上方」', (tester) async {
    await pumpEmptyList(tester, TodoVisualViewports.mobile);
    expect(find.text('暂无任务'), findsOneWidget);
    expect(
      find.text('在上方输入任务并按回车。'),
      findsNothing,
      reason: '390px 下快速添加条不渲染，这句话指向不存在的控件',
    );
    expect(find.text('点右下角的 + 添加任务。'), findsOneWidget);
  });

  testWidgets('平板及以上：空态仍指向顶部快速添加条', (tester) async {
    await pumpEmptyList(tester, TodoVisualViewports.tablet);
    expect(find.text('在上方输入任务并按回车。'), findsOneWidget);
    expect(find.text('点右下角的 + 添加任务。'), findsNothing);
  });
}
