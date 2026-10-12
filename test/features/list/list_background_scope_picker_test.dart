import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/list/list_properties.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_workspace_header.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// specs/106 / FL #572 两面：
/// ①《02-用清单管理任务》:100 那张图里背景盖的是**整个详情屏**（含标题区），
///   不是只有任务列表那一段 ⇒ 装饰要包在整层外面；
/// ② :111 的图片档是相册选图，不是让用户手贴地址 ⇒ 选图上传拿 URL。
/// 默认（跟随主题）不套任何装饰，所以既有 golden 基线不该动。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<TodoVisualFixture> pumpPage(
    WidgetTester tester, {
    required String initialListId,
  }) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: themed(),
          home: TasksByListPage(
            initialListId: initialListId,
            lockedListId: true,
            hideAppBar: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    return fixture;
  }

  Future<void> setRow(
    TodoVisualFixture fixture, {
    required String type,
    String? value,
  }) async {
    await (fixture.database.update(
      fixture.database.todoLists,
    )..where((row) => row.id.equals(TodoVisualFixture.workListId))).write(
      TodoListsCompanion(
        backgroundType: Value(type),
        backgroundValue: Value(value),
      ),
    );
  }

  testWidgets('颜色背景盖住整个详情层：标题区那枚菜单也在装饰之内', (tester) async {
    final fixture = await pumpPage(
      tester,
      initialListId: TodoVisualFixture.workListId,
    );
    // 控制组：先量"没有背景"的样子。判据按装饰层的专属 key 量——
    // header 自己就带一个 DecoratedBox（白底 + 下边框），按类型找会把它算进来。
    expect(
      find.byKey(const Key('todo-list-background-surface')),
      findsNothing,
      reason: '默认跟随主题时不该有背景装饰层',
    );

    await setRow(fixture, type: 'color', value: '#4772FA');
    await tester.pumpAndSettle();

    final surface = find.byKey(const Key('todo-list-background-surface'));
    expect(surface, findsOneWidget);
    expect(
      find.descendant(
        of: surface,
        matching: find.byKey(const Key('todo-sort-menu')),
      ),
      findsOneWidget,
      reason: '标题区也要被背景盖住，不然切清单认不出来',
    );
    final box = tester.widget<DecoratedBox>(surface);
    expect((box.decoration as BoxDecoration).color, const Color(0xFF4772FA));
    expect(
      find.descendant(of: surface, matching: find.byType(TaskWorkspaceHeader)),
      findsOneWidget,
      reason: '装饰层在整层外面，不是只包住列表体',
    );
  });

  testWidgets('图片档：选图上传把 URL 填回同一格，保存后落库', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    final list =
        (await (fixture.database.select(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .getSingle());
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var uploaded = '';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: ListBackgroundSheet(
              list: list,
              pickImage: () async => '/tmp/相册/背景.png',
              uploadImage: (path, name) async {
                uploaded = path;
                return 'https://files.test/todo/bg.png';
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-list-background-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-list-background-pick-image')));
    await tester.pumpAndSettle();

    expect(uploaded, '/tmp/相册/背景.png', reason: '上传要用选中的那条本地路径');
    expect(
      find.text('https://files.test/todo/bg.png'),
      findsOneWidget,
      reason: '拿到的 URL 要填回「图片地址」那一格',
    );

    await tester.tap(find.byKey(const Key('todo-list-background-save')));
    await tester.pumpAndSettle();

    final row =
        (await (fixture.database.select(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .getSingle());
    expect(row.backgroundType, 'image');
    expect(row.backgroundValue, 'https://files.test/todo/bg.png');
  });

  testWidgets('上传失败：错误就地可见、不落库、弹层不关', (tester) async {
    final fixture = await TodoVisualFixture.create(
      set: TodoVisualFixtureSet.populated,
    );
    addTearDown(fixture.dispose);
    final repo = fixture.container.read(listRepositoryProvider)!;
    final list =
        (await (fixture.database.select(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .getSingle());
    await repo.setBackground(list.id, 'color', '#00C853');
    final updated =
        (await (fixture.database.select(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .getSingle());
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: themed(),
          home: Scaffold(
            body: ListBackgroundSheet(
              list: updated,
              pickImage: () async => '/tmp/相册/坏.png',
              uploadImage: (path, name) async => throw StateError('服务没接住'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-list-background-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-list-background-pick-image')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-list-background-error')), findsOneWidget);
    expect(find.textContaining('图片上传失败'), findsOneWidget);
    final row =
        (await (fixture.database.select(fixture.database.todoLists)
              ..where((row) => row.id.equals(TodoVisualFixture.workListId)))
            .getSingle());
    expect(row.backgroundType, 'color', reason: '失败不该把背景改成半截状态');
  });
}
