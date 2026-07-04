import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../api/api_config.dart';
import '../api/sync_api.dart';
import '../api/todo_client.dart';
import '../db/app_database.dart';
import '../sync/sync_coordinator.dart';
import 'session_state.dart';
import 'sync_change_queue.dart';
import 'repositories/list_repository.dart';
import 'repositories/folder_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/task_repository.dart';

/// 全局 provider 容器
///
/// - dio 客户端：业务 API（已注入 Bearer/tenant-id，见 [TodoApiClient]）
/// - 本地数据库、同步队列、各领域 Repository

/// 业务 API 客户端；随 [sessionProvider] 变化重建，始终携带最新 token。
final todoApiClientProvider = Provider<TodoApiClient>((ref) {
  ref.watch(sessionProvider);
  return TodoApiClient(
    tokenProvider: () => ref.read(sessionProvider)?.accessToken ?? '',
    tenantId: ApiConfig.defaultTenantId,
    onUnauthorized: () {
      // 避免在 build 过程中同步修改 provider：延后到下一帧。
      Future.microtask(() => ref.read(sessionProvider.notifier).signOut());
    },
  );
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

// --- 同步 --------------------------------------------------------------

/// 设备唯一标识（持久化，跨启动稳定，用于 sync `device_id`）。
final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'zh_cloud_todo_flutter_device_id';
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;
  final generated = const Uuid().v4();
  await prefs.setString(key, generated);
  return generated;
});

final syncApiProvider = Provider<SyncApi?>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull;
  final session = ref.watch(sessionProvider);
  if (deviceId == null || session == null) return null;
  return SyncApi(
    ref.watch(todoApiClientProvider).raw,
    clientId: 'flutter',
    deviceId: deviceId,
  );
});

final syncCoordinatorProvider = Provider<SyncCoordinator?>((ref) {
  final syncApi = ref.watch(syncApiProvider);
  if (syncApi == null) return null;
  return SyncCoordinator(
    db: ref.watch(appDatabaseProvider),
    api: syncApi,
    todoApi: ref.watch(todoApiClientProvider),
  );
});
