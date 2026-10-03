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
