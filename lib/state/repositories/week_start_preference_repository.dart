import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';
import '../../core/time/week_start.dart';

/// 「星期开始于」偏好（嘀嗒《01-欢迎/03-常见问题.md:134》）。
///
/// 全局单值，复用 `todo_view_preferences`（`sourceType='WEEK_START'`、
/// `sourceKey='global'`）与 `view_preference` 出箱通道 ⇒ 不升 `schemaVersion`、
/// 不加列。库本身已按 tenant/user 隔离，所以 `global` 是"每用户一份"。
class WeekStartPreferenceRepository {
  WeekStartPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const int defaultFirstDay = WeekStart.defaultFirstDay;
  static const _sourceType = 'WEEK_START';
  static const _sourceKey = 'global';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<int> get() async {
    final row = await (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).getSingleOrNull();
    return _decode(row?.valueJson);
  }

  Stream<int> watch() {
    return (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).watchSingleOrNull().map((row) => _decode(row?.valueJson));
  }

  /// 只写嘀嗒给的三档；其余值在碰到数据库之前就拒掉（FR-1、FR-9）。
  Future<void> save(int firstDay) async {
    if (!WeekStart.allowedFirstDays.contains(firstDay)) {
      throw ArgumentError.value(firstDay, 'firstDay', '星期开始于只能是周日、周一或周六');
    }
    final now = DateTime.now();
    final valueJson = jsonEncode({'weekStart': firstDay});
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
        )..where((preference) => preference.id.equals(id))).write(companion);
      }
      await _queue.enqueue(
        entity: SyncEntities.viewPreference,
        op: SyncOps.upsert,
        localId: id,
        serverId: existing?.serverId,
        payload: {
          'sourceType': _sourceType,
          'sourceKey': _sourceKey,
          'viewType': 'GLOBAL',
          'valueJson': valueJson,
        },
      );
    });
  }

  Expression<bool> _byKey(TodoViewPreferences preference) =>
      preference.sourceType.equals(_sourceType) &
      preference.sourceKey.equals(_sourceKey);

  int _decode(String? valueJson) {
    if (valueJson == null) return defaultFirstDay;
    try {
      final raw = jsonDecode(valueJson);
      if (raw is! Map<String, dynamic>) return defaultFirstDay;
      // 本地 save 直接写 `{weekStart}`；sync pull 保留服务端实体包装，
      // 档位落在被字符串化的 `valueJson` 字段里。两种形态必须同样读得出，
      // 否则第二设备会静默退回默认档（specs/035 实测过的同类坑）。
      final nested = raw['valueJson'];
      final nestedValue = nested is String ? jsonDecode(nested) : null;
      final stored = nestedValue is Map<String, dynamic>
          ? nestedValue['weekStart']
          : raw['weekStart'];
      if (stored is! num) return defaultFirstDay;
      final firstDay = stored.toInt();
      return WeekStart.allowedFirstDays.contains(firstDay)
          ? firstDay
          : defaultFirstDay;
    } on FormatException {
      return defaultFirstDay;
    }
  }
}
