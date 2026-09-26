import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 「设置 → 日期与时间 → 时区」这条总开关（specs/055 / FL Issue #368）。
///
/// 落在既有的 `todo_view_preferences` 上（`DATE_TIME` + `timezone`）：不新增表、不进 SQL，
/// 也**不写任何任务字段** —— 开关只决定任务上「固定时区」这一档可不可见（取舍见 spec 六-3）。
class TimezonePreferenceRepository {
  TimezonePreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const sourceType = 'DATE_TIME';
  static const sourceKey = 'timezone';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  /// 没有记录时按「开」处理：本仓的固定时区能力今天对每个任务恒可用，
  /// 默认关会让它对所有老用户凭空消失（数据在、入口没了）。
  Future<bool> get() async => _decode((await _row())?.valueJson);

  Stream<bool> watch() {
    return (_db.select(_db.todoViewPreferences)..where(
          (row) =>
              row.sourceType.equals(sourceType) &
              row.sourceKey.equals(sourceKey),
        ))
        .watchSingleOrNull()
        .map((row) => _decode(row?.valueJson));
  }

  Future<void> setEnabled(bool enabled) async {
    final now = DateTime.now();
    final existing = await _row();
    final id = existing?.id ?? _uuid.v4();
    final valueJson = jsonEncode({'enabled': enabled});
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
      )..where((row) => row.id.equals(id))).write(companion);
    }
    // payload 不带 viewType：服务端的 AppTodoViewPreferenceSaveReqVO 只有
    // sourceType / sourceKey 是 @NotBlank，viewType 可空（已读该 VO 字节确认）。
    await _queue.enqueue(
      entity: SyncEntities.viewPreference,
      op: SyncOps.upsert,
      localId: id,
      serverId: existing?.serverId,
      payload: {
        'sourceType': sourceType,
        'sourceKey': sourceKey,
        'valueJson': valueJson,
      },
    );
  }

  Future<TodoViewPreference?> _row() {
    return (_db.select(_db.todoViewPreferences)..where(
          (row) =>
              row.sourceType.equals(sourceType) &
              row.sourceKey.equals(sourceKey),
        ))
        .getSingleOrNull();
  }

  bool _decode(String? valueJson) {
    if (valueJson == null) return true;
    try {
      final raw = jsonDecode(valueJson);
      if (raw is! Map<String, dynamic>) return true;
      final enabled = raw['enabled'];
      return enabled is bool ? enabled : true;
    } on FormatException {
      return true;
    }
  }
}
