import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 看板列宽三档（嘀嗒《02-看板视图：分类管理任务》FAQ `:209`
/// 「有小、中、大三种尺寸供你选择」；specs/119，矩阵 #15 面 ⑧）。
enum BoardColumnWidth {
  small(200),
  medium(260),
  large(320);

  const BoardColumnWidth(this.columnWidth);
  final double columnWidth;

  static BoardColumnWidth fromWire(String? wire) => switch (wire) {
    'small' => BoardColumnWidth.small,
    'large' => BoardColumnWidth.large,
    _ => BoardColumnWidth.medium,
  };

  String get wire => name;
}

class BoardViewPreference {
  const BoardViewPreference({
    this.orderedColumnIds = defaultColumnIds,
    this.collapsedColumnIds = const {},
    this.columnWidth = BoardColumnWidth.medium,
    this.showColumnInput = false,
  });

  static const defaultColumnIds = ['todo', 'doing', 'urgent', 'archive'];

  final List<String> orderedColumnIds;
  final Set<String> collapsedColumnIds;

  /// 「显示设置」里的列宽档（specs/119）。
  final BoardColumnWidth columnWidth;

  /// 「显示输入框」：列头下常驻快速添加输入框（FAQ `:213`）。
  final bool showColumnInput;
}

/// B4 看板偏好本地优先写链路。
class BoardPreferenceRepository {
  BoardPreferenceRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<BoardViewPreference> get(String listId) async {
    final row =
        await (_db.select(_db.todoBoardPreferences)
              ..where((preference) => preference.listId.equals(listId)))
            .getSingleOrNull();
    return _decodeLayout(row?.columnsJson);
  }

  Stream<BoardViewPreference> watch(String listId) {
    return (_db.select(_db.todoBoardPreferences)
          ..where((preference) => preference.listId.equals(listId)))
        .watchSingleOrNull()
        .map((row) => _decodeLayout(row?.columnsJson));
  }

  Future<void> saveLayout({
    required String listId,
    required List<String> orderedColumnIds,
    required Set<String> collapsedColumnIds,
  }) async {
    final existing =
        await (_db.select(_db.todoBoardPreferences)
              ..where((preference) => preference.listId.equals(listId)))
            .getSingleOrNull();
    final order = _normalizeOrder(orderedColumnIds);
    final collapsed =
        collapsedColumnIds
            .where(BoardViewPreference.defaultColumnIds.contains)
            .toSet()
            .toList()
          ..sort();
    // 列序保存不得冲掉「显示设置」：读现值整体写回（specs/119）。
    // 「显示设置」的唯一定期写入口是 [saveDisplaySettings]。
    final current = _decodeLayout(existing?.columnsJson);
    await save(
      listId: listId,
      groupDimension: existing?.groupDimension ?? 'PRIORITY',
      columnsJson: jsonEncode({
        'order': order,
        'collapsed': collapsed,
        'columnWidth': current.columnWidth.wire,
        'showColumnInput': current.showColumnInput,
      }),
    );
  }

  /// 「显示设置」只改列宽与「显示输入框」，不动列序/折叠
  /// （嘀嗒 FAQ `:209`/`:213`；specs/119）。
  Future<void> saveDisplaySettings({
    required String listId,
    required BoardColumnWidth columnWidth,
    required bool showColumnInput,
  }) async {
    final current = await get(listId);
    final existing =
        await (_db.select(_db.todoBoardPreferences)
              ..where((preference) => preference.listId.equals(listId)))
            .getSingleOrNull();
    await save(
      listId: listId,
      groupDimension: existing?.groupDimension ?? 'PRIORITY',
      columnsJson: jsonEncode({
        'order': current.orderedColumnIds,
        'collapsed': current.collapsedColumnIds.toList()..sort(),
        'columnWidth': columnWidth.wire,
        'showColumnInput': showColumnInput,
      }),
    );
  }

  Future<void> save({
    required String listId,
    required String groupDimension,
    String? columnsJson,
  }) async {
    if (groupDimension.trim().isEmpty) {
      throw ArgumentError.value(groupDimension, 'groupDimension', '分组维度不能为空');
    }
    await _db.transaction(
      () => _save(
        listId: listId,
        groupDimension: groupDimension,
        columnsJson: columnsJson,
      ),
    );
  }

  /// 重新应用当前清单最近一次失败的偏好变更。
  ///
  /// 原变更保留为 `resolved`，新的 upsert 通过既有 outbox 正常重试，避免
  /// Widget 直接解析 payload 或修改同步队列。
  Future<bool> recoverLatestFailed({required String listId}) async {
    return _db.transaction(() async {
      final list = await (_db.select(
        _db.todoLists,
      )..where((row) => row.id.equals(listId))).getSingleOrNull();
      if (list == null) return false;
      final changes =
          await (_db.select(_db.todoSyncChanges)
                ..where(
                  (row) =>
                      row.entity.equals(SyncEntities.boardPreference) &
                      row.status.equals('failed'),
                )
                ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
              .get();
      for (final change in changes) {
        final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
        final payloadListId = payload['listId']?.toString();
        if (payloadListId != listId &&
            payloadListId != list.serverId?.toString()) {
          continue;
        }
        final groupDimension = payload['groupDimension']?.toString();
        if (groupDimension == null || groupDimension.trim().isEmpty) {
          return false;
        }
        await _save(
          listId: listId,
          groupDimension: groupDimension,
          columnsJson: payload['columnsJson']?.toString(),
        );
        await (_db.update(_db.todoSyncChanges)
              ..where((row) => row.id.equals(change.id)))
            .write(const TodoSyncChangesCompanion(status: Value('resolved')));
        return true;
      }
      return false;
    });
  }

  /// 当前清单是否存在可恢复的失败偏好变更。
  ///
  /// 仅用于决定是否显示恢复入口；具体恢复仍由 [recoverLatestFailed] 统一完成。
  Future<bool> hasRecoverableFailed({required String listId}) async {
    final list = await (_db.select(
      _db.todoLists,
    )..where((row) => row.id.equals(listId))).getSingleOrNull();
    if (list == null) return false;
    final changes =
        await (_db.select(_db.todoSyncChanges)
              ..where(
                (row) =>
                    row.entity.equals(SyncEntities.boardPreference) &
                    row.status.equals('failed'),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
            .get();
    for (final change in changes) {
      try {
        final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
        final payloadListId = payload['listId']?.toString();
        final groupDimension = payload['groupDimension']?.toString();
        if ((payloadListId == listId ||
                payloadListId == list.serverId?.toString()) &&
            groupDimension != null &&
            groupDimension.trim().isNotEmpty) {
          return true;
        }
      } on FormatException {
        // 忽略损坏的历史 outbox 记录，继续检查更早的可恢复变更。
      } on TypeError {
        // payload 不是对象时也不应阻断看板加载。
      }
    }
    return false;
  }

  Future<void> _save({
    required String listId,
    required String groupDimension,
    required String? columnsJson,
  }) async {
    final list = await (_db.select(
      _db.todoLists,
    )..where((row) => row.id.equals(listId))).getSingleOrNull();
    if (list == null) throw StateError('清单不存在');
    final existing = await (_db.select(
      _db.todoBoardPreferences,
    )..where((row) => row.listId.equals(listId))).getSingleOrNull();
    final now = DateTime.now();
    final companion = TodoBoardPreferencesCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      serverId: Value(existing?.serverId),
      listId: Value(listId),
      groupDimension: Value(groupDimension),
      columnsJson: Value(columnsJson),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );
    if (existing == null) {
      await _db.into(_db.todoBoardPreferences).insert(companion);
    } else {
      await (_db.update(
        _db.todoBoardPreferences,
      )..where((row) => row.id.equals(existing.id))).write(companion);
    }
    final saved = await (_db.select(
      _db.todoBoardPreferences,
    )..where((row) => row.listId.equals(listId))).getSingle();
    await _queue.enqueue(
      entity: SyncEntities.boardPreference,
      op: SyncOps.upsert,
      localId: saved.id,
      serverId: saved.serverId,
      payload: {
        'listId': list.serverId ?? listId,
        'groupDimension': saved.groupDimension,
        'columnsJson': saved.columnsJson,
      },
    );
  }

  BoardViewPreference _decodeLayout(String? columnsJson) {
    if (columnsJson == null || columnsJson.trim().isEmpty) {
      return const BoardViewPreference();
    }
    try {
      final decoded = jsonDecode(columnsJson);
      if (decoded is Map<String, dynamic>) {
        final order = _normalizeOrder(
          (decoded['order'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(),
        );
        final collapsed = (decoded['collapsed'] as List? ?? const [])
            .map((value) => value.toString())
            .where(BoardViewPreference.defaultColumnIds.contains)
            .toSet();
        return BoardViewPreference(
          orderedColumnIds: order,
          collapsedColumnIds: collapsed,
          columnWidth: BoardColumnWidth.fromWire(
            decoded['columnWidth']?.toString(),
          ),
          showColumnInput: decoded['showColumnInput'] == true,
        );
      }
      if (decoded is List) {
        return BoardViewPreference(
          orderedColumnIds: _normalizeOrder(
            decoded.map((value) => _legacyColumnId(value.toString())).toList(),
          ),
        );
      }
    } on FormatException {
      // 损坏的历史偏好安全降级为默认布局，不阻塞看板任务。
    } on TypeError {
      // 非对象/非数组或字段类型异常同样降级。
    }
    return const BoardViewPreference();
  }

  List<String> _normalizeOrder(List<String> values) {
    final order = <String>[];
    for (final value in values) {
      if (BoardViewPreference.defaultColumnIds.contains(value) &&
          !order.contains(value)) {
        order.add(value);
      }
    }
    for (final value in BoardViewPreference.defaultColumnIds) {
      if (!order.contains(value)) order.add(value);
    }
    return order;
  }

  String _legacyColumnId(String value) {
    return switch (value.toUpperCase()) {
      'TODO' => 'todo',
      'DOING' => 'doing',
      'URGENT' => 'urgent',
      'DONE' || 'ARCHIVE' => 'archive',
      _ => value,
    };
  }
}
