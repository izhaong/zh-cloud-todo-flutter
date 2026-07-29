import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/features/note/note_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/note_repository.dart';

void main() {
  testWidgets('note page lists and previews Markdown notes', (tester) async {
    final repository = _FakeNoteRepository([
      const TodoNoteItem(
        id: 1,
        title: '本周复盘',
        content: '# 已完成\n- 同步闭环',
        contentType: 2,
        archived: false,
      ),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('本周复盘'), findsOneWidget);
    await tester.tap(find.text('本周复盘'));
    await tester.pumpAndSettle();
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('同步闭环'), findsOneWidget);
  });

  testWidgets('note page creates a Markdown note through repository', (
    tester,
  ) async {
    final repository = _FakeNoteRepository([]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todo-note-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('todo-note-title')), '会议纪要');
    await tester.enterText(
      find.byKey(const Key('todo-note-content')),
      '- 决策 A',
    );
    await tester.tap(find.byKey(const Key('todo-note-save')));
    await tester.pumpAndSettle();

    expect(repository.createdTitles, ['会议纪要']);
    expect(find.text('会议纪要'), findsOneWidget);
  });
}

Widget _app(NoteRepository repository) {
  return ProviderScope(
    overrides: [noteRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: NotePage()),
  );
}

class _FakeNoteRepository implements NoteRepository {
  _FakeNoteRepository(List<TodoNoteItem> seed)
    : _items = List<TodoNoteItem>.of(seed);

  final List<TodoNoteItem> _items;
  final List<String> createdTitles = [];

  @override
  Future<List<TodoNoteItem>> list() async => List.unmodifiable(_items);

  @override
  Future<int> create({required String title, required String content}) async {
    createdTitles.add(title);
    final id = _items.length + 1;
    _items.add(
      TodoNoteItem(
        id: id,
        title: title,
        content: content,
        contentType: 2,
        archived: false,
      ),
    );
    return id;
  }

  @override
  Future<void> update({
    required int id,
    required String title,
    required String content,
    int sortOrder = 0,
  }) async {}

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> archive(int id, {required bool archived}) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<int> convertFromTask(int taskId) async => 1;
}
