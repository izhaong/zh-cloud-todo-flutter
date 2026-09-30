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

  /// 「过滤器」也默认「显示」：侧栏那行入口在 develop 上一直是常驻的，
  /// 默认改成隐藏等于让既有账号一夜之间找不到筛选器（FL Issue #336）。
  static const defaultShowFilters = true;

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

  /// 「过滤器」那一档的读法，与上面两个方法同一行、同一套三态口径。
  Future<bool> getFilters() async => _decodeKey(
    await (_db.select(_db.todoViewPreferences)..where(
          (preference) =>
              preference.sourceType.equals(sourceType) &
              preference.sourceKey.equals(sourceKey),
        ))
        .getSingleOrNull(),
    _keyShowFilters,
    defaultShowFilters,
  );

  Stream<bool> watchFilters() =>
      (_db.select(_db.todoViewPreferences)..where(
            (preference) =>
                preference.sourceType.equals(sourceType) &
                preference.sourceKey.equals(sourceKey),
          ))
          .watchSingleOrNull()
          .map((row) => _decodeKey(row, _keyShowFilters, defaultShowFilters));

  /// 与排序偏好同一处写法：写行与入队在一个事务里，失败时不留"本地改了、没同步"的半条状态。
  Future<void> save({required bool showTags}) =>
      _write(<String, Object>{_keyShowTags: showTags});

  /// 嘀嗒《过滤器》:33「找到「过滤器」设置为「显示」即可」⇒ 落库走这同一条通道。
  Future<void> saveFilters({required bool showFilters}) =>
      _write(<String, Object>{_keyShowFilters: showFilters});

  /// 两个开关共用同一行偏好 ⇒ 每个写方法只 patch 自己那个键。
  /// 原先那种 `jsonEncode({'showTags': …})` 整块覆盖的写法，在加第二个键之后就是缺陷：
  /// 用户改「过滤器」会被顺手把「标签」顶回默认值。
  Future<void> _write(Map<String, Object> patch) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todoViewPreferences)..where(
                (preference) =>
                    preference.sourceType.equals(sourceType) &
                    preference.sourceKey.equals(sourceKey),
              ))
              .getSingleOrNull();
      final valueJson = jsonEncode(<String, Object>{
        ..._jsonMap(existing),
        ...patch,
      });
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

  static const _keyShowTags = 'showTags';
  static const _keyShowFilters = 'showFilters';

  bool _decode(TodoViewPreference? row) =>
      _decodeKey(row, _keyShowTags, defaultShowTags);

  /// 读某一档；行不存在、坏 JSON、或这一键缺失都回各自的默认值（都是「显示」）。
  bool _decodeKey(TodoViewPreference? row, String key, bool fallback) {
    final map = _jsonMap(row);
    if (!map.containsKey(key)) return fallback;
    return map[key] == true;
  }

  /// 旧行的键值。写之前先取这份，是为了 patch 而不是覆盖（见 [_write]）。
  Map<String, Object> _jsonMap(TodoViewPreference? row) {
    final raw = row?.valueJson;
    if (raw == null) return const {};
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
      if (map is Map<String, dynamic>) {
        return <String, Object>{
          for (final entry in map.entries)
            if (entry.value is bool) entry.key: entry.value as bool,
        };
      }
    } on FormatException {
      // 坏 JSON ⇒ 当作没有旧值，与排序偏好的处理一致：一个读不懂的偏好不该把侧栏锁死。
    }
    return const {};
  }
}
