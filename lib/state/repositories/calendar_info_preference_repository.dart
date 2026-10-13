import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 「显示农历 / 显示节假日调休」开关（嘀嗒《02-日历/06-日历显示设置.md》:5-21；
/// specs/125，矩阵 #31 面 ①）。
///
/// 两个布尔位复用 `todo_view_preferences`（`sourceType='CALENDAR_INFO'`、
/// `sourceKey='global'`）与 `view_preference` 出箱通道 ⇒ 不升 `schemaVersion`、
/// 不加列，与 `WEEK_START` 同一套落法。库按 tenant/user 隔离，`global` 即
/// "每用户一份"。
class CalendarInfoPreferenceRepository {
  CalendarInfoPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _sourceType = 'CALENDAR_INFO';
  static const _sourceKey = 'global';

  Expression<bool> _byKey(TodoViewPreferences row) =>
      row.sourceType.equals(_sourceType) & row.sourceKey.equals(_sourceKey);

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  static const _default = CalendarInfoFlags(
    showLunar: false,
    showHolidays: false,
  );

  Future<CalendarInfoFlags> get() async {
    final row = await (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).getSingleOrNull();
    return _decode(row);
  }

  Stream<CalendarInfoFlags> watch() {
    return (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).watchSingleOrNull().map(_decode);
  }

  Future<void> save(CalendarInfoFlags flags) async {
    final now = DateTime.now();
    final valueJson = jsonEncode({
      'showLunar': flags.showLunar,
      'showHolidays': flags.showHolidays,
      // 习惯打卡进日历（specs/129，矩阵 #45 面 ③）。
      'showHabits': flags.showHabits,
    });
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

  CalendarInfoFlags _decode(TodoViewPreference? row) {
    if (row == null) return _default;
    try {
      final raw = jsonDecode(row.valueJson);
      if (raw is! Map<String, dynamic>) return _default;
      return CalendarInfoFlags(
        showLunar: raw['showLunar'] == true,
        showHolidays: raw['showHolidays'] == true,
        showHabits: raw['showHabits'] == true,
      );
    } on FormatException {
      return _default;
    }
  }
}

class CalendarInfoFlags {
  const CalendarInfoFlags({
    required this.showLunar,
    required this.showHolidays,
    this.showHabits = false,
  });

  final bool showLunar;
  final bool showHolidays;

  /// 日历显示习惯打卡点（specs/129，矩阵 #45 面 ③）；旧数据无此键按关处理。
  final bool showHabits;

  @override
  bool operator ==(Object other) =>
      other is CalendarInfoFlags &&
      other.showLunar == showLunar &&
      other.showHolidays == showHolidays &&
      other.showHabits == showHabits;

  @override
  int get hashCode => Object.hash(showLunar, showHolidays, showHabits);
}
