import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../core/api/sync_api.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/auth_gateway.dart';
import '../core/db/app_database.dart';
import '../core/storage/session_store.dart';
import '../core/sync/sync_change_queue.dart';
import '../core/sync/sync_coordinator.dart';
import '../state/session_state.dart';
import 'repositories/folder_repository.dart';
import 'repositories/list_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/task_repository.dart';

/// ----- API 客户端 --------------------------------------------------------

/// 业务 API 客户端：随 [sessionProvider] 变化重建，始终携带最新 token。
/// token / tenantId 均从会话取（tenantId 默认回退 ApiConfig.defaultTenantId）。
final apiClientProvider = Provider<ApiClient>((ref) {
  ref.watch(sessionProvider);
  return ApiClient(
    tokenProvider: () => ref.read(sessionProvider)?.accessToken ?? '',
    tenantIdProvider: () => ref.read(sessionProvider)?.tenantId ?? ApiConfig.defaultTenantId,
    onUnauthorized: () {
      Future.microtask(() => ref.read(sessionProvider.notifier).signOut());
    },
  );
});

/// ----- 本地库（多租户隔离）-----------------------------------------------

/// 设备唯一标识（持久化，跨启动稳定，供 sync `device_id` 用）。
final deviceIdProvider = FutureProvider<String>((ref) async {
  final store = ref.watch(sessionStoreProvider);
  return store.readOrCreateDeviceId(generate: () => const Uuid().v4());
});

/// 按 `tenantId + userId` 构建用户专属本地库；会话重建时跟随重建。
/// 未登录（会话 null）时返回 null，下游仓库/同步可选置空。
final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  ref.watch(sessionProvider);
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final db = AppDatabase.forUser(
    tenantId: session.tenantId,
    userId: session.userId,
  );
  ref.onDispose(db.close);
  return db;
});

/// 同步变更队列（依赖用户本地库）。
final syncChangeQueueProvider = Provider<SyncChangeQueue?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return SyncChangeQueue(db);
});

/// ----- 各领域仓库 ---------------------------------------------------------

final listRepositoryProvider = Provider<ListRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return ListRepository(db, queue);
});

final folderRepositoryProvider = Provider<FolderRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return FolderRepository(db, queue);
});

final tagRepositoryProvider = Provider<TagRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TagRepository(db, queue);
});

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final queue = ref.watch(syncChangeQueueProvider);
  if (db == null || queue == null) return null;
  return TaskRepository(db, queue);
});

// --- 同步 ---------------------------------------------------------------

final syncApiProvider = Provider<SyncApi?>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull;
  final session = ref.watch(sessionProvider);
  if (deviceId == null || session == null) return null;
  return SyncApi(
    ref.watch(apiClientProvider),
    clientId: 'flutter',
    deviceId: deviceId,
  );
});

final syncCoordinatorProvider = Provider<SyncCoordinator?>((ref) {
  final syncApi = ref.watch(syncApiProvider);
  final db = ref.watch(appDatabaseProvider);
  if (syncApi == null || db == null) return null;
  return SyncCoordinator(
    db: db,
    api: syncApi,
    todoApi: ref.watch(apiClientProvider),
  );
});

// --- 任务 / 清单 / 文件夹 / 标签流 -----------------------------------------

/// 任务列表 stream（顶层任务，按 listId 过滤）。[listId] 本地 UUID。
final tasksByListProvider = StreamProvider.family<List<TodoTask>, String>((
  ref,
  listId,
) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchTopLevelByList(listId);
});

/// 清单列表 stream（不含智能清单）。
final listsStreamProvider = StreamProvider<List<TodoList>>((ref) {
  final repo = ref.watch(listRepositoryProvider);
  if (repo == null) return const Stream<List<TodoList>>.empty();
  return repo.watchAll();
});

/// 用户保存的智能清单 stream（`smart:` 前缀）。
final smartListsStreamProvider = StreamProvider<List<TodoList>>((ref) {
  final repo = ref.watch(listRepositoryProvider);
  if (repo == null) return const Stream<List<TodoList>>.empty();
  return repo.watchSmartLists();
});

/// 文件夹列表 stream。
final foldersStreamProvider = StreamProvider<List<TodoFolder>>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  if (repo == null) return const Stream<List<TodoFolder>>.empty();
  return repo.watchAll();
});

/// 标签列表 stream。
final tagsStreamProvider = StreamProvider<List<TodoTag>>((ref) {
  final repo = ref.watch(tagRepositoryProvider);
  if (repo == null) return const Stream<List<TodoTag>>.empty();
  return repo.watchAll();
});
