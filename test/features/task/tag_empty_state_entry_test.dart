import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_detail_pane.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

/// FL Issue #332：详情里的标签选择器空态文案把用户指向**不可达**的「清单页」。
///
/// 旧文案是「暂无标签，请先在清单页右上角创建」。本端确实有一个 `ListPage`，
/// 但它没有任何入口（下面的第二条用例钉住这点），能创建标签的真实入口是侧栏
/// 那行 `todo-sidebar-row-tags`（`lib/features/shell/sidebar.dart` 里 label 就是「标签」，
/// `onTap` 走 `home_shell.dart` 的 `_openTags` 推 `TagPage`）。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  }

  testWidgets('一条标签都没有时，空态指向侧栏「标签」而不是清单页', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final list = await ListRepository(db, queue).create(name: '工作');
    final task = await TaskRepository(
      db,
      queue,
    ).create(listId: list.id, title: '写周报');

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncChangeQueueProvider.overrideWithValue(queue),
        ],
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(body: TaskDetailPane(taskId: task.id, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 标签选择器是懒加载的：等首帧后把语义树里的空态文案读出来。
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final empty = find.text('暂无标签，可先在侧栏「标签」里创建');
    expect(empty, findsOneWidget, reason: '空态必须指向真的入口');
    expect(
      find.textContaining('清单页'),
      findsNothing,
      reason: '旧文案把用户指向一个没有任何入口的页面',
    );
    await settleTimers(tester);
  });

  test('ListPage 除了自身声明之外在 lib 里没有任何被引用的地方', () {
    // 判据要避开子串陷阱：`TasksByListPage(` 里也含 `ListPage(`，
    // 所以按「前一个字符不是字母」才算一次真引用。
    final decl = 'lib/features/list/list_page.dart';
    final refs = <String, List<int>>{};
    final bySlash = decl.replaceAll('/', io.Platform.pathSeparator);
    for (final entry in io.Directory('lib').listSync(recursive: true)) {
      if (entry is! io.File || !entry.path.endsWith('.dart')) continue;
      final lines = entry.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        var from = 0;
        while (true) {
          final at = lines[i].indexOf('ListPage(', from);
          if (at < 0) break;
          final prev = at > 0 ? lines[i][at - 1] : '';
          if (!RegExp('[A-Za-z]').hasMatch(prev)) {
            refs.putIfAbsent(entry.path, () => []).add(i + 1);
          }
          from = at + 1;
        }
      }
    }
    expect(refs[decl] ?? refs[bySlash], isNotNull, reason: '自身声明要在');
    final outside = {
      for (final e in refs.entries)
        if (!(e.key.endsWith('list/list_page.dart') ||
            e.key.endsWith('list_page.dart')))
          e.key: e.value,
    };
    expect(outside, isEmpty, reason: '清单页若变得可达，旧空态文案就不再是缺陷');
  });
}
