import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/task_quick_add_sheet.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/kanban_view.dart';

/// 看板列绑清单分组（`TodoTaskSection`）。
///
/// 源：《01-任务/07-不同的视图查看任务/02-看板视图：分类管理任务.md》
/// `:99`-`:101`「当然，你还可以根据需求创建不同类别的分组：」「- 按主题：英语、政治、专业课…」
/// 「- 按进度：未开始、进行中、已完成…」、`:129`「无论是在电脑端还是移动端都能点击「分组」
/// 或者「任务」自由地拖动到相应位置。」、`:141`「点击「分组」右上角的「+」，你可以在分组中添加任务。」
void main() {
  final now = DateTime.utc(2026, 7, 15, 9);

  TodoTask task(
    String id, {
    int priority = 0,
    bool completed = false,
    String? sectionId,
  }) {
    return TodoTask(
      id: id,
      listId: 'list-inbox',
      sectionId: sectionId,
      title: '任务-$id',
      completed: completed,
      cancelled: false,
      allDay: false,
      fixedTimezone: false,
      priority: priority,
      isPinned: false,
      sortOrder: 0,
      updatedAt: now,
      createdAt: now,
    );
  }

  TodoTaskSection section(String id, String name, int sortOrder) {
    return TodoTaskSection(
      id: id,
      listId: 'list-inbox',
      name: name,
      sortOrder: sortOrder,
      updatedAt: now,
      createdAt: now,
    );
  }

  final sections = [section('sec-en', '英语', 0), section('sec-pol', '政治', 1)];

  Future<void> pump(
    WidgetTester tester, {
    required List<TodoTask> tasks,
    List<TodoTaskSection> sections = const [],
    void Function(String, String?)? onSectionMove,
    void Function(int, bool)? onPriorityMove,
    void Function(List<String>)? onSectionOrderChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: tasks,
            listId: 'list-inbox',
            sections: sections,
            onTaskMove: onPriorityMove == null
                ? null
                : (moved, priority, completed) async =>
                      onPriorityMove(priority, completed),
            onTaskSectionMove: onSectionMove == null
                ? null
                : (moved, sectionId) async =>
                      onSectionMove(moved.id, sectionId),
            onSectionOrderChanged: onSectionOrderChanged == null
                ? null
                : (ordered) async => onSectionOrderChanged(ordered),
          ),
        ),
      ),
    );
  }

  /// 拖到某列的空白处（该列没有任务时显示「空」，落在它上面即命中本列的 DragTarget）。
  Future<void> dragToEmptyColumn(
    WidgetTester tester, {
    required String cardTitle,
    required Key columnKey,
  }) async {
    final target = find
        .descendant(of: find.byKey(columnKey), matching: find.text('空'))
        .first;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(cardTitle)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('清单有分组时看板按分组开列，列名取分组名', (tester) async {
    await pump(
      tester,
      tasks: [
        task('a', sectionId: 'sec-en'),
        task('b'),
        task('c'),
      ],
      sections: sections,
    );

    expect(find.text('英语'), findsOneWidget);
    expect(find.text('政治'), findsOneWidget);
    expect(find.text('未分组'), findsOneWidget);
    // priority 四列在分组模式下不再出现（英语/政治/未分组三列）。
    expect(find.text('未开始'), findsNothing);
    expect(find.text('进行中'), findsNothing);
    expect(find.text('紧急'), findsNothing);
    expect(find.text('归档'), findsNothing);
    // 任务按 sectionId 归位：a 在英语列，b/c 在未分组列。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('col-sec-en')),
        matching: find.text('任务-a'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('col-unsectioned')),
        matching: find.text('任务-b'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('没有分组时仍是 priority 四列', (tester) async {
    await pump(tester, tasks: [task('a'), task('d', priority: 2)]);

    expect(find.text('未开始'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('紧急'), findsOneWidget);
    expect(find.text('归档'), findsOneWidget);
    expect(find.text('未分组'), findsNothing);
  });

  testWidgets('跨列拖到分组列只写分组，不请求 priority 写操作', (tester) async {
    var priorityCalls = 0;
    String? movedSectionId;
    String? movedTaskId;
    await pump(
      tester,
      tasks: [task('a')],
      sections: sections,
      onPriorityMove: (_, _) => priorityCalls++,
      onSectionMove: (id, sectionId) {
        movedTaskId = id;
        movedSectionId = sectionId;
      },
    );

    await dragToEmptyColumn(
      tester,
      cardTitle: '任务-a',
      columnKey: const ValueKey('col-sec-pol'),
    );

    expect(movedTaskId, 'a');
    expect(movedSectionId, 'sec-pol');
    expect(priorityCalls, 0);
  });

  testWidgets('拖到未分组列会以 null 清空分组', (tester) async {
    String? movedTaskId = 'untouched';
    String? movedSectionId = 'untouched';
    await pump(
      tester,
      tasks: [task('a', sectionId: 'sec-en')],
      sections: sections,
      onSectionMove: (id, sectionId) {
        movedTaskId = id;
        movedSectionId = sectionId;
      },
    );

    await dragToEmptyColumn(
      tester,
      cardTitle: '任务-a',
      columnKey: const ValueKey('col-unsectioned'),
    );

    expect(movedTaskId, 'a');
    expect(movedSectionId, isNull);
  });

  testWidgets('指向不存在分组的任务落在未分组列而不是消失', (tester) async {
    await pump(
      tester,
      tasks: [task('a', sectionId: 'sec-deleted')],
      sections: sections,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('col-unsectioned')),
        matching: find.text('任务-a'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('分组列的「+」按该分组新建任务', (tester) async {
    await pump(tester, tasks: [task('a')], sections: sections);

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('col-sec-en')),
            matching: find.byIcon(Icons.add),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final sheet = tester.widget<TaskQuickAddSheet>(
      find.byType(TaskQuickAddSheet),
    );
    expect(sheet.listId, 'list-inbox');
    expect(sheet.sectionId, 'sec-en');
  });

  testWidgets('未分组列的「+」不带分组', (tester) async {
    await pump(tester, tasks: [task('a')], sections: sections);

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('col-unsectioned')),
            matching: find.byIcon(Icons.add),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TaskQuickAddSheet>(find.byType(TaskQuickAddSheet))
          .sectionId,
      isNull,
    );
  });

  testWidgets('分组列左移只提交分组 id，不含未分组哨兵', (tester) async {
    List<String>? submitted;
    await pump(
      tester,
      tasks: [task('a')],
      sections: sections,
      onSectionOrderChanged: (ordered) => submitted = ordered,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('col-sec-pol')),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('左移政治'));
    await tester.pumpAndSettle();

    expect(submitted, ['sec-pol', 'sec-en']);
  });

  testWidgets('分组列的「+」读屏能分清是哪一列', (tester) async {
    await pump(tester, tasks: [task('a')], sections: sections);

    expect(find.byTooltip('在英语新建任务'), findsOneWidget);
    expect(find.byTooltip('在政治新建任务'), findsOneWidget);
    expect(find.byTooltip('在未分组新建任务'), findsOneWidget);
  });

  testWidgets('分组列写入失败会提示并保留原列，不静默吞掉', (tester) async {
    var attempts = 0;
    await pump(
      tester,
      tasks: [task('a')],
      sections: sections,
      onSectionMove: (_, _) async {
        attempts++;
        if (attempts == 1) throw StateError('write failed');
      },
    );

    await dragToEmptyColumn(
      tester,
      cardTitle: '任务-a',
      columnKey: const ValueKey('col-sec-pol'),
    );

    expect(find.text('移动任务失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    // 失败后任务仍留在原列（未分组），不会被挪进政治列。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('col-unsectioned')),
        matching: find.text('任务-a'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('320px + 1.3 倍字号下分组列头不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: KanbanView(
            tasks: [task('a', sectionId: 'sec-long')],
            listId: 'list-inbox',
            sections: [
              section('sec-long', '全年英语语法与词汇复习计划', 0),
              section('sec-pol', '政治', 1),
            ],
            onTaskSectionMove: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('长分组名的列标题用省略号而不是撑破列头', (tester) async {
    await pump(
      tester,
      tasks: [task('a', sectionId: 'sec-en')],
      sections: [section('sec-en', '全年英语语法与词汇复习计划', 0)],
    );

    final title = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(const ValueKey('col-sec-en')),
            matching: find.text('全年英语语法与词汇复习计划'),
          )
          .first,
    );
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.maxLines, 1);
  });

  testWidgets('分组模式已完成任务留在自己的分组列，不聚合成归档列', (tester) async {
    await pump(
      tester,
      tasks: [task('a', sectionId: 'sec-en', completed: true)],
      sections: sections,
    );

    expect(find.text('归档'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('col-sec-en')),
        matching: find.text('任务-a'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('分组模式忽略折叠：偏好里塞分组 id 也不会收起该列', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            tasks: [task('a', sectionId: 'sec-en')],
            listId: 'list-inbox',
            sections: sections,
            collapsedColumnIds: const {'sec-en'},
            onTaskSectionMove: (_, _) async {},
            onColumnCollapsedChanged: (_, _) async {},
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('col-sec-en'))).width, 260);
    expect(find.text('展开英语'), findsNothing);
  });

  testWidgets('分组模式的列头菜单仍列出「折叠」项但不可用（与固定四列一致）', (tester) async {
    await pump(
      tester,
      tasks: [task('a', sectionId: 'sec-en')],
      sections: sections,
      onSectionMove: (_, _) async {},
      onSectionOrderChanged: (_) {},
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('col-sec-en')),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();

    PopupMenuItem<String> item(String label) =>
        tester.widget<PopupMenuItem<String>>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(PopupMenuItem<String>),
          ),
        );
    // 三项都渲染（与 develop 的固定四列一致），折叠在分组模式是「灰显」而不是消失。
    expect(item('折叠英语').enabled, isFalse);
    expect(item('左移英语').enabled, isFalse);
    expect(item('右移英语').enabled, isTrue);
  });

  testWidgets('固定四列的「+」tooltip 也带上列名（本轮确实改了这一处）', (tester) async {
    await pump(tester, tasks: [task('a')]);

    expect(find.byTooltip('在未开始新建任务'), findsOneWidget);
    expect(find.byTooltip('新建任务'), findsNothing);
  });
}
