import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/list/list_properties.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/105 / FL #340：清单「背景」设置弹层。
///
/// 嘀嗒《02-用清单管理任务.md》:103-:111 背景四样式（跟随应用主题/颜色/
/// 渐变/图片）、:118「已完成/已放弃/垃圾桶」不支持背景（本端智能清单
/// 由仓储守卫拒绝，弹层里把错误显出来）。
void main() {
  TodoVisualFixture? listFixture;

  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<TodoVisualFixture> createFixture() async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    listFixture = fixture;
    return fixture;
  }

  Future<void> pumpSheet(WidgetTester tester, TodoList list) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: listFixture!.container,
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ListBackgroundSheet.show(context, list),
                child: const Text('打开背景设置'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开背景设置'));
    await tester.pumpAndSettle();
  }

  Future<TodoList?> listById(String id) async {
    final rows = await (listFixture!.database.select(
      listFixture!.database.todoLists,
    )..where((row) => row.id.equals(id))).get();
    return rows.isEmpty ? null : rows.single;
  }

  Future<TodoList> workList() async =>
      (await listById(TodoVisualFixture.workListId))!;

  testWidgets('选颜色档 + 色点保存 ⇒ backgroundType/value 落库', (tester) async {
    await createFixture();
    final list = await workList();
    await pumpSheet(tester, list);

    await tester.tap(find.byKey(const Key('todo-list-background-color')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('todo-list-background-color-00c853')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-list-background-save')));
    await tester.pumpAndSettle();

    final row = await listById(TodoVisualFixture.workListId);
    expect(row!.backgroundType, 'color');
    expect(row.backgroundValue, '#00C853');
  });

  testWidgets('色档没选色直接保存 ⇒ 弹层不关、错误文案当场可见', (tester) async {
    await createFixture();
    final list = await workList();
    await pumpSheet(tester, list);

    await tester.tap(find.byKey(const Key('todo-list-background-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-list-background-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-list-background-error')), findsOneWidget);
    final row = await listById(TodoVisualFixture.workListId);
    expect(row!.backgroundType, 'theme', reason: '失败不该有写入');
  });

  testWidgets('切回「跟随应用主题」保存 ⇒ value 清空', (tester) async {
    await createFixture();
    final repo = listFixture!.container.read(listRepositoryProvider)!;
    final list = await workList();
    await repo.setBackground(list.id, 'color', '#4772FA');
    await pumpSheet(tester, await workList());

    await tester.tap(find.byKey(const Key('todo-list-background-theme')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-list-background-save')));
    await tester.pumpAndSettle();

    final row = await listById(TodoVisualFixture.workListId);
    expect(row!.backgroundType, 'theme');
    expect(row.backgroundValue, isNull);
  });

  testWidgets('智能清单选色保存 ⇒ 仓储拒绝，错误文案带「不支持设置背景」', (tester) async {
    await createFixture();
    final repo = listFixture!.container.read(listRepositoryProvider)!;
    final smart = await repo.create(name: 'smart:today');
    await pumpSheet(tester, smart);

    await tester.tap(find.byKey(const Key('todo-list-background-color')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('todo-list-background-color-4772fa')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-list-background-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-list-background-error')), findsOneWidget);
    expect(find.textContaining('不支持设置背景'), findsOneWidget);
    final row = await listById(smart.id);
    expect(row!.backgroundType, 'theme', reason: '嘀嗒 :118：智能清单不落背景');
  });
}
