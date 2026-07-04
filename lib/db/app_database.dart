import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Drift 本地表
/// - todo_list：清单
/// - todo_task：任务（FK listId）
/// - todo_folder：文件夹（REST 直连，不进入 `/sync` 白名单）
/// - todo_tag / todo_task_tag：标签与任务-标签关联
/// - todo_reminder / todo_repeat_rule / todo_repeat_skip：提醒与重复
/// - todo_view_preference / todo_filter：视图偏好与过滤器
/// - todo_sync_change：本地变更队列（push 同步用）
/// - todo_sync_cursor：全局同步游标（对应后端 opaque cursor）
/// - todo_entity_revision：服务端 revision 镜像，供 push 时携带 baseRevision

class TodoLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  IntColumn get folderId => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class TodoTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get listId => integer()();
  IntColumn get parentTaskId => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class TodoFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class TodoTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class TodoTaskTags extends Table {
  IntColumn get taskId => integer()();
  IntColumn get tagId => integer()();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

/// 提醒（任务维度，单任务可有多条提醒规则）。
class TodoReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get taskId => integer()();
  DateTimeColumn get remindAt => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('PENDING'))(); // PENDING/DISMISSED/DONE
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 重复规则（任务维度，一对一）。
class TodoRepeatRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get taskId => integer()();
  TextColumn get freq => text()(); // DAILY/WEEKLY/MONTHLY/YEARLY/CUSTOM
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get byDay => text().nullable()(); // 逗号分隔，如 MO,WE,FR
  DateTimeColumn get until => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 重复规则的单次跳过记录。
class TodoRepeatSkips extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get repeatRuleId => integer()();
  DateTimeColumn get occurrenceDate => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 视图偏好（单用户单行，key-value 精简为固定字段）。
class TodoViewPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get scope =>
      text().unique()(); // e.g. 'task_view' / 'calendar_view'
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 过滤器 / 智能清单条件。
class TodoFilters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get conditionJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class TodoSyncChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientMutationId => text().unique()();
  TextColumn get entity =>
      text()(); // list/task/reminder/repeat_rule/... （见 SyncEntities）
  TextColumn get op => text()(); // upsert/delete
  IntColumn get entityLocalId => integer().nullable()();
  IntColumn get entityServerId => integer().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get status =>
      text().withDefault(const Constant('queued'))(); // queued/synced/failed

  @override
  List<Set<Column>> get uniqueKeys => [];
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
  AppDatabase() : super(_open());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(todoTasks, todoTasks.parentTaskId);
      }
      if (from < 3) {
        await m.addColumn(todoTasks, todoTasks.isPinned);
        await m.addColumn(todoTasks, todoTasks.sortOrder);
        await m.createTable(todoReminders);
        await m.createTable(todoRepeatRules);
        await m.createTable(todoRepeatSkips);
        await m.createTable(todoViewPreferences);
        await m.createTable(todoFilters);
        await m.createTable(todoEntityRevisions);
        await m.createTable(todoSyncCursor);
      }
    },
  );

  static QueryExecutor _open() {
    // 默认平台 native (drift_flutter 提供)；Web 由 drift_flutter 自动选用 wasm。
    return driftDatabase(name: 'zh_cloud_todo');
  }

  // --- DAO helpers ---------------------------------------------------------

  /// 切换任务完成状态（乐观更新本地 + 调用方负责 sync_queue 写入）。
  Future<TodoTask> toggleTaskComplete(int taskId) async {
    final row = await (select(
      todoTasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
    final next = row.copyWith(
      completed: !row.completed,
      updatedAt: DateTime.now(),
    );
    await (update(todoTasks)..where((t) => t.id.equals(taskId))).write(next);
    return next;
  }

  /// 将一个任务改为另一个任务的子任务（parentTaskId = newParentId）。
  Future<void> reparentTask(int taskId, int? newParentId) async {
    await (update(todoTasks)..where((t) => t.id.equals(taskId))).write(
      TodoTasksCompanion(
        parentTaskId: Value(newParentId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 统计清单下未完成任务数（删除清单前用于拦截弹窗）。
  Future<int> countOpenTasksByList(int listId) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM todo_tasks WHERE list_id = ? AND completed = 0',
      variables: [Variable.withInt(listId)],
      readsFrom: {todoTasks},
    ).getSingle();
    return row.read<int>('c');
  }

  /// 子任务查询（直接 children）。
  Future<List<TodoTask>> childrenOf(int parentTaskId) {
    return (select(todoTasks)
          ..where((t) => t.parentTaskId.equals(parentTaskId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// 读取（或初始化）全局同步游标。
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
}
