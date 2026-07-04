import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/todo_client.dart';
import '../api/member_auth_client.dart';
import '../db/app_database.dart';
import 'sync_change_queue.dart';
import 'repositories/list_repository.dart';
import 'repositories/folder_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/task_repository.dart';

/// M11-B1 全局 provider 容器
///
/// - dio 客户端：业务 + 认证
/// - 本地数据库
/// - 后续 B 系在 lib/state/ 中扩展：authController / listController / taskController / syncEngine

final todoApiClientProvider = Provider<TodoApiClient>((ref) {
  return TodoApiClient();
});

final memberAuthClientProvider = Provider<MemberAuthClient>((ref) {
  return MemberAuthClient();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// M11-B2 同步变更队列。
final syncChangeQueueProvider = Provider<SyncChangeQueue>((ref) {
  return SyncChangeQueue(ref.watch(appDatabaseProvider));
});

/// M11-B2 仓库 providers。
final listRepositoryProvider = Provider<ListRepository>((ref) {
  return ListRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncChangeQueueProvider),
  );
});

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncChangeQueueProvider),
  );
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncChangeQueueProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncChangeQueueProvider),
  );
});

/// 任务列表 stream（顶层任务，按 listId 过滤）。
final tasksByListProvider = StreamProvider.family<List<TodoTask>, int>((
  ref,
  listId,
) {
  return ref.watch(taskRepositoryProvider).watchTopLevelByList(listId);
});

/// 清单列表 stream（不含智能清单）。
final listsStreamProvider = StreamProvider<List<TodoList>>((ref) {
  return ref.watch(listRepositoryProvider).watchAll();
});

/// 用户保存的智能清单 stream（`smart:` 前缀）。
final smartListsStreamProvider = StreamProvider<List<TodoList>>((ref) {
  return ref.watch(listRepositoryProvider).watchSmartLists();
});

/// 文件夹列表 stream。
final foldersStreamProvider = StreamProvider<List<TodoFolder>>((ref) {
  return ref.watch(folderRepositoryProvider).watchAll();
});

/// 标签列表 stream。
final tagsStreamProvider = StreamProvider<List<TodoTag>>((ref) {
  return ref.watch(tagRepositoryProvider).watchAll();
});