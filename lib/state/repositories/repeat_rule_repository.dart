import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 重复规则与跳过记录的本地真相源。
///
/// 规则和单次跳过均在一个 Drift transaction 内落库并写入 outbox；UI 只能
/// 通过本仓库写入，避免出现“本地一半、直连接口一半”的状态分裂。
class RepeatRuleRepository {
  RepeatRuleRepository(this._db, this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<TodoRepeatRule> save({
    required String taskId,
    required String frequency,
    int intervalValue = 1,
    Iterable<int>? weekdays,
    int? monthDay,
    required DateTime startAt,
    DateTime? untilAt,
    int? countLimit,
    String repeatMode = 'ON_DUE',
    Iterable<DateTime>? selectedDates,
    String? timeZone,
    bool enabled = true,
  }) async {
    final normalizedFrequency = frequency.trim().toUpperCase();
    final normalizedMode = repeatMode.trim().toUpperCase();
    final normalizedSelectedDates = _normalizeSelectedDates(selectedDates);
    final normalizedWeekdays = _validate(
      frequency: normalizedFrequency,
      intervalValue: intervalValue,
      weekdays: weekdays,
      monthDay: monthDay,
      startAt: startAt,
      untilAt: untilAt,
      countLimit: countLimit,
      repeatMode: normalizedMode,
      selectedDates: normalizedSelectedDates,
    );
    final effectiveMonthDay = normalizedFrequency == 'MONTHLY'
        ? (monthDay ?? startAt.day)
        : monthDay;
    final existing = await (_db.select(
      _db.todoRepeatRules,
    )..where((rule) => rule.taskId.equals(taskId))).getSingleOrNull();
    final now = DateTime.now();
    final mutationId = _uuid.v4();
    late TodoRepeatRule row;

    await _db.transaction(() async {
      final companion = TodoRepeatRulesCompanion(
        id: Value(existing?.id ?? _uuid.v4()),
        serverId: Value(existing?.serverId),
        taskId: Value(taskId),
        freq: Value(normalizedFrequency),
        interval: Value(intervalValue),
        byDay: Value(_weekdayText(normalizedWeekdays)),
        monthDay: Value(effectiveMonthDay),
        startAt: Value(startAt),
        until: Value(untilAt),
        countLimit: Value(countLimit),
        enabled: Value(enabled),
        repeatMode: Value(normalizedMode),
        timeZone: Value(timeZone),
        selectedDatesJson: Value(
          normalizedSelectedDates.isEmpty
              ? null
              : jsonEncode(normalizedSelectedDates.map(_dateText).toList()),
        ),
        updatedAt: Value(now),
        createdAt: Value(existing?.createdAt ?? now),
      );
      if (existing == null) {
        await _db.into(_db.todoRepeatRules).insert(companion);
      } else {
        await (_db.update(
          _db.todoRepeatRules,
        )..where((rule) => rule.id.equals(existing.id))).write(companion);
      }
      row =
          await (_db.select(_db.todoRepeatRules)..where(
                (rule) => rule.id.equals(existing?.id ?? companion.id.value),
              ))
              .getSingle();
      await _queue.enqueue(
        entity: SyncEntities.repeatRule,
        op: SyncOps.upsert,
        localId: row.id,
        serverId: row.serverId,
        clientMutationId: mutationId,
        payload: _rulePayload(row),
      );
    });
    return row;
  }

  Future<TodoRepeatSkip> skip({
    required String repeatRuleId,
    required String taskId,
    required DateTime occurrenceAt,
  }) async {
    final rule = await (_db.select(
      _db.todoRepeatRules,
    )..where((entry) => entry.id.equals(repeatRuleId))).getSingleOrNull();
    if (rule == null || rule.taskId != taskId) {
      throw ArgumentError.value(repeatRuleId, 'repeatRuleId', '重复规则不属于任务');
    }
    final existing =
        await (_db.select(_db.todoRepeatSkips)
              ..where((entry) => entry.repeatRuleId.equals(repeatRuleId))
              ..where((entry) => entry.occurrenceDate.equals(occurrenceAt)))
            .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now();
    final id = _uuid.v4();
    late TodoRepeatSkip row;
    await _db.transaction(() async {
      await _db
          .into(_db.todoRepeatSkips)
          .insert(
            TodoRepeatSkipsCompanion.insert(
              id: id,
              repeatRuleId: repeatRuleId,
              taskId: taskId,
              occurrenceDate: occurrenceAt,
              updatedAt: now,
              createdAt: now,
            ),
          );
      row = await (_db.select(
        _db.todoRepeatSkips,
      )..where((entry) => entry.id.equals(id))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.repeatSkip,
        op: SyncOps.upsert,
        localId: row.id,
        serverId: row.serverId,
        payload: {
          'id': row.id,
          'serverId': row.serverId,
          'repeatRuleId': row.repeatRuleId,
          'taskId': row.taskId,
          'occurrenceAt': row.occurrenceDate.toIso8601String(),
        },
      );
    });
    return row;
  }

  /// 撤回本地跳过，并以持久化 action 交给同步层补做对应 occurrence。
  ///
  /// 与 [skip] 一样，删除本地 skip 和写入 outbox 在同一个 Drift transaction
  /// 内完成。服务端收到 action 后校验所属关系、撤销 skip，并物化真实任务；
  /// 因此 UI 不会直接调用 occurrence REST API。
  Future<void> catchup({
    required String repeatRuleId,
    required String taskId,
    required DateTime occurrenceAt,
  }) async {
    final rule = await (_db.select(
      _db.todoRepeatRules,
    )..where((entry) => entry.id.equals(repeatRuleId))).getSingleOrNull();
    if (rule == null || rule.taskId != taskId) {
      throw ArgumentError.value(repeatRuleId, 'repeatRuleId', '重复规则不属于任务');
    }
    final existing =
        await (_db.select(_db.todoRepeatSkips)
              ..where((entry) => entry.repeatRuleId.equals(repeatRuleId))
              ..where((entry) => entry.taskId.equals(taskId))
              ..where((entry) => entry.occurrenceDate.equals(occurrenceAt)))
            .getSingleOrNull();
    if (existing == null) {
      throw ArgumentError.value(occurrenceAt, 'occurrenceAt', '该次重复尚未跳过');
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.todoRepeatSkips,
      )..where((entry) => entry.id.equals(existing.id))).go();
      // 尚未上推的“跳过→补做”在本机折叠为无操作。此时服务端不存在
      // skip，发送 CATCHUP 反而会制造 occurrence-not-found 失败。
      if (existing.serverId == null) {
        final queuedSkipChanges =
            await (_db.select(_db.todoSyncChanges)
                  ..where(
                    (change) => change.entity.equals(SyncEntities.repeatSkip),
                  )
                  ..where((change) => change.entityLocalId.equals(existing.id))
                  ..where((change) => change.status.equals('queued')))
                .get();
        if (queuedSkipChanges.isNotEmpty) {
          await (_db.delete(_db.todoSyncChanges)
                ..where(
                  (change) => change.entity.equals(SyncEntities.repeatSkip),
                )
                ..where((change) => change.entityLocalId.equals(existing.id))
                ..where((change) => change.status.equals('queued')))
              .go();
          return;
        }
      }
      await _queue.enqueue(
        entity: SyncEntities.repeatOccurrenceAction,
        op: SyncOps.upsert,
        localId: _uuid.v4(),
        clientMutationId: _uuid.v4(),
        payload: {
          'action': 'CATCHUP',
          'taskId': taskId,
          'repeatRuleId': repeatRuleId,
          'occurrenceAt': occurrenceAt.toIso8601String(),
        },
      );
    });
  }

  List<int>? _validate({
    required String frequency,
    required int intervalValue,
    required Iterable<int>? weekdays,
    required int? monthDay,
    required DateTime startAt,
    required DateTime? untilAt,
    required int? countLimit,
    required String repeatMode,
    required List<DateTime> selectedDates,
  }) {
    const frequencies = {
      'DAILY',
      'WEEKLY',
      'MONTHLY',
      'YEARLY',
      'WEEKDAY',
      'CUSTOM',
    };
    if (!frequencies.contains(frequency)) {
      throw ArgumentError.value(frequency, 'frequency', '不支持的重复频率');
    }
    if (intervalValue < 1) {
      throw ArgumentError.value(intervalValue, 'intervalValue', '间隔必须为正整数');
    }
    if (untilAt != null && untilAt.isBefore(startAt)) {
      throw ArgumentError.value(untilAt, 'untilAt', '结束时间不能早于开始时间');
    }
    if (countLimit != null && countLimit < 1) {
      throw ArgumentError.value(countLimit, 'countLimit', '次数上限必须为正整数');
    }
    const selectedDatesMode = 'ON_SELECTED_DATES';
    if (repeatMode != 'ON_DUE' &&
        repeatMode != 'ON_COMPLETE' &&
        repeatMode != selectedDatesMode) {
      throw ArgumentError.value(repeatMode, 'repeatMode', '不支持的重复模式');
    }
    if (monthDay != null && (monthDay < 1 || monthDay > 31)) {
      throw ArgumentError.value(monthDay, 'monthDay', '每月日期必须在 1 到 31 之间');
    }
    final normalized = (weekdays ?? const <int>[]).toSet().toList()..sort();
    if (normalized.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays', '星期必须在 1 到 7 之间');
    }
    if (repeatMode == selectedDatesMode) {
      final startDate = DateTime(startAt.year, startAt.month, startAt.day);
      if (frequency != 'CUSTOM' ||
          selectedDates.isEmpty ||
          normalized.isNotEmpty ||
          untilAt != null ||
          countLimit != null ||
          selectedDates.any((date) => date.isBefore(startDate))) {
        throw ArgumentError.value(
          selectedDates,
          'selectedDates',
          '自选日期重复必须使用 CUSTOM，且日期不能为空、不得早于开始日期或与其他结束条件并用',
        );
      }
      return null;
    }
    if (selectedDates.isNotEmpty) {
      throw ArgumentError.value(
        selectedDates,
        'selectedDates',
        '仅 ON_SELECTED_DATES 模式可设置自选日期',
      );
    }
    if (frequency == 'WEEKDAY') return const [1, 2, 3, 4, 5];
    if (frequency == 'CUSTOM' && normalized.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', '自定义重复必须指定星期');
    }
    return normalized.isEmpty ? null : normalized;
  }

  String? _weekdayText(List<int>? weekdays) => weekdays?.join(',');

  List<DateTime> _normalizeSelectedDates(Iterable<DateTime>? dates) {
    final byDate = <String, DateTime>{};
    for (final value in dates ?? const <DateTime>[]) {
      final date = DateTime(value.year, value.month, value.day);
      byDate[_dateText(date)] = date;
    }
    final normalized = byDate.values.toList()
      ..sort((left, right) => left.compareTo(right));
    return normalized;
  }

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  List<String>? _selectedDatePayload(TodoRepeatRule row) {
    final encoded = row.selectedDatesJson;
    if (encoded == null || encoded.isEmpty) return null;
    return (jsonDecode(encoded) as List<dynamic>).cast<String>();
  }

  Map<String, dynamic> _rulePayload(TodoRepeatRule row) => {
    'id': row.id,
    'serverId': row.serverId,
    'taskId': row.taskId,
    'frequency': row.freq.toLowerCase(),
    'intervalValue': row.interval,
    'weekdays': row.byDay,
    'monthDay': row.monthDay,
    'startAt': row.startAt?.toIso8601String(),
    'untilAt': row.until?.toIso8601String(),
    'countLimit': row.countLimit,
    'enabled': row.enabled,
    'repeatMode': row.repeatMode,
    'timeZone': row.timeZone,
    'selectedDates': _selectedDatePayload(row),
  };
}
