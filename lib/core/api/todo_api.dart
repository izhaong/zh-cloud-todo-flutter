/// 任务 / 清单 / 文件夹 / 标签 的直连 REST 助手（`/app-api/todo/**` 前缀由
/// [ApiClient] 自动补全，传参使用无前缀路径如 `/task/complete`）。
///
/// 以下端点**不在** `/app-api/todo/sync` 白名单内（checklist / complete /
/// reorder / folder / tag-task-bind / nlp），故直接调用 REST；其余 9 个同步实体
/// 仍走各 Repository 的 drift + outbox 路径，不再这里重复。
///
/// 统一响应信封 `{code, msg, data}`：`code != 0` 视为业务错误（与
/// [SyncApi] / [ApiClient] 一致）。
import 'package:dio/dio.dart';

import 'api_client.dart';

Map<String, dynamic> _unwrapBody(Map<String, dynamic>? body) {
  if (body == null) return const {};
  if (body.containsKey('code')) {
    final code = body['code'];
    if (code != 0) {
      throw DioException(
        requestOptions: RequestOptions(path: '/app-api/todo'),
        error: body['msg'] ?? '请求失败',
      );
    }
    return (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  }
  return body;
}

/// 任务动作：完成 / 取消完成 / 重排顺序（直接 REST）。
class TaskRestApi {
  TaskRestApi(this._client);

  final ApiClient _client;

  /// `POST /task/complete`
  Future<void> complete(int serverId) =>
      _client.post('/task/complete', data: {'id': serverId});

  /// `POST /task/uncomplete`
  Future<void> uncomplete(int serverId) =>
      _client.post('/task/uncomplete', data: {'id': serverId});

  /// `PUT /task/reorder` — 后端按 [orderedServerId] 重排任务顺序。
  Future<void> reorder(List<int> orderedServerId) =>
      _client.put('/task/reorder', data: {'orderedTaskIds': orderedServerId});
}

/// 单个检查事项。
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    this.taskId,
    required this.title,
    this.completed = false,
    this.sortOrder = 0,
  });

  final int id;
  final String? taskId;
  final String title;
  final bool completed;
  final int sortOrder;
}

/// 任务检查事项（checklist），直接 REST（不走 outbox 协议）。
class ChecklistApi {
  ChecklistApi(this._client);

  final ApiClient _client;

  ChecklistItem _fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        taskId: j['taskId']?.toString(),
        title: j['title']?.toString() ?? '',
        completed: j['completed'] == true,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );

  /// `GET /task/checklist?taskId=...`
  Future<List<ChecklistItem>> list(String taskId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/task/checklist',
      query: {'taskId': taskId},
    );
    final data = _unwrapBody(resp.data);
    final raw = (data['list'] as List?) ?? (data['items'] as List?) ?? const [];
    return raw
        .map((e) => _fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// `POST /task/checklist/create`
  Future<int> create({
    required String taskId,
    required String title,
    int sortOrder = 0,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/task/checklist/create',
      data: {'taskId': taskId, 'title': title, 'sortOrder': sortOrder},
    );
    final data = _unwrapBody(resp.data);
    return (data['id'] as num?)?.toInt() ?? 0;
  }

  /// `PUT /task/checklist/update`
  Future<void> update(
    int checklistId, {
    String? title,
    bool? completed,
    int? sortOrder,
  }) =>
      _client.put('/task/checklist/update', data: {
        'id': checklistId,
        if (title != null) 'title': title,
        if (completed != null) 'completed': completed,
        if (sortOrder != null) 'sortOrder': sortOrder,
      });

  /// `POST /task/checklist/delete`
  Future<void> delete(int checklistId) =>
      _client.post('/task/checklist/delete', data: {'id': checklistId});
}

/// 文件夹 / 清单组织 REST（folder 不在 sync 白名单，走普通 REST）。
/// 本地仍由 FolderRepository 的 drift + outbox 驱动，本类提供外部主动调用
/// 的 DELETE / move-list 能力。
class FolderApi {
  FolderApi(this._client);

  final ApiClient _client;

  /// `POST /folder/delete`
  Future<void> deleteFolder(int serverId) =>
      _client.post('/folder/delete', data: {'id': serverId});

  /// `POST /folder/move-list` — 把 [listServerId] 挪到 [folderServerId] 下。
  Future<void> moveList({
    required int listServerId,
    required int folderServerId,
  }) =>
      _client.post('/folder/move-list', data: {
        'listId': listServerId,
        'folderId': folderServerId,
      });
}

/// NLP 自然语言日期解析（`POST /nlp/parse`）。
class NlpApi {
  NlpApi(this._client);

  final ApiClient _client;

  /// 返回解析出的截止时间；无法解析时返回 null。
  Future<DateTime?> parseDue(Iterable<String> texts) async {
    for (final text in texts.where((t) => t.trim().isNotEmpty)) {
      final resp = await _client.post<Map<String, dynamic>>(
        '/nlp/parse',
        data: {'text': text},
      );
      final data = _unwrapBody(resp.data);
      final dueRaw = data['dueDate'];
      if (dueRaw is String && dueRaw.isNotEmpty) {
        final parsed = DateTime.tryParse(dueRaw);
        if (parsed != null) return parsed;
      }
      if (dueRaw is num) {
        // 兼容后端返回 Unix 秒。
        return DateTime.fromMillisecondsSinceEpoch(dueRaw.toInt() * 1000);
      }
    }
    return null;
  }
}

/// 标签 - 任务绑定（直接 REST；本地同步写仍由 TagRepository 负责 offline 安全）。
class TagApi {
  TagApi(this._client);

  final ApiClient _client;

  /// `POST /tag/task-bind`
  Future<void> taskBind({
    required String taskId,
    required int tagServerId,
  }) =>
      _client.post('/tag/task-bind', data: {
        'taskId': taskId,
        'tagId': tagServerId,
      });

  /// `DELETE /tag/task-unbind`
  Future<void> taskUnbind({
    required String taskId,
    required int tagServerId,
  }) =>
      _client.delete('/tag/task-unbind', data: {
        'taskId': taskId,
        'tagId': tagServerId,
      });
}

/// 直连 REST helper 容器：一次性拿到所有子 helper，便于页面注入。
class TodoRestApi {
  TodoRestApi(ApiClient client)
      : task = TaskRestApi(client),
        checklist = ChecklistApi(client),
        folder = FolderApi(client),
        nlp = NlpApi(client),
        tag = TagApi(client),
        reminder = ReminderActionApi(client),
        repeatOccurrence = RepeatOccurrenceApi(client);

  final TaskRestApi task;
  final ChecklistApi checklist;
  final FolderApi folder;
  final NlpApi nlp;
  final TagApi tag;
  final ReminderActionApi reminder;
  final RepeatOccurrenceApi repeatOccurrence;
}

/// 提醒动作（`/reminder-action/**`）直达 REST：收件箱 / 完成 / 忽略 / 延后；不走
/// sync 协议，由页面与通知 service 直接调用。
class ReminderActionApi {
  ReminderActionApi(this._client);

  final ApiClient _client;

  /// 把后端返回的时间字段（ISO 字符串 或 Unix 毫秒）解析为本地 [DateTime]。
  static DateTime parseTime(Object? v) {
    if (v is String && v.isNotEmpty) {
      final p = DateTime.tryParse(v);
      if (p != null) return p;
    }
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DateTime.now();
  }

  static ReminderInboxItem _item(Map<String, dynamic> j) => ReminderInboxItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        taskId: (j['taskId'] as num?)?.toInt() ?? 0,
        taskTitle: (j['taskTitle'] ?? j['title'])?.toString() ?? '',
        remindAt: parseTime(j['remindAt'] ?? j['fireAt']),
        status: j['status']?.toString() ?? 'PENDING',
      );

  /// 把非标准信封（纯数组 / `{data:{list}}` / `{data:[…]}` 等）归一化为提醒列表。
  static List<ReminderInboxItem> normalize(Object? data) {
    List raw;
    if (data is List) {
      raw = data;
    } else if (data is Map && data['data'] != null) {
      final d = data['data'];
      if (d is List) {
        raw = d;
      } else if (d is Map) {
        raw = (d['list'] as List?) ?? (d['items'] as List?) ?? const [];
      } else {
        raw = const [];
      }
    } else if (data is Map) {
      raw = (data['list'] as List?) ?? (data['items'] as List?) ?? const [];
    } else {
      raw = const [];
    }
    return raw.map((e) => _item(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// `GET /reminder-action/inbox` — 拉取当前用户的待处理提醒。
  ///
  /// 兼容两种响应形态：
  /// 1. `{code, msg, data: [...] 或 {list:[…]}}`（统一信封）
  /// 2. 纯数组 `[…]` / `{list:[…]}/{items:[…]}` 兜底。
  Future<List<ReminderInboxItem>> inbox() async {
    final resp = await _client.get('/reminder-action/inbox');
    final body = resp.data;
    if (body is Map<String, dynamic> && body.containsKey('code')) {
      return normalize(_unwrapBody(body));
    }
    return normalize(body);
  }

  /// `GET /reminder-action/task/{taskId}` — 某个任务的提醒列表。
  Future<List<ReminderInboxItem>> byTask(int taskId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/reminder-action/task/$taskId',
    );
    final body = resp.data;
    return normalize(body is Map<String, dynamic> ? _unwrapBody(body) : body);
  }

  /// `POST /reminder-action/complete` body `{reminderId}`。
  Future<void> complete(int reminderId) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/complete',
        data: {'reminderId': reminderId},
      );

  /// `POST /reminder-action/dismiss` body `{reminderId}`。
  Future<void> dismiss(int reminderId) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/dismiss',
        data: {'reminderId': reminderId},
      );

  /// `POST /reminder-action/snooze` body `{reminderId, minutes}`。
  Future<void> snooze(int reminderId, {int minutes = 10}) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/snooze',
        data: {'reminderId': reminderId, 'minutes': minutes},
      );

  /// `POST /reminder-action/{id}/persistent` — 持续响铃（后端标记，仅信息态）。
  Future<void> persistent(int reminderId) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/$reminderId/persistent',
      );
}

/// 收件箱中一个待处理的提醒（来自 `GET /reminder-action/inbox`）。
class ReminderInboxItem {
  const ReminderInboxItem({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.remindAt,
    this.status = 'PENDING',
  });

  /// 提醒自身服务端 id。
  final int id;

  /// 关联任务服务端 id（int）。
  final int taskId;

  /// 关联任务标题（优先后端冗余字段，否则由页面层按 taskId 解析填充）。
  final String taskTitle;

  /// 触发时刻。
  final DateTime remindAt;

  /// PENDING / DISMISSED / DONE 等。
  final String status;

  bool get pending => status == 'PENDING';
}

/// 重复周期（repeat-occurrence）的跳过 / 追补动作（直达 REST，不走 sync 协议）。
class RepeatOccurrenceApi {
  RepeatOccurrenceApi(this._client);

  final ApiClient _client;

  /// `POST /repeat-occurrence/{id}/skip` — 跳过该周期一次发生。
  Future<void> skip(int id) =>
      _client.post<Map<String, dynamic>>('/repeat-occurrence/$id/skip');

  /// `POST /repeat-occurrence/{id}/catchup` — 追补该周期一次发生。
  Future<void> catchup(int id) =>
      _client.post<Map<String, dynamic>>('/repeat-occurrence/$id/catchup');
}
