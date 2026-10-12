import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 智能清单的三种显示状态（嘀嗒《02-用清单管理任务.md》:45）。
///
/// 放在仓储层而不是 UI：键与解码都归这里，侧栏与管理弹层共用同一份口径。
enum SmartListVisibility {
  /// 「显示」——也是缺键时的默认值。
  show,

  /// 「隐藏」。
  hide,

  /// 「有内容时显示」——内容判定由消费侧用自己的计数口径兑现。
  auto,
}

/// 侧栏「显示标签」偏好（嘀嗒《01-任务/09-如何管理海量任务/04-用标签管理任务.md》:10/:16/:23/:27）。
///
/// 与 `TaskSortPreferenceRepository` 同一套：`todo_view_preferences` 行 + `viewPreference` outbox，
/// ⇒ 跨端同步走既有通道，不新增表、不 bump `schemaVersion`。
/// 不复用那个类是因为它的签名是 `(listId, TaskSort)`，硬塞全局布尔会让类名与签名一起说谎
/// （spec.md 取舍 2）。
/// 「设置 > 功能模块」那三档（嘀嗒《03-四象限/01-如何使用四象限》:24/:33 的「四象限」、
/// 《01-欢迎/03-常见问题》:802 的「番茄专注」、《01-任务/09-如何管理海量任务/07-搜索任务》:12 的「搜索」）。
/// 看板不在其中——《02-看板视图：分类管理任务》:14「看板并不是独立的功能模块，它是清单的一种显示方式」。
enum TodoFeatureModule { quadrant, pomodoro, search }

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

  /// 智能清单三态的键前缀；键名 = `smartList.<SmartList 枚举名>`。
  /// 用 String 而不是 SmartList 类型做参数，仓储层就不必反向依赖 UI 的枚举。
  static const _smartKeyPrefix = 'smartList.';

  /// 显式读三态映射；只含有值的键，缺键 = 默认「显示」。
  Future<Map<String, SmartListVisibility>> getSmartListStates() async =>
      _decodeSmartStates(
        await (_db.select(_db.todoViewPreferences)..where(
              (preference) =>
                  preference.sourceType.equals(sourceType) &
                  preference.sourceKey.equals(sourceKey),
            ))
            .getSingleOrNull(),
      );

  Stream<Map<String, SmartListVisibility>> watchSmartListStates() =>
      (_db.select(_db.todoViewPreferences)..where(
            (preference) =>
                preference.sourceType.equals(sourceType) &
                preference.sourceKey.equals(sourceKey),
          ))
          .watchSingleOrNull()
          .map(_decodeSmartStates);

  /// 嘀嗒《02-用清单管理任务.md》:20「收集箱是不可以被隐藏或删除」⇒
  /// 写成显式守卫，不靠"恰好没有入口"。被拒的写入不留半条状态。
  Future<void> saveSmartListState(
    String smartListName,
    SmartListVisibility state,
  ) {
    if (smartListName == 'inbox' && state != SmartListVisibility.show) {
      throw ArgumentError('收集箱不可隐藏或删除（嘀嗒《02-用清单管理任务》:20）');
    }
    return _write(<String, Object>{
      '$_smartKeyPrefix$smartListName': state.name,
    });
  }

  /// 功能模块三档的键前缀；键名 = `module.<枚举名>`，读法与 `smartList.` 同一套「缺键=默认」。
  static const _moduleKeyPrefix = 'module.';

  /// **默认「开」**：这三档在 develop 上一直是常驻可达的，默认关掉任何一档都会让既有账号
  /// 一夜之间找不到入口，并且要重录黄金基线。
  static const defaultFeatureEnabled = true;

  Future<TodoViewPreference?> _preferenceRow() =>
      (_db.select(_db.todoViewPreferences)..where(
            (preference) =>
                preference.sourceType.equals(sourceType) &
                preference.sourceKey.equals(sourceKey),
          ))
          .getSingleOrNull();

  /// 某一档功能模块是否开启；行不存在、坏 JSON、缺键都回默认「开」。
  Future<bool> getFeature(TodoFeatureModule module) async => _decodeKey(
    await _preferenceRow(),
    _moduleKey(module),
    defaultFeatureEnabled,
  );

  Stream<bool> watchFeature(TodoFeatureModule module) =>
      (_db.select(_db.todoViewPreferences)..where(
            (preference) =>
                preference.sourceType.equals(sourceType) &
                preference.sourceKey.equals(sourceKey),
          ))
          .watchSingleOrNull()
          .map(
            (row) => _decodeKey(row, _moduleKey(module), defaultFeatureEnabled),
          );

  /// 只 patch 这一档：与其它键共用同一行，整块覆盖会把别的档位顶回默认值。
  Future<void> saveFeature({
    required TodoFeatureModule module,
    required bool enabled,
  }) => _write(<String, Object>{_moduleKey(module): enabled});

  static String _moduleKey(TodoFeatureModule module) =>
      '$_moduleKeyPrefix${module.name}';

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

  /// 三态映射：只收带前缀且值可辨认的键；缺键 = 「显示」由消费侧兜底。
  /// 同步拉回来的行可能被服务端实体包一层，[_jsonMap] 已统一拆壳。
  Map<String, SmartListVisibility> _decodeSmartStates(TodoViewPreference? row) {
    final states = <String, SmartListVisibility>{};
    _jsonMap(row).forEach((key, value) {
      if (!key.startsWith(_smartKeyPrefix)) return;
      final name = value is String ? value : null;
      final state = SmartListVisibility.values
          .where((v) => v.name == name)
          .firstOrNull;
      if (state != null) {
        states[key.substring(_smartKeyPrefix.length)] = state;
      }
    });
    return states;
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
            // bool 是既有两键（showTags/showFilters），String 是智能清单三态。
            // 放宽成"留 bool + String"时旧键不受影响；别的类型仍然丢弃。
            if (entry.value is bool || entry.value is String)
              entry.key: entry.value as Object,
        };
      }
    } on FormatException {
      // 坏 JSON ⇒ 当作没有旧值，与排序偏好的处理一致：一个读不懂的偏好不该把侧栏锁死。
    }
    return const {};
  }
}
