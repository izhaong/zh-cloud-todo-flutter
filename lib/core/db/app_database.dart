import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// 离线优先本地库（Drift）。
///
/// **设计要点（对齐 Todo 离线优先能力规划）**：
/// - **UUID-v4 本地主键**：所有 sync 白名单实体本地主键为 `String`（客户端
///   自生成 UUID-v4），本地外键（`listId` / `taskId` / ...）也走 `String`。
///   支持完全离线 CRUD，无需占位 ID。
/// - **serverId 映射收敛到 sync 层**：每张实体表保留 `serverId`（后端整数
///   主键，可空）仅供 `SyncCoordinator` 在 push（负数临时 ID）/pull（回写
///   serverId）时映射；UI 与 Repository 一律以本地 UUID 为准。
/// - **多租户隔离**：[AppDatabase.forUser] 按 `tenantId + userId` 动态命名
///   SQLite 文件（`todo_t<tenant>_u<user>.sqlite`），切换账号/租户天然隔离。
///
/// 表清单：
/// - todo_list / todo_task / todo_folder(REST 直连) / todo_tag / todo_task_tag
/// - todo_reminder / todo_repeat_rule / todo_repeat_skip
/// - todo_view_preference / todo_filter
/// - todo_sync_change（outbox 本地变更队列）/ todo_sync_cursor / todo_entity_revision

// --- sync 白名单实体（本地 UUID 主键）-------------------------------------

class TodoLists extends Table {
  TextColumn get id => text()(); // UUID-v4 本地主键
  IntColumn get serverId => integer().nullable()(); // 后端整数主键（sync 映射用）
  TextColumn get name => text()();
  IntColumn get folderId => integer().nullable()(); // folder 走 REST，保留 int 外键
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TodoTasks extends Table {
  TextColumn get id => text()(); // UUID-v4 本地主键
  IntColumn get serverId => integer().nullable()();
  TextColumn get listId => text()(); // 本地 UUID 外键 → todo_list.id
  TextColumn get parentTaskId =>
      text().nullable()(); // 本地 UUID 外键 → todo_task.id
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  BoolColumn get cancelled => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 文件夹：不在后端 `/sync` 白名单，走普通 REST（`/app-api/todo/folder`）。
/// 仍本地缓存展示 + 复用 outbox 做离线重试。本地主键同样用 UUID。
class TodoFolders extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TodoTags extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 任务-标签关联（本地 UUID 复合主键）。
class TodoTaskTags extends Table {
  TextColumn get taskId => text()(); // → todo_task.id
  TextColumn get tagId => text()(); // → todo_tag.id
  IntColumn get serverId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

/// 任务检查事项：本地 UUID 保证任务尚未同步时也能离线编辑。
class TodoChecklistItems extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get taskId => text()();
  TextColumn get title => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 任务附件元数据及本地上传状态。二进制由本地路径和上传队列管理。
class TodoAttachments extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get taskId => text()();
  TextColumn get name => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get mimeType => text()();
  IntColumn get size => integer()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 服务端任务动态的本地只读缓存；联网刷新后离线仍可展示最近活动。
class TodoActivities extends Table {
  IntColumn get serverId => integer()();
  IntColumn get taskServerId => integer()();
  IntColumn get actorUserId => integer().nullable()();
  TextColumn get actorUserName => text().nullable()();
  TextColumn get action => text()();
  TextColumn get detail => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {serverId};
}

/// 任务模板的本地真相源；服务端登记通过 outbox 异步完成。
class TodoTemplates extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get contentJson => text()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 提醒（任务维度，单任务可有多条提醒规则）。
class TodoReminders extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get taskId => text()(); // → todo_task.id
  DateTimeColumn get remindAt => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('PENDING'))(); // PENDING/DISMISSED/DONE
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 重复规则（任务维度，一对一）。
class TodoRepeatRules extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get taskId => text()(); // → todo_task.id
  TextColumn get freq => text()(); // DAILY/WEEKLY/MONTHLY/YEARLY/CUSTOM
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get byDay => text().nullable()(); // 逗号分隔，如 MO,WE,FR
  DateTimeColumn get until => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 重复规则的单次跳过记录。
class TodoRepeatSkips extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get repeatRuleId => text()(); // → todo_repeat_rule.id
  TextColumn get taskId => text()(); // → todo_task.id
  DateTimeColumn get occurrenceDate => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 视图偏好（按 sourceType + sourceKey 唯一）。
class TodoViewPreferences extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get sourceType => text()();
  TextColumn get sourceKey => text()();
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {sourceType, sourceKey},
  ];
}

/// 过滤器 / 智能清单条件。
class TodoFilters extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get conditionJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- sync 协调表 -----------------------------------------------------------

/// 本地变更队列（outbox）。
class TodoSyncChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientMutationId => text().unique()(); // 幂等键（UUID-v4）
  TextColumn get entity =>
      text()(); // list/task/reminder/repeat_rule/... （见 SyncEntities）
  TextColumn get op => text()(); // upsert/delete
  TextColumn get entityLocalId => text().nullable()(); // 本地 UUID（离线实体真相源）
  IntColumn get entityServerId => integer().nullable()(); // 已同步实体的服务端 ID
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get status =>
      text().withDefault(const Constant('queued'))(); // queued/synced/failed
}

/// 全局同步游标（单行，id 固定为 1）。
class TodoSyncCursor extends Table {
  IntColumn get id => integer()();
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 服务端 revision 镜像：push 前查询作为 baseRevision，pull 后写回最新值。
/// 以 serverId（后端整数主键）为键——revision 是服务端概念。
class TodoEntityRevisions extends Table {
  TextColumn get entity => text()();
  IntColumn get serverId => integer()();
  IntColumn get revision => integer()();

  @override
  Set<Column> get primaryKey => {entity, serverId};
}

@DriftDatabase(
  tables: [
    TodoLists,
    TodoTasks,
    TodoFolders,
    TodoTags,
    TodoTaskTags,
    TodoChecklistItems,
    TodoAttachments,
    TodoActivities,
    TodoTemplates,
    TodoReminders,
    TodoRepeatRules,
    TodoRepeatSkips,
    TodoViewPreferences,
    TodoFilters,
    TodoSyncChanges,
    TodoSyncCursor,
    TodoEntityRevisions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open(null));
  AppDatabase.forTesting(super.e);

  /// 多租户隔离构造：按 `tenantId + userId` 命名 SQLite 文件。
  /// 未登录阶段（tenantId/userId 未知）用共享占位库，登录后由
  /// [SessionController] 重建指向用户专属库。
  AppDatabase.forUser({required String tenantId, required int userId})
    : super(_open('todo_t${tenantId}_u$userId'));

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    // 注：schemaVersion 4 = P1 重建（UUID 本地主键）。本地库为全新结构，
    // 旧 schema（int 主键）与新版不兼容；升级时逐表 drop 重建。
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        for (final table in allTables) {
          await m.deleteTable(table.actualTableName);
        }
        await m.createAll();
      } else if (from < 5) {
        await m.createTable(todoChecklistItems);
      }
      if (from < 6) {
        await m.createTable(todoAttachments);
      }
      if (from < 7) {
        await m.addColumn(todoTasks, todoTasks.cancelled);
      }
      if (from < 8) {
        await m.createTable(todoActivities);
      }
      if (from < 9) {
        await m.createTable(todoTemplates);
      }
    },
  );

  static QueryExecutor _open(String? fileName) {
    // 测试环境（forTesting 注入 NativeDatabase.memory）或无文件名时用默认。
    // driftFlutter 的 driftDatabase 在 Web 自动选用 wasm。
    return driftDatabase(name: fileName ?? 'zh_cloud_todo');
  }

  // --- DAO helpers ---------------------------------------------------------

  /// 切换任务完成状态（乐观更新本地；调用方负责 outbox 写入）。
  Future<TodoTask> toggleTaskComplete(String taskId) async {
    final row = await (select(
      todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
    final next = row.copyWith(
      completed: !row.completed,
      cancelled: false,
      updatedAt: DateTime.now(),
    );
    await (update(todoTasks)..where((t) => t.id.equals(taskId))).write(next);
    return next;
  }

  /// 将一个任务改为另一个任务的子任务（parentTaskId = newParentId）。
  Future<void> reparentTask(String taskId, String? newParentId) async {
    await (update(todoTasks)..where((t) => t.id.equals(taskId))).write(
      TodoTasksCompanion(
        parentTaskId: Value(newParentId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 统计清单下未完成任务数（删除清单前用于拦截弹窗）。
  Future<int> countOpenTasksByList(String listId) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM todo_tasks WHERE list_id = ? AND completed = 0',
      variables: [Variable.withString(listId)],
      readsFrom: {todoTasks},
    ).getSingle();
    return row.read<int>('c');
  }

  /// 子任务查询（直接 children）。
  Future<List<TodoTask>> childrenOf(String parentTaskId) {
    return (select(todoTasks)
          ..where((t) => t.parentTaskId.equals(parentTaskId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// 子任务 reactive stream（直接 children），DB 变更时自动推送。
  Stream<List<TodoTask>> watchChildrenOf(String parentTaskId) {
    return (select(todoTasks)
          ..where((t) => t.parentTaskId.equals(parentTaskId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  // --- sync cursor / revision ---------------------------------------------

  Future<TodoSyncCursorData?> readSyncCursor() {
    return (select(
      todoSyncCursor,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
  }

  Future<void> writeSyncCursor(String? cursor) async {
    await into(todoSyncCursor).insertOnConflictUpdate(
      TodoSyncCursorCompanion.insert(
        id: const Value(1),
        cursor: Value(cursor),
        lastSyncAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int?> readRevision(String entity, int serverId) async {
    final row =
        await (select(todoEntityRevisions)..where(
              (t) => t.entity.equals(entity) & t.serverId.equals(serverId),
            ))
            .getSingleOrNull();
    return row?.revision;
  }

  Future<void> writeRevision(String entity, int serverId, int revision) async {
    await into(todoEntityRevisions).insertOnConflictUpdate(
      TodoEntityRevisionsCompanion.insert(
        entity: entity,
        serverId: serverId,
        revision: revision,
      ),
    );
  }

  /// 按 serverId 查本地行（pull/冲突回写时用）。
  Future<TodoTask?> taskByServerId(int serverId) => (select(
    todoTasks,
  )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
  Future<TodoList?> listByServerId(int serverId) => (select(
    todoLists,
  )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
  Future<TodoTag?> tagByServerId(int serverId) => (select(
    todoTags,
  )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();

  /// 按本地 UUID 主键查清单（任务详情反查清单 serverId 用）。
  Future<TodoList?> listByLocalId(String localId) =>
      (select(todoLists)..where((t) => t.id.equals(localId))).getSingleOrNull();
}
