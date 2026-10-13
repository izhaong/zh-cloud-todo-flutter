import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 「在“今天”、“最近7天”中显示」习惯开关（嘀嗒《02-更好地完成习惯.md》:66；
/// specs/130，矩阵 #45 面 ⑤）。
///
/// 面⑤的偏好与面③的日历打卡点（`CALENDAR_INFO.showHabits`）是两个开关：
/// 原文的入口在习惯页管理图标里，作用面是智能清单而不是日历 ⇒ 单独存
/// `HABIT_SMART_LIST/global` 一行（view_preference 出箱通道，零迁移）。
class HabitSmartListPreferenceRepository {
  HabitSmartListPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _sourceType = 'HABIT_SMART_LIST';
  static const _sourceKey = 'global';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Expression<bool> _byKey(TodoViewPreferences row) =>
      row.sourceType.equals(_sourceType) & row.sourceKey.equals(_sourceKey);

  Future<bool> get() async {
    final row = await (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).getSingleOrNull();
    return _decode(row);
  }

  Stream<bool> watch() {
    return (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).watchSingleOrNull().map(_decode);
  }

  Future<void> save(bool visible) async {
    final now = DateTime.now();
    final valueJson = jsonEncode({'showInSmartLists': visible});
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.todoViewPreferences,
      )..where(_byKey)).getSingleOrNull();
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
        )..where(_byKey)).write(companion);
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

  bool _decode(TodoViewPreference? row) {
    if (row == null) return false;
    try {
      final raw = jsonDecode(row.valueJson);
      if (raw is! Map<String, dynamic>) return false;
      return raw['showInSmartLists'] == true;
    } on FormatException {
      return false;
    }
  }
}
