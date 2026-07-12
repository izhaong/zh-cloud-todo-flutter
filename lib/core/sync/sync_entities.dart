/// 同步实体常量：与后端 `TodoSyncServiceImpl.normalizeEntityType` 白名单
/// 保持一致的小写下划线命名（`folder` 例外，见下）。
class SyncEntities {
  static const list = 'list';
  static const task = 'task';
  static const reminder = 'reminder';
  static const repeatRule = 'repeat_rule';
  static const repeatSkip = 'repeat_skip';
  static const viewPreference = 'view_preference';
  static const tag = 'tag';
  static const taskTag = 'task_tag';
  static const checklist = 'checklist';
  static const filter = 'filter';

  /// 不在后端 `/sync` 白名单内、由 [SyncCoordinator] 路由到普通 REST 的实体。
  static const folder = 'folder';

  /// 走 `/app-api/todo/sync/push` 的实体集合（folder 例外）。
  static const syncable = {
    list,
    task,
    reminder,
    repeatRule,
    repeatSkip,
    viewPreference,
    tag,
    taskTag,
    filter,
  };
}

class SyncOps {
  static const upsert = 'upsert';
  static const delete = 'delete';
}
