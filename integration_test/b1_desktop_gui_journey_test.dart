import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';
import 'package:zh_cloud_todo_flutter/main.dart' as app;

/// Runs only in an isolated macOS runner. It intentionally uses Flutter's
/// native integration-test harness instead of desktop automation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const definedMobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
  const definedPassword = String.fromEnvironment('TODO_B1_E2E_PASSWORD');
  final mobile = definedMobile.isNotEmpty
      ? definedMobile
      : Platform.environment['TODO_B1_E2E_MOBILE'] ?? '';
  final password = definedPassword.isNotEmpty
      ? definedPassword
      : Platform.environment['TODO_B1_E2E_PASSWORD'] ?? '';

  testWidgets('B1 desktop GUI journey logs in and saves Markdown task detail', (
    tester,
  ) async {
    if (mobile.isEmpty || password.isEmpty) {
      fail('需要通过受保护的 dart-define 提供 B1 测试账号');
    }

    app.main();
    await _pumpUntil(tester, find.byKey(const Key('todo-auth-mobile-input')));
    await tester.enterText(
      find.byKey(const Key('todo-auth-mobile-input')),
      mobile,
    );
    await tester.enterText(
      find.byKey(const Key('todo-auth-password-input')),
      password,
    );
    await tester.tap(find.byKey(const Key('todo-auth-submit')));
    await _pumpUntil(tester, find.byKey(const Key('todo-quick-add-input')));

    final taskTitle =
        'B1 macOS GUI 验收任务 ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(
      find.byKey(const Key('todo-quick-add-input')),
      taskTitle,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);

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

    const markdown = '## macOS GUI 保存后回读';
    await tester.enterText(
      find.byKey(const Key('todo-task-detail-description-input')),
      markdown,
    );
    await tester.tap(find.byKey(const Key('todo_task_detail_save_button')));
    await tester.pump(const Duration(seconds: 1));

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
  for (var step = 0; step < 400 && rowTitle.evaluate().isEmpty; step++) {
    final next = (position.pixels + 400).clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump(const Duration(milliseconds: 50));
  }
}
