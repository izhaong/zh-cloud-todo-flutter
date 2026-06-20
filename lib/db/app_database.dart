import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// M11-B1 Drift 本地表（脚手架版本）
/// - todo_list：清单
/// - todo_task：任务（FK listId）
/// - todo_folder：文件夹
/// - todo_tag / todo_task_tag：标签与任务-标签关联
/// - todo_sync_change：本地变更队列（push 同步用）
/// - todo_sync_state：远端 cursor 与 lastSyncAt

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
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
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

class TodoSyncChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()(); // LIST / TASK / FOLDER / TAG
  TextColumn get op => text()(); // CREATE / UPDATE / DELETE
  IntColumn get entityLocalId => integer().nullable()();
  IntColumn get entityServerId => integer().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('queued'))();
}

class TodoSyncStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text().unique()();
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
}

@DriftDatabase(
  tables: [
    TodoLists,
    TodoTasks,
    TodoFolders,
    TodoTags,
    TodoTaskTags,
    TodoSyncChanges,
    TodoSyncStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() {
    // 默认平台 native (drift_flutter 提供)；Web/iOS 见 build_runner 输出
    return driftDatabase(name: 'zh_cloud_todo');
  }
}