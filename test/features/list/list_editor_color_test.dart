import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/list/list_editor_sheet.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/102 / FL Issue #339：清单编辑器「颜色」属性。
///
/// 嘀嗒《02-用清单管理任务.md》:73
/// 「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」
const colorRowKey = Key('todo-list-editor-color-row');
const colorNoneKey = Key('todo-list-editor-color-none');

Key colorSwatchKey(String hex) =>
    Key('todo-list-editor-color-${hex.substring(1).toLowerCase()}');

void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<TodoVisualFixture> pumpSheet(
    WidgetTester tester, {
    TodoList? existing,
    TodoVisualFixture? fixture,
  }) async {
    // 复用调用方造好的库：一个用例里 create 两次会出现"写进库 B、断言读库 A"的假失败。
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
        container: f.container,
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
    return f;
  }

  Future<TodoList?> listById(AppDatabase db, String id) async {
    return await (db.select(
      db.todoLists,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<int> listChangeCount(TodoVisualFixture fixture) async {
    final rows = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    return rows.length;
  }

  // 不用 .first：findsNothing 会对空集求值，.first 在空集上抛 Bad state，
  // 负向断言就变成"判据自己崩"而不是"没有找到"。
  Finder selectedMark(Finder swatch) =>
      find.descendant(of: swatch, matching: find.byIcon(Icons.check));

  testWidgets('新建弹层渲染色板：10 色 + 「无」，默认没有任何选中标记', (tester) async {
    await pumpSheet(tester);

    expect(find.byKey(colorRowKey), findsOneWidget);
    for (final hex in kExpectedPalette) {
      expect(
        find.byKey(colorSwatchKey(hex)),
        findsOneWidget,
        reason: '色板缺 $hex',
      );
    }
    expect(find.byKey(colorNoneKey), findsOneWidget);
    expect(
      selectedMark(find.byKey(colorRowKey)),
      findsNothing,
      reason: '默认无色，「无」与色点都不该带选中标记',
    );
  });

  testWidgets('新建：选色保存 ⇒ 清单落库该色，outbox payload 带同名键', (tester) async {
    final fixture = await pumpSheet(tester);

    await tester.tap(find.byKey(colorSwatchKey('#00C853')));
    await tester.pumpAndSettle();
    expect(
      selectedMark(find.byKey(colorSwatchKey('#00C853'))),
      findsOneWidget,
      reason: '点中的色点要当场看见选中标记',
    );
    await tester.enterText(find.widgetWithText(TextField, '清单名'), '骑行');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final created = await (fixture.database.select(
      fixture.database.todoLists,
    )..where((row) => row.name.equals('骑行'))).getSingle();
    expect(created.color, '#00C853', reason: '选的色要写进清单');
    final payloads =
        (await fixture.database.select(fixture.database.todoSyncChanges).get())
            .map((r) => jsonDecode(r.payloadJson) as Map<String, dynamic>);
    final payload = payloads.firstWhere(
      (p) => p['name'] == '骑行',
      orElse: () => throw TestFailure('新建清单的 outbox 不存在'),
    );
    expect(payload['color'], '#00C853', reason: 'outbox 必须把色带出去');
  });

  testWidgets('编辑：预选当前色，改色与清色各留一条 outbox', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    final rows =
        await (fixture.database.update(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .write(const TodoListsCompanion(color: Value('#4772FA')));
    expect(rows, 1, reason: '前提：先给工作清单上色');
    final work = (await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    ))!;
    await pumpSheet(tester, existing: work, fixture: fixture);

    expect(
      selectedMark(find.byKey(colorSwatchKey('#4772FA'))),
      findsOneWidget,
      reason: '打开时必须预选当前色',
    );

    var changes = await listChangeCount(fixture);
    await tester.tap(find.byKey(colorSwatchKey('#F44336')));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    var after = await listById(fixture.database, TodoVisualFixture.workListId);
    expect(after!.color, '#F44336');
    expect(
      await listChangeCount(fixture),
      changes + 1,
      reason: '改色要进 outbox，否则另一台设备 pull 后颜色不一致',
    );

    // 再开一次，把色清掉
    final recolored = await listById(
      fixture.database,
      TodoVisualFixture.workListId,
    );
    await pumpSheet(tester, existing: recolored, fixture: fixture);
    expect(
      selectedMark(find.byKey(colorSwatchKey('#F44336'))),
      findsOneWidget,
      reason: '第二次打开预选的要是刚改的新色',
    );
    changes = await listChangeCount(fixture);
    await tester.tap(find.byKey(colorNoneKey));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    after = await listById(fixture.database, TodoVisualFixture.workListId);
    expect(after!.color, isNull, reason: '「无」= 清除颜色');
    expect(await listChangeCount(fixture), changes + 1, reason: '清色也要同步出去');
  });
}

/// 只用于断言渲染面（与 lib 里的常量解耦，防止实现抄测试）。
const kExpectedPalette = <String>[
  '#4772FA',
  '#00B8D9',
  '#00C853',
  '#FFAB00',
  '#FF6D00',
  '#F44336',
  '#E91E63',
  '#9C27B0',
  '#673AB7',
  '#607D8B',
];
