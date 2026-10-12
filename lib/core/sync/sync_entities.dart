/// 同步实体常量：与后端 `TodoSyncServiceImpl.normalizeEntityType` 白名单
/// 保持一致的小写下划线命名（`folder` 例外，见下）。
class SyncEntities {
  static const list = 'list';
  static const taskSection = 'task_section';
  static const task = 'task';
  static const reminder = 'reminder';
  static const reminderDispatchAction = 'reminder_dispatch_action';
  static const repeatRule = 'repeat_rule';
  static const repeatSkip = 'repeat_skip';
  static const repeatOccurrenceAction = 'repeat_occurrence_action';
  static const viewPreference = 'view_preference';
  static const boardPreference = 'board_preference';
  static const tag = 'tag';
  static const taskTag = 'task_tag';
  static const filter = 'filter';
  static const attachment = 'attachment';
  static const template = 'template';

  /// 任务动态由服务端产生，只允许 pull 落本地只读缓存。
  ///
  /// 不得加入 [syncable]，也不能由 Repository 写入 outbox。
  static const activity = 'activity';

  /// 不在后端 `/sync` 白名单内、由 [SyncCoordinator] 路由到普通 REST 的实体。
  static const folder = 'folder';

  /// 走 `/app-api/todo/sync/push` 的实体集合（folder 例外）。
  static const syncable = {
    list,
    taskSection,
    task,
    reminder,
    reminderDispatchAction,
    repeatRule,
    repeatSkip,
    repeatOccurrenceAction,
    viewPreference,
    boardPreference,
    tag,
    taskTag,
    filter,
    template,
  };
}

class SyncOps {
  static const upsert = 'upsert';
  static const delete = 'delete';
}
