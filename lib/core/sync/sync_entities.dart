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
  static const filter = 'filter';
  static const attachment = 'attachment';
  static const template = 'template';

  /// 任务动态由服务端产生，只允许 pull 落本地只读缓存。
  ///
  /// 不得加入 [syncable]，也不能由 Repository 写入 outbox。
  static const activity = 'activity';

  /// 不在后端 `/sync` 白名单内、由 [SyncCoordinator] 路由到普通 REST 的实体。
  static const folder = 'folder';

  /// 任务-标签关联同样走 REST，不能进 `/sync/push`。
  ///
  /// 后端 `TodoSyncServiceImpl` 对 `ENTITY_TASK_TAG` 直接
  /// `throw exception(TODO_SYNC_INVALID_ARGUMENT)`（注释：「task_tag 关联表不支持
  /// 客户端 push：所有变更走 `/app-api/todo/tag/{task-bind,task-unbind}`」）。
  /// 放进 `/sync/push` 会让**整批**被拒——同批的检查事项、新建任务一起丢。
  static const taskTag = 'task_tag';

  /// 走 `/app-api/todo/sync/push` 的实体集合（folder / task_tag 例外）。
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
    filter,
    template,
  };
}

class SyncOps {
  static const upsert = 'upsert';
  static const delete = 'delete';
}
