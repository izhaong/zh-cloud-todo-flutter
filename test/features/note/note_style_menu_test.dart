import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/features/note/note_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/note_repository.dart';

/// 嘀嗒《03-特色功能/11-笔记与摘要.md:43》：
/// 「你可以使用键盘上方的样式菜单，给内容设置加粗、高亮等样式。」
/// 标记形态照抄《02-功能指南/01-任务/03-编辑与排版.md:48》与 `:49` 那张 Markdown 表：
/// `**文字**` 即加粗、`==文字==` 即高亮 —— 不自造第三种语法。
///
/// 选区用真键盘造（Home → Shift + →）：「按住 Shift 精确选中文字」本身就是嘀嗒
/// 《09-桌面快捷操作.md:68》要求的能力；读值只走公开 API
/// （`tester.widget<TextField>(...).controller`），不碰 `EditableTextState` 的非公开成员。
void main() {
  testWidgets('笔记编辑器带「加粗」「高亮」样式菜单', (tester) async {
    await _openEditor(tester);
    expect(find.byTooltip('加粗'), findsOneWidget, reason: '嘀嗒 :43 的样式菜单');
    expect(find.byTooltip('高亮'), findsOneWidget);
  });

  testWidgets('选中后点「加粗」写成 **…），再点「高亮」叠成 ==…**', (tester) async {
    await _openEditor(tester);
    final content = find.byKey(const Key('todo-note-content'));
    await tester.enterText(content, '截止时间');
    await tester.pump();
    await _selectFromStart(tester, content, skip: 0, take: 4);

    await tester.tap(find.byTooltip('加粗'));
    await tester.pump();
    expect(_text(content), '**截止时间**');

    await _selectFromStart(tester, content, skip: 2, take: 2);
    await tester.tap(find.byTooltip('高亮'));
    await tester.pump();
    expect(_text(content), '**==截止==时间**');
    expect(
      _range(content),
      const _Range(2, 8),
      reason: '包裹后选区要跟着扩到含标记，否则连点两次只会把标记本身当正文再包一层',
    );
  });

  testWidgets('光标折叠时点「高亮」插入成对标记并把光标落在中间', (tester) async {
    await _openEditor(tester);
    final content = find.byKey(const Key('todo-note-content'));
    await tester.enterText(content, 'ab');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_range(content), const _Range(1, 1), reason: '光标停在 a 与 b 之间');

    await tester.tap(find.byTooltip('高亮'));
    await tester.pump();
    expect(_text(content), 'a====b');
    expect(_range(content), const _Range(3, 3));
  });

  testWidgets('样式只作用在内容框，不串到标题框', (tester) async {
    await _openEditor(tester);
    final title = find.byKey(const Key('todo-note-title'));
    final content = find.byKey(const Key('todo-note-content'));
    await tester.enterText(title, '会议纪要');
    await tester.enterText(content, '正文');
    await tester.pump();
    await _selectFromStart(tester, content, skip: 0, take: 2);

    await tester.tap(find.byTooltip('加粗'));
    await tester.pump();
    expect(_text(content), '**正文**');
    expect(_text(title), '会议纪要', reason: '嘀嗒那一节只说「给内容设置样式」');
  });

  testWidgets('320px + 1.3 倍字号下样式菜单不溢出', (tester) async {
    await _openEditor(tester, width: 320, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('加粗'), findsOneWidget);
    expect(find.byTooltip('高亮'), findsOneWidget);
  });
}

class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is _Range && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '($start, $end)';
}

TextEditingController _controller(Finder field) =>
    (field.evaluate().single.widget as TextField).controller!;

String _text(Finder field) => _controller(field).text;

_Range _range(Finder field) {
  final selection = _controller(field).selection;
  return _Range(selection.start, selection.end);
}

/// Home 回行首 → 右移 skip 格 → Shift + 右 选 take 格。
Future<void> _selectFromStart(
  WidgetTester tester,
  Finder field, {
  required int skip,
  required int take,
}) async {
  await tester.tap(field);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.home);
  await tester.pump();
  for (var i = 0; i < skip; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  for (var i = 0; i < take; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Future<void> _openEditor(
  WidgetTester tester, {
  double width = 800,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(_FakeNoteRepository()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const NotePage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('todo-note-add')));
  await tester.pumpAndSettle();
}

class _FakeNoteRepository implements NoteRepository {
  @override
  Future<List<TodoNoteItem>> notes({bool includeArchived = false}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
