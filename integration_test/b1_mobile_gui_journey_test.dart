import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';
import 'package:zh_cloud_todo_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const mobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
  const password = String.fromEnvironment('TODO_B1_E2E_PASSWORD');

  testWidgets('B1 mobile GUI journey logs in and saves Markdown task detail', (
    tester,
  ) async {
    if (mobile.isEmpty || password.isEmpty) {
      fail('需要通过受保护的 dart-define 提供 B1 测试账号');
    }

    app.main();
    await _pumpUntil(tester, find.byKey(const Key('todo-auth-mobile-input')));
    expect(
      find.byKey(const Key('todo-auth-password-input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('todo-auth-mobile-input')),
      mobile,
    );
    await tester.enterText(
      find.byKey(const Key('todo-auth-password-input')),
      password,
    );
    await tester.tap(find.byKey(const Key('todo-auth-submit')));
    await _pumpUntil(tester, find.byKey(const Key('todo-mobile-add')));

    await tester.tap(find.byKey(const Key('todo-mobile-add')));
    await _pumpUntil(tester, find.byKey(const Key('todo-mobile-add-field')));
    final taskTitle =
        'B1 GUI 验收任务 ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      taskTitle,
    );
    await tester.tap(find.byTooltip('创建任务'));
    await _pumpUntilAbsent(
      tester,
      find.byKey(const Key('todo-mobile-add-field')),
    );
    final taskTitleInRow = find.descendant(
      of: find.byType(TaskRow),
      matching: find.text(taskTitle),
    );
    await _scrollToTaskRow(tester, taskTitleInRow);
    await _pumpUntil(tester, taskTitleInRow);
    final taskRow = find.ancestor(
      of: taskTitleInRow,
      matching: find.byType(TaskRow),
    );
    expect(taskRow, findsOneWidget);
    await tester.tap(
      find.descendant(of: taskRow, matching: find.byType(InkWell)).first,
    );
    await _pumpUntil(
      tester,
      find.byKey(const Key('todo-task-detail-description-input')),
    );
    const markdown = '## GUI 保存后回读';
    await tester.enterText(
      find.byKey(const Key('todo-task-detail-description-input')),
      markdown,
    );
    await tester.tap(find.byKey(const Key('todo_task_detail_save_button')));
    await tester.pump(const Duration(seconds: 1));
    // pageBack() 只认英文 'Back' tooltip 与 Cupertino 导航条按钮：应用挂了中文
    // 本地化、且真机 Android 没有 Cupertino 导航条，所以它在 Android 上必然红
    // （Issue #484）。系统返回是平台无关的那条路。
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));
    await _scrollToTaskRow(tester, taskTitleInRow);
    await _pumpUntil(tester, taskTitleInRow);
    await tester.tap(
      find.descendant(of: taskRow, matching: find.byType(InkWell)).first,
    );
    await _pumpUntil(
      tester,
      find.byKey(const Key('todo-task-detail-description-input')),
    );
    final descriptionField = tester.widget<TextField>(
      find.byKey(const Key('todo-task-detail-description-input')),
    );
    expect(descriptionField.controller?.text, markdown);
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  throw TestFailure('未在固定时间内找到 GUI 锚点: $finder');
}

Future<void> _pumpUntilAbsent(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (finder.evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  throw TestFailure('GUI 锚点未在固定时间内消失: $finder');
}

/// 任务列表是懒构建的 ListView.builder：无截止时间的新建任务落在「无日期」分组
/// （六组里的第五组），fixture 任务一多，那一行根本没进构建窗口，
/// 直接 find 只会得到「Found 0 widgets」，分不清是功能坏了还是没滚到。
/// 滚动定位同时把该行留在视口里，后面的 tap 才打得中。
Future<void> _scrollToTaskRow(WidgetTester tester, Finder rowTitle) async {
  if (rowTitle.evaluate().isNotEmpty) return;
  final rows = find.byType(TaskRow);
  if (rows.evaluate().isEmpty) return;
  // 不靠命名 Scrollable：scrollUntilVisible 要求 scrollable: 恰好命中一个，而实测这里
  // 既不在 todo-task-list-scroll 之下、也可能套着行内的横向滚动。改为在所有 Scrollable
  // 里取「可滚动范围最大」的那个——几百行的任务列表远大于任何行内滑动容器。
  ScrollPosition? position;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (position == null || state.position.maxScrollExtent > position.maxScrollExtent) {
      position = state.position;
    }
  }
  if (position == null) return;
  // 未命中时从顶部重扫：列表会按日期/排序重排，目标行可能跑到当前偏移之上，
  // 只向前扫永远碰不到（同 #510 在 b2 里定位到的机制）。
  position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 50));
  for (var step = 0; step < 400 && rowTitle.evaluate().isEmpty; step++) {
    final next = (position.pixels + 400).clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump(const Duration(milliseconds: 50));
  }
}
