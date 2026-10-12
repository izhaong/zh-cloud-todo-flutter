import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/shell/smart_list_manager_sheet.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/sidebar_visibility_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/103：嘀嗒《02-用清单管理任务.md》:29「智能清单管理」页面。
///
/// :45 三态；:20「（收集箱是不可以被隐藏或删除。）」要落成显式判据。
void main() {
  Finder row(String name) => find.byKey(Key('todo-smart-list-manager-$name'));

  Future<TodoVisualFixture> pumpSheet(WidgetTester tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 720, child: SmartListManagerSheet()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  // 弹层是懒渲染的 ListView：不滚到位就断言 = 量不到第八行，红得没有信息量。
  Future<void> scrollToRow(WidgetTester tester, String name) =>
      tester.scrollUntilVisible(
        row(name),
        100,
        scrollable: find.byType(Scrollable).last,
      );

  testWidgets('八行齐：本端全部智能清单都要能管理', (tester) async {
    await pumpSheet(tester);

    for (final name in [
      'inbox',
      'assignToMe',
      'today',
      'tomorrow',
      'upcoming',
      'all',
      'completed',
      'trash',
    ]) {
      await scrollToRow(tester, name);
      expect(row(name), findsOneWidget, reason: '管理页缺 $name 行');
    }
  });

  testWidgets('收集箱固定「显示」：不可隐藏或删除要写成显式说明，不靠没入口', (tester) async {
    await pumpSheet(tester);

    expect(
      find.descendant(of: row('inbox'), matching: find.text('收集箱不可隐藏或删除')),
      findsOneWidget,
      reason: '嘀嗒 :20 的约束要在界面上可见',
    );
    expect(
      find.descendant(of: row('inbox'), matching: find.text('有内容时显示')),
      findsNothing,
      reason: '收集箱没有可切的三态',
    );
  });

  testWidgets('「有内容时显示」只给有内容判定的五行：指派给我/今天/明天/最近七天/全部', (tester) async {
    await pumpSheet(tester);

    for (final name in ['assignToMe', 'today', 'tomorrow', 'upcoming', 'all']) {
      await scrollToRow(tester, name);
      expect(
        find.descendant(of: row(name), matching: find.text('有内容时显示')),
        findsOneWidget,
        reason: '$name 该有第三档',
      );
    }
    for (final name in ['completed', 'trash']) {
      await scrollToRow(tester, name);
      expect(
        find.descendant(of: row(name), matching: find.text('有内容时显示')),
        findsNothing,
        reason: '$name 本端没有内容计数，不该给一个永远判定为没内容的档位',
      );
    }
  });

  testWidgets('把「今天」切成「隐藏」要落库', (tester) async {
    final fixture = await pumpSheet(tester);

    await tester.tap(
      find.descendant(of: row('today'), matching: find.text('隐藏')),
    );
    await tester.pumpAndSettle();

    final states = await SidebarVisibilityRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).getSmartListStates();
    expect(states['today'], SmartListVisibility.hide);
  });
}
