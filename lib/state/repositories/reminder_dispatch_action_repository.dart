import 'package:uuid/uuid.dart';

import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// 提醒派发动作的离线写入口。
///
/// 派发记录只存在服务端，因此不复制一张会漂移的本地派发表；动作本身和重试
/// 状态由 Drift `todo_sync_change` 持久化。规则 ID 与派发 ID 不能互换：这里的
/// 每个动作都必须携带服务端派发 ID。
class ReminderDispatchActionRepository {
  ReminderDispatchActionRepository(this._queue, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final SyncChangeQueue _queue;
  final Uuid _uuid;

  Future<String> dismiss({required int reminderDispatchId}) =>
      _enqueue(reminderDispatchId: reminderDispatchId, action: 'dismiss');

  Future<String> complete({required int reminderDispatchId}) =>
      _enqueue(reminderDispatchId: reminderDispatchId, action: 'complete');

  Future<String> startFocus({required int reminderDispatchId}) =>
      _enqueue(reminderDispatchId: reminderDispatchId, action: 'start_focus');

  Future<String> snooze({
    required int reminderDispatchId,
    required int minutes,
  }) {
    if (minutes <= 0) {
      throw ArgumentError.value(minutes, 'minutes', '稍后提醒分钟数必须为正数');
    }
    return _enqueue(
      reminderDispatchId: reminderDispatchId,
      action: 'snooze',
      minutes: minutes,
    );
  }

  Future<String> _enqueue({
    required int reminderDispatchId,
    required String action,
    int? minutes,
  }) async {
    if (reminderDispatchId <= 0) {
      throw ArgumentError.value(
        reminderDispatchId,
        'reminderDispatchId',
        '提醒派发 ID 必须为正数',
      );
    }
    final actionId = _uuid.v4();
    final mutationId = _uuid.v4();
    await _queue.enqueue(
      entity: SyncEntities.reminderDispatchAction,
      op: SyncOps.upsert,
      localId: actionId,
      serverId: reminderDispatchId,
      clientMutationId: mutationId,
      payload: {
        'reminderDispatchId': reminderDispatchId,
        'action': action,
        'minutes': ?minutes,
      },
    );
    return mutationId;
  }
}
