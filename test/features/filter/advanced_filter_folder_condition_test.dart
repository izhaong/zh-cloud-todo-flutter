import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart'
    show TodoFolder;
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md》
/// `:50`「按照清单名称、标签、日期等属性进行多维度筛选」，并把文件夹定义为清单的容器
/// —— 本单（FL Issue #333）判过的缺口是：`TaskFilter.folderId` 两端都没接线，
/// 面板里根本没有「文件夹」这条条件。
const _folderSectionKey = Key('task-filter-folder-section');

Future<void> _openAdvancedDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-filter-menu')));
  await tester.pumpAndSettle();
  final advanced = find.byKey(const Key('todo-filter-advanced'));
  await tester.ensureVisible(advanced);
  await tester.pumpAndSettle();
  await tester.tap(advanced);
  await tester.pumpAndSettle();
}

Future<void> _enablePreview(WidgetTester tester) async {
  final toggle = find.byKey(const Key('task-filter-advanced-preview'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  if (!tester.widget<Switch>(toggle).value) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
}

Future<void> _tapFolder(WidgetTester tester, String name) async {
  final chip = find.descendant(
    of: find.byKey(_folderSectionKey),
    matching: find.widgetWithText(ChoiceChip, name),
  );
  expect(chip, findsOneWidget, reason: '「文件夹」小节里没有名为「$name」的选项');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

String _panelTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('task-filter-advanced-preview-panel')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .join('｜');
}

/// 「命中 N 项」里的 N；拿不到就红，别让断言悄悄退化成「文案存在」。
int _previewHits(WidgetTester tester) {
  final match = RegExp(r'命中 (\d+) 项').firstMatch(_panelTexts(tester));
  expect(match, isNotNull, reason: '预览面板里没有可解析的「命中 N 项」计数');
  return int.parse(match!.group(1)!);
}

Future<TodoVisualFixture> _pump(WidgetTester tester) async {
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
  return fixture;
}

void main() {
  testWidgets('高级筛选对话框里有「文件夹」小节，选项来自文件夹列表', (tester) async {
    await _pump(tester);
    await _openAdvancedDialog(tester);

    expect(
      find.byKey(_folderSectionKey),
      findsOneWidget,
      reason: '嘀嗒《05-过滤器》`:50` 把清单/文件夹列为筛选维度之一 —— 这张对话框里没有这一格',
    );
    expect(
      find.descendant(
        of: find.byKey(_folderSectionKey),
        matching: find.text('文件夹'),
      ),
      findsOneWidget,
      reason: '小节要有自己的标题，读屏才知道这组选项是什么',
    );
    // fixture 里只有一个文件夹：「项目」（挂「工作」清单）。
    await _tapFolder(tester, '项目');
  });

  testWidgets('选「项目」预览只剩该文件夹下清单的任务，取消后回到原状', (tester) async {
    await _pump(tester);
    await _openAdvancedDialog(tester);
    await _enablePreview(tester);

    final before = _previewHits(tester);
    expect(before, greaterThan(1), reason: '夹具里跨多个清单有不止一条任务，未加条件时不该只有 1 项');

    await _tapFolder(tester, '项目');
    expect(_previewHits(tester), 1, reason: '「项目」文件夹只有「工作」这一张清单，里面 1 条任务');

    await _tapFolder(tester, '项目');
    expect(_previewHits(tester), before, reason: '再点一次要清空这条条件，回到未加文件夹条件时的结果');
  });

  testWidgets('应用文件夹条件后，筛选条上能看见它已生效', (tester) async {
    await _pump(tester);
    await _openAdvancedDialog(tester);
    await _tapFolder(tester, '项目');

    await tester.tap(find.text('应用高级筛选'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('todo-filter-advanced')),
        matching: find.text('文件夹'),
      ),
      findsOneWidget,
      reason: '文件夹条件没写进 TaskFilter，或高级筛选入口的标签没跟着显示',
    );
  });

  testWidgets('应用后列表真的被筛掉（不是只有标签变了）', (tester) async {
    await _pump(tester);
    await _openAdvancedDialog(tester);
    await _tapFolder(tester, '项目');
    await tester.tap(find.text('应用高级筛选'));
    await tester.pumpAndSettle();

    expect(
      find.byType(TaskRow),
      findsOneWidget,
      reason: '「项目」文件夹下只有 1 条任务；屏上不止一行说明归属索引没参与求值',
    );
  });

  testWidgets('一个文件夹都没有时给可见提示，不静默退化成空小节', (tester) async {
    // 夹具的 empty 档只跳过失焦任务，文件夹与清单仍会插入 ⇒ 这里直接覆盖文件夹流，
    // 才真的量到「一个文件夹都没有」这一态。
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        foldersStreamProvider.overrideWith(
          (ref) => Stream.value(const <TodoFolder>[]),
        ),
      ],
    );
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
    await _openAdvancedDialog(tester);

    expect(
      find.descendant(
        of: find.byKey(_folderSectionKey),
        matching: find.textContaining('还没有文件夹'),
      ),
      findsOneWidget,
      reason: '零文件夹要可见说明（四件套③），不能什么都不列还显示成「没有可选」的样子',
    );
  });
}
