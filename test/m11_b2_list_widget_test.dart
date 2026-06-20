import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/list/list_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

/// M11-B2 widget 测试：进入清单 tab 后能创建清单。
void main() {
  testWidgets('creates a list and writes sync_queue', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ListPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 初始为空时显示"暂无未分组清单"
    expect(find.text('暂无未分组清单'), findsOneWidget);

    // 点击 AppBar 右上角的"新建清单"按钮
    await tester.tap(find.byTooltip('新建清单'));
    await tester.pumpAndSettle();

    // 弹窗出现，键入名称
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '工作');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 现在清单页应当显示"工作"
    expect(find.text('工作'), findsOneWidget);

    // sync_queue 应当有 1 条 LIST/CREATE 记录
    final queued = await db.select(db.todoSyncChanges).get();
    expect(queued.length, 1);
    expect(queued.first.entity, 'LIST');
    expect(queued.first.op, 'CREATE');
  });
}