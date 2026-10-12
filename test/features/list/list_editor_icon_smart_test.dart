import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/list/list_editor_sheet.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/105 / FL #339：清单编辑器「Emoji 图标（方式一/方式二）」与
/// 「在智能清单中显示」开关。
///
/// 嘀嗒《02-用清单管理任务.md》:86「点击名称前面的「图标」，选择需要的 Emoji」、
/// :87「清单名称最前面输入 Emoji 表情，可自动设置为清单的图标」、
/// :73「在智能清单中显示/隐藏」。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<TodoVisualFixture> pumpSheet(
    WidgetTester tester, {
    TodoList? existing,
    TodoVisualFixture? fixture,
  }) async {
    // 复用调用方造好的库：一个用例里跨两个库会"写进库 B、断言读库 A"。
    final f = fixture ??= await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(f.dispose);
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ListEditorSheet(existing: existing),
                ),
                child: const Text('打开清单编辑器'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开清单编辑器'));
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<TodoList?> listByName(AppDatabase db, String name) async {
    final rows = await (db.select(
      db.todoLists,
    )..where((row) => row.name.equals(name))).get();
    return rows.isEmpty ? null : rows.single;
  }

  testWidgets('新建：点候选 Emoji 保存 ⇒ icon 落库，payload 带同名键', (tester) async {
    final fixture = await pumpSheet(tester);

    // 📌 = U+1F4CC，key 走 runes（codeUnits 首位是代理对，会互相撞 key）。
    expect(
      find.byKey(const Key('todo-list-editor-emoji-1f4cc')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('todo-list-editor-emoji-1f4cc')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '图标清单A');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final row = await listByName(fixture.database, '图标清单A');
    expect(row, isNotNull);
    expect(row!.icon, '📌');
    final payload = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(
      payload.map((r) => r.payloadJson).where((j) => j.contains('图标清单A')),
      isNotEmpty,
    );
    expect(
      payload
          .map((r) => r.payloadJson)
          .where((j) => j.contains('图标清单A'))
          .every((j) => j.contains('"icon":"📌"')),
      isTrue,
      reason: '新建清单的 outbox payload 必须带 icon',
    );
  });

  testWidgets('方式二：名称最前面输入 Emoji 不点面板 ⇒ 自动采纳为图标', (tester) async {
    final fixture = await pumpSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, '清单名'), '🎯目标清单');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final row = await listByName(fixture.database, '🎯目标清单');
    expect(row, isNotNull);
    expect(row!.icon, '🎯', reason: '嘀嗒 :87 前导 Emoji 自动设为图标');
  });

  testWidgets('方式一优先：既选了面板 Emoji 又输前导 Emoji ⇒ 面板说了算', (tester) async {
    final fixture = await pumpSheet(tester);

    await tester.tap(find.byKey(const Key('todo-list-editor-emoji-1f4cc')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '🎯冲突清单');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final row = await listByName(fixture.database, '🎯冲突清单');
    expect(row!.icon, '📌', reason: '用户显式选过图标时，自动检测不许抢决定');
  });

  testWidgets('编辑：关掉「在智能清单中显示」保存 ⇒ 列回 false 并出库', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    final existing = await (fixture.database.select(
      fixture.database.todoLists,
    )..where((row) => row.id.equals(TodoVisualFixture.workListId))).getSingle();
    expect(existing.showInSmartList, isTrue, reason: '前提：种子清单默认显示');

    await pumpSheet(tester, existing: existing, fixture: fixture);

    await tester.tap(find.byKey(const Key('todo-list-editor-show-in-smart')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final row = await (fixture.database.select(
      fixture.database.todoLists,
    )..where((r) => r.id.equals(TodoVisualFixture.workListId))).getSingle();
    expect(row.showInSmartList, isFalse);
  });
}
