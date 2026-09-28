import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 侧栏「显示标签」偏好（嘀嗒《01-任务/09-如何管理海量任务/04-用标签管理任务.md》:10/:16/:23/:27）。
///
/// 与 `TaskSortPreferenceRepository` 同一套：`todo_view_preferences` 行 + `viewPreference` outbox，
/// ⇒ 跨端同步走既有通道，不新增表、不 bump `schemaVersion`。
/// 不复用那个类是因为它的签名是 `(listId, TaskSort)`，硬塞全局布尔会让类名与签名一起说谎
/// （spec.md 取舍 2）。
class SidebarVisibilityRepository {
  SidebarVisibilityRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const sourceType = 'SIDEBAR_VISIBILITY';
  static const sourceKey = 'global';

  /// **默认「显示」**：9 张黄金基线里有侧栏画面，默认若改成隐藏就要重录基线（spec.md FR-4）。
  static const defaultShowTags = true;

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<bool> get() async => _decode(
    await (_db.select(_db.todoViewPreferences)..where(
          (preference) =>
              preference.sourceType.equals(sourceType) &
              preference.sourceKey.equals(sourceKey),
        ))
        .getSingleOrNull(),
  );

  Stream<bool> watch() =>
      (_db.select(_db.todoViewPreferences)..where(
            (preference) =>
                preference.sourceType.equals(sourceType) &
                preference.sourceKey.equals(sourceKey),
          ))
          .watchSingleOrNull()
          .map(_decode);

  /// 与排序偏好同一处写法：写行与入队在一个事务里，失败时不留"本地改了、没同步"的半条状态。
  Future<void> save({required bool showTags}) async {
    final now = DateTime.now();
    final valueJson = jsonEncode({'showTags': showTags});
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todoViewPreferences)..where(
                (preference) =>
                    preference.sourceType.equals(sourceType) &
                    preference.sourceKey.equals(sourceKey),
              ))
              .getSingleOrNull();
      final id = existing?.id ?? _uuid.v4();
      final companion = TodoViewPreferencesCompanion(
        id: Value(id),
        serverId: existing?.serverId == null
            ? const Value.absent()
            : Value(existing!.serverId),
        sourceType: const Value(sourceType),
        sourceKey: const Value(sourceKey),
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
          'sourceType': sourceType,
          'sourceKey': sourceKey,
          'viewType': 'LIST',
          'valueJson': valueJson,
        },
      );
    });
  }

  bool _decode(TodoViewPreference? row) {
    final raw = row?.valueJson;
    if (raw == null) return defaultShowTags;
    try {
      final decoded = jsonDecode(raw);
      // 同步拉回来的行可能被服务端实体包一层（`{"valueJson":"{\"showTags\":false}"}`），
      // 与 `TaskSortPreferenceRepository._decode` 同样的两种格式都要读得出来，
      // 否则第二台设备会静默退回默认值。
      final nested = decoded is Map<String, dynamic>
          ? decoded['valueJson']
          : null;
      final nestedValue = nested is String ? jsonDecode(nested) : null;
      final map = nestedValue is Map<String, dynamic> ? nestedValue : decoded;
      if (map is Map<String, dynamic> && map.containsKey('showTags')) {
        return map['showTags'] == true;
      }
    } on FormatException {
      // 坏 JSON ⇒ 退回默认「显示」，与排序偏好的处理一致：一个读不懂的偏好不该把侧栏锁死。
    }
    return defaultShowTags;
  }
}
