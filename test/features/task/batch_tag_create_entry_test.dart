import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

import '../../support/todo_visual_fixture.dart';

/// FL #493：批量「设置标签」以前只说「暂无可选择的标签」，不给就地建。
///
/// 判据打在弹窗本体上：表内必须有一行「新建标签」，添加后新标签直接是选中态，
/// 点「应用标签」要真的把这条标签挂到选中的任务上。
void main() {
  testWidgets('batch tag sheet offers in-place tag creation and applies it', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const Key('todo-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('task-batch-select-${TodoVisualFixture.metadataTaskId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-action-setTags')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('todo-batch-new-tag-input')),
      findsOneWidget,
      reason: '弹窗里没有就地建标签的入口，用户只能看到已有标签（或一句空态提示）',
    );

    await tester.enterText(
      find.byKey(const Key('todo-batch-new-tag-input')),
      '批量新建-判据',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-batch-create-tag')));
    await tester.pumpAndSettle();

    final created =
        (await fixture.database.select(fixture.database.todoTags).get())
            .where((tag) => tag.name == '批量新建-判据')
            .toList();
    expect(created, hasLength(1), reason: '同名只应有一条，且确实落库');
    // 不断言这一行在树里：弹窗的 ListView 是懒建的，第 5 行可能在屏幕外，
    // 用「应用后是否挂上」来量「建了即选中」，才不依赖滚动位置。

    await tester.tap(find.byKey(const Key('todo-batch-apply-tags')));
    await tester.pumpAndSettle();

    final bindings = await fixture.database
        .select(fixture.database.todoTaskTags)
        .get();
    expect(
      bindings.any(
        (row) =>
            row.taskId == TodoVisualFixture.metadataTaskId &&
            row.tagId == created.single.id,
      ),
      isTrue,
      reason: '添加即选中、应用即挂上，不需要再点一次勾选框',
    );
  });
}
