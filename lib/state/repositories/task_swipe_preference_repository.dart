import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';
import '../../core/task/task_swipe_preferences.dart';

/// 「滑动操作」自定义配置（嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》`:75`
/// 「还可以在「设置」-「更多设置」-「滑动操作」中，进行自定义配置」）。
///
/// 与「星期开始于」同一套通道：全局单值，复用 `todo_view_preferences`
/// （`sourceType='TASK_SWIPE'`、`sourceKey='global'`）与 `view_preference` 出箱通道
/// ⇒ 不升 `schemaVersion`、不加列。库按 tenant/user 隔离，所以 `global` 是"每用户一份"。
/// 走这条通道而不是 SharedPreferences 的理由就一条：仓里"可跨设备记住的偏好"已经是这个形状，
/// 再造一条本地态会让同一类偏好有两种寿命。
class TaskSwipePreferenceRepository {
  TaskSwipePreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _sourceType = 'TASK_SWIPE';
  static const _sourceKey = 'global';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<TaskSwipePreferences> get() async {
    final row = await (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).getSingleOrNull();
    return _decode(row?.valueJson);
  }

  Stream<TaskSwipePreferences> watch() {
    return (_db.select(
      _db.todoViewPreferences,
    )..where(_byKey)).watchSingleOrNull().map((row) => _decode(row?.valueJson));
  }

  /// 只收"合法且不超过一屏"的配置：重复动作、超过一侧上限的都拒（界面上先禁选，
  /// 这一层再兜住直接调仓储的调用方）。
  Future<void> save(TaskSwipePreferences preferences) async {
    if (!preferences.isValid) {
      throw ArgumentError.value(
        preferences,
        'preferences',
        '滑动动作不能重复，且一侧最多 ${TaskSwipePreferences.maxActionsPerSide} 个',
      );
    }
    final now = DateTime.now();
    final valueJson = jsonEncode(preferences.toJson());
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

  /// 读值。三种形态都要给同一个答案：没写过（null）、本地 save 写的那份、
  /// sync pull 带服务端实体包装的那份（`valueJson` 被再字符串化了一次）。
  /// 少认一种，第二台设备就会静默退回默认档 —— `specs/035` 那面实测过的同类坑。
  TaskSwipePreferences _decode(String? valueJson) {
    if (valueJson == null) return TaskSwipePreferences.defaults;
    try {
      final raw = jsonDecode(valueJson);
      if (raw is! Map<String, dynamic>) return TaskSwipePreferences.defaults;
      final nested = raw['valueJson'];
      final nestedValue = nested is String ? jsonDecode(nested) : null;
      final stored = nestedValue is Map<String, dynamic> ? nestedValue : raw;
      if (stored['swipeLeft'] == null && stored['swipeRight'] == null) {
        return TaskSwipePreferences.defaults;
      }
      return TaskSwipePreferences.fromJson(stored);
    } on FormatException {
      return TaskSwipePreferences.defaults;
    }
  }
}
