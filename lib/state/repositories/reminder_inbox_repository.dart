import '../../core/api/todo_api.dart';

export '../../core/api/todo_api.dart' show ReminderInboxItem;

/// 提醒收件箱读模型入口。
///
/// 读取仍需请求服务端派发表，但页面只能经由本仓库访问，避免 Widget 直接依赖
/// API 实现。
class ReminderInboxRepository {
  ReminderInboxRepository(this._api);

  final ReminderActionApi _api;

  Future<List<ReminderInboxItem>> list() => _api.inbox();
}
