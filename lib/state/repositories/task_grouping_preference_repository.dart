import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';
import '../../features/task/smart_grouping.dart';

/// 未存过偏好、旧行缺 `grouping` 键、或取值不认识时的共同回退值：
/// 必须等于本功能上线前唯一的行为（不分组），否则升级即静默改变视图。
const smartGroupingFallback = SmartGrouping.none;

/// 每个清单独立的「智能分组」偏好（嘀嗒《03-用分组和排序管理任务》的
/// 智能分组档，Issue #321）。
///
/// 存法与 `TaskSortPreferenceRepository` 同形：用户库已按 tenant/user 隔离；
/// 库内以 `TASK_GROUP + listId` 唯一，让不同清单、离线重启和跨端同步共用一份。
class TaskGroupingPreferenceRepository {
  TaskGroupingPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _sourceType = 'TASK_GROUP';
  static const _inboxSourceKey = 'inbox';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<SmartGrouping> get(String? listId) async {
    final row =
        await (_db.select(_db.todoViewPreferences)..where(
              (preference) =>
                  preference.sourceType.equals(_sourceType) &
                  preference.sourceKey.equals(_sourceKey(listId)),
            ))
            .getSingleOrNull();
    return _decode(row?.valueJson);
  }

  Stream<SmartGrouping> watch(String? listId) {
    return (_db.select(_db.todoViewPreferences)..where(
          (preference) =>
              preference.sourceType.equals(_sourceType) &
              preference.sourceKey.equals(_sourceKey(listId)),
        ))
        .watchSingleOrNull()
        .map((row) => _decode(row?.valueJson));
  }

  Future<void> save(String? listId, SmartGrouping grouping) async {
    final sourceKey = _sourceKey(listId);
    final now = DateTime.now();
    final valueJson = jsonEncode({'grouping': grouping.name});
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todoViewPreferences)..where(
                (preference) =>
                    preference.sourceType.equals(_sourceType) &
                    preference.sourceKey.equals(sourceKey),
              ))
              .getSingleOrNull();
      final id = existing?.id ?? _uuid.v4();
      final companion = TodoViewPreferencesCompanion(
        id: Value(id),
        serverId: existing?.serverId == null
            ? const Value.absent()
            : Value(existing!.serverId),
        sourceType: const Value(_sourceType),
        sourceKey: Value(sourceKey),
        valueJson: Value(valueJson),
        updatedAt: Value(now),
        createdAt: existing == null ? Value(now) : Value(existing.createdAt),
      );
      if (existing == null) {
        await _db.into(_db.todoViewPreferences).insert(companion);
      } else {
        await (_db.update(
          _db.todoViewPreferences,
        )..where((preference) => preference.id.equals(id))).write(companion);
      }
      await _queue.enqueue(
        entity: SyncEntities.viewPreference,
        op: SyncOps.upsert,
        localId: id,
        serverId: existing?.serverId,
        payload: {
          'sourceType': _sourceType,
          'sourceKey': sourceKey,
          'viewType': 'LIST',
          'valueJson': valueJson,
        },
      );
    });
  }

  String _sourceKey(String? listId) =>
      listId == null || listId.isEmpty ? _inboxSourceKey : listId;

  SmartGrouping _decode(String? valueJson) {
    if (valueJson == null) return smartGroupingFallback;
    try {
      final raw = jsonDecode(valueJson);
      if (raw is! Map<String, dynamic>) return smartGroupingFallback;
      // 本地 save 直接存 `{grouping}`；sync pull 保留服务端实体包装，
      // 实际值在其字符串化的 `valueJson` 字段内。两种格式同样可读，
      // 否则第二设备会静默退回不分组。
      final nested = raw['valueJson'];
      final nestedValue = nested is String ? jsonDecode(nested) : null;
      final value = nestedValue is Map<String, dynamic>
          ? nestedValue['grouping']
          : raw['grouping'];
      return SmartGrouping.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => smartGroupingFallback,
      );
    } on FormatException {
      return smartGroupingFallback;
    }
  }
}
