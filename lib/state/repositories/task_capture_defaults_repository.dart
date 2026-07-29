import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 快速收集的用户级创建默认值。
///
/// 默认值复用跨端同步的 `view_preference` 实体，固定来源为
/// `TASK_CAPTURE/defaults`。这避免和任务级 `/task-defaults`（B2 兼容 API）
/// 混淆，也让离线保存与 outbox 具有相同的恢复语义。
class TaskCaptureDefaults {
  const TaskCaptureDefaults({this.defaultListId, this.defaultPriority = 0});

  final String? defaultListId;
  final int defaultPriority;

  Map<String, dynamic> toJson() => {
    'defaultListId': defaultListId,
    'defaultPriority': defaultPriority,
  };

  static TaskCaptureDefaults fromJson(Map<String, dynamic> json) {
    final priority = json['defaultPriority'];
    return TaskCaptureDefaults(
      defaultListId: json['defaultListId']?.toString(),
      defaultPriority: priority is num ? priority.toInt() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskCaptureDefaults &&
      other.defaultListId == defaultListId &&
      other.defaultPriority == defaultPriority;

  @override
  int get hashCode => Object.hash(defaultListId, defaultPriority);
}

class TaskCaptureDefaultsRepository {
  TaskCaptureDefaultsRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _sourceType = 'TASK_CAPTURE';
  static const _sourceKey = 'defaults';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Stream<TaskCaptureDefaults> watch() {
    return (_db.select(_db.todoViewPreferences)..where(
          (row) =>
              row.sourceType.equals(_sourceType) &
              row.sourceKey.equals(_sourceKey),
        ))
        .watchSingleOrNull()
        .map(_decode);
  }

  Future<TaskCaptureDefaults> get() async {
    final row =
        await (_db.select(_db.todoViewPreferences)..where(
              (row) =>
                  row.sourceType.equals(_sourceType) &
                  row.sourceKey.equals(_sourceKey),
            ))
            .getSingleOrNull();
    return _decode(row);
  }

  Future<void> save(TaskCaptureDefaults defaults) async {
    final now = DateTime.now();
    final valueJson = jsonEncode(defaults.toJson());
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todoViewPreferences)..where(
                (row) =>
                    row.sourceType.equals(_sourceType) &
                    row.sourceKey.equals(_sourceKey),
              ))
              .getSingleOrNull();
      final id = existing?.id ?? _uuid.v4();
      final companion = TodoViewPreferencesCompanion(
        id: Value(id),
        serverId: existing?.serverId == null
            ? const Value.absent()
            : Value(existing!.serverId),
        sourceType: const Value(_sourceType),
        sourceKey: const Value(_sourceKey),
        valueJson: Value(valueJson),
        updatedAt: Value(now),
        createdAt: existing == null ? Value(now) : Value(existing.createdAt),
      );
      if (existing == null) {
        await _db.into(_db.todoViewPreferences).insert(companion);
      } else {
        await (_db.update(
          _db.todoViewPreferences,
        )..where((row) => row.id.equals(id))).write(companion);
      }
      await _queue.enqueue(
        entity: SyncEntities.viewPreference,
        op: SyncOps.upsert,
        localId: id,
        serverId: existing?.serverId,
        payload: {
          'sourceType': _sourceType,
          'sourceKey': _sourceKey,
          'viewType': 'LIST',
          'valueJson': valueJson,
        },
      );
    });
  }

  TaskCaptureDefaults _decode(TodoViewPreference? row) {
    if (row == null) return const TaskCaptureDefaults();
    try {
      final raw = jsonDecode(row.valueJson);
      if (raw is! Map<String, dynamic>) return const TaskCaptureDefaults();
      final nested = raw['valueJson'];
      if (nested is String) {
        final decoded = jsonDecode(nested);
        if (decoded is Map<String, dynamic>) {
          return TaskCaptureDefaults.fromJson(decoded);
        }
      }
      return TaskCaptureDefaults.fromJson(raw);
    } on FormatException {
      return const TaskCaptureDefaults();
    }
  }
}
