import '../../core/api/todo_api.dart';

abstract interface class NoteRepository {
  Future<List<TodoNoteItem>> list();

  Future<int> create({required String title, required String content});

  Future<void> update({
    required int id,
    required String title,
    required String content,
    int sortOrder,
  });

  Future<void> delete(int id);

  Future<void> archive(int id, {required bool archived});

  Future<int> convertFromTask(int taskId);
}

class ApiNoteRepository implements NoteRepository {
  ApiNoteRepository(this._api);

  final NoteApi _api;

  @override
  Future<List<TodoNoteItem>> list() => _api.list();

  @override
  Future<int> create({required String title, required String content}) =>
      _api.create(title: title, content: content);

  @override
  Future<void> update({
    required int id,
    required String title,
    required String content,
    int sortOrder = 0,
  }) =>
      _api.update(id: id, title: title, content: content, sortOrder: sortOrder);

  @override
  Future<void> delete(int id) => _api.delete(id);

  @override
  Future<void> archive(int id, {required bool archived}) =>
      _api.archive(id, archived: archived);

  @override
  Future<int> convertFromTask(int taskId) => _api.convertFromTask(taskId);
}
