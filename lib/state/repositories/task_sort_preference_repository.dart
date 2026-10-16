import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';
import 'task_query_repository.dart';

class TaskSortPreference {
  const TaskSortPreference({
    required this.sort,
    this.direction = TaskSortDirection.newestFirst,
  });

  /// 未存过偏好、旧行缺 `direction` 键、或方向取值不认识时的共同回退值：
  /// 必须等于本参数存在之前唯一的行为（降序），否则升级即静默换序。
  static const fallback = TaskSortPreference(sort: TaskSort.smart);

  final TaskSort sort;
  final TaskSortDirection direction;
}

/// 每个清单独立的任务排序偏好。
///
/// 用户库已按 tenant/user 隔离；在库内再以 `TASK_SORT + listId` 唯一，
/// 让不同清单、离线重启和跨端同步使用同一份偏好实体。
class TaskSortPreferenceRepository {
  TaskSortPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _sourceType = 'TASK_SORT';

  /// 「没有清单上下文」的键（智能清单 / 四象限 / 全部等页面）。
  ///
  /// 收集箱不用常量占位：它的清单 id 本身就是字面量 `'inbox'`，原样作键即可。
  /// `listId == null` 则表示**这个页面不属于任何清单**，与收集箱是两件事 ——
  /// 以前两者都落成 `'inbox'`，于是在「今天」里改排序会连带改掉收集箱的档位（FL #619 后半）。
  static const _noListSourceKey = 'no-list';

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<TaskSortPreference> get(String? listId) async {
    final row =
        await (_db.select(_db.todoViewPreferences)..where(
              (preference) =>
                  preference.sourceType.equals(_sourceType) &
                  preference.sourceKey.equals(_sourceKey(listId)),
            ))
            .getSingleOrNull();
    return _decode(row?.valueJson);
  }

  Stream<TaskSortPreference> watch(String? listId) {
    return (_db.select(_db.todoViewPreferences)..where(
          (preference) =>
              preference.sourceType.equals(_sourceType) &
              preference.sourceKey.equals(_sourceKey(listId)),
        ))
        .watchSingleOrNull()
        .map((row) => _decode(row?.valueJson));
  }

  Future<void> save(
    String? listId,
    TaskSort sort, [
    TaskSortDirection direction = TaskSortDirection.newestFirst,
  ]) async {
    final sourceKey = _sourceKey(listId);
    final now = DateTime.now();
    final valueJson = jsonEncode({
      'sort': sort.name,
      'direction': direction.name,
    });
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

  /// `null` / 空串 = 没有清单上下文（智能清单等）⇒ 独立一把键；
  /// 其余（含真实清单 `'inbox'`）按清单 id 原样作键。
  String _sourceKey(String? listId) =>
      listId == null || listId.isEmpty ? _noListSourceKey : listId;

  TaskSortPreference _decode(String? valueJson) {
    if (valueJson == null) return TaskSortPreference.fallback;
    try {
      final raw = jsonDecode(valueJson);
      if (raw is! Map<String, dynamic>) return TaskSortPreference.fallback;
      // 本地 save 直接存储 `{sort, direction}`；sync pull 则保留服务端实体包装，
      // 排序实际位于其字符串化的 `valueJson` 字段内。两种格式必须同样可读，
      // 否则第二设备会静默退回智能排序。
      final nested = raw['valueJson'];
      final nestedValue = nested is String ? jsonDecode(nested) : null;
      final value = nestedValue is Map<String, dynamic>
          ? nestedValue['sort']
          : raw['sort'];
      // 方向单独取：嵌套包装里也要能取到，且**取值认不出来时只回退方向**，
      // 不能连档位一起退回智能排序（两条判据在上面的用例里分开钉着）。
      final directionSource = nestedValue is Map<String, dynamic>
          ? nestedValue
          : raw;
      final sort = TaskSort.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => TaskSort.smart,
      );
      final direction = TaskSortDirection.values.firstWhere(
        (candidate) => candidate.name == directionSource['direction'],
        orElse: () => TaskSortDirection.newestFirst,
      );
      return TaskSortPreference(sort: sort, direction: direction);
    } on FormatException {
      return TaskSortPreference.fallback;
    }
  }
}
