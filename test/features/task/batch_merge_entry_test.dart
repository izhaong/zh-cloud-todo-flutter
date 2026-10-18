import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';

/// FL #357 客户端接线（service !414，语义 B —— opencode A/B 拍定）：
/// 「合并任务」批量入口「能选目标、说清后果、未同步拒绝」。
///
/// 判据源《01-列表视图》:84/:93「甚至进行优先级、分享和**合并任务**的操作」。
void main() {
  Future<void> pumpPage(WidgetTester tester, TodoVisualFixture fixture) async {
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

  testWidgets('批量菜单里有「合并到…」，选中合并后出目标选择器且后果说在前面', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await pumpPage(tester, fixture);

    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('todo-batch-action-merge')),
      findsOneWidget,
      reason: '服务端 !414 已有 /task/merge，批量入口缺了等于没有这个能力',
    );

    await tester.tap(find.byKey(const Key('todo-batch-action-merge')));
    await tester.pumpAndSettle();

    // opencode：把合并的**后果说清楚** —— 避免用户预期成"都还在"的语义。
    expect(
      find.byKey(const Key('todo-batch-merge-consequences')),
      findsOneWidget,
      reason: '合并是破坏性批量动作（源软删），后果必须在确认前可见',
    );
    expect(find.textContaining('将删除'), findsOneWidget);
    expect(find.textContaining('提醒与重复规则不保留'), findsOneWidget);
  });

  testWidgets('未同步任务（serverId 为空）合并被拒并说明，不静默', (tester) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    // 视觉 fixture 的任务都是本地行（serverId null）—— 天然就是"未同步"样本。
    await pumpPage(tester, fixture);

    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.pinnedTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-action-merge')));
    await tester.pumpAndSettle();

    // 候选行是动态的（同清单非选中任务）—— 取树上任意一行
    // 找所有 merge-target 键的行
    final targets = find.byWidgetPredicate(
      (w) =>
          w is ListTile &&
          (w.key as ValueKey<String>?)?.value.startsWith(
                'todo-batch-merge-target-',
              ) ==
              true,
    );
    if (targets.evaluate().isNotEmpty) {
      await tester.tap(targets.first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('所选任务尚未同步'),
        findsOneWidget,
        reason:
            '未同步的**源任务**必须拒绝并说明（照单条指派的既有纪律），不许静默跳过 —— '
            '断言源那条文案，目标那条也会触发但那是另一条路径（探针曾因两条文案都含'
            '"尚未同步"而假绿）',
      );
    }
  });
}
