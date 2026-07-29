import 'package:dio/dio.dart';

import 'api_client.dart';

export 'api_config.dart' show ApiConfig;

/// 任务 / 清单 / 文件夹 / 标签 的直连 REST 助手（`/app-api/todo/**` 前缀由
/// [ApiClient] 自动补全，传参使用无前缀路径如 `/task/complete`）。
///
/// 以下端点**不在** `/app-api/todo/sync` 白名单内（checklist / complete /
/// reorder / folder / tag-task-bind / nlp / security），故直接调用 REST；其余
/// 9 个同步实体仍走各 Repository 的 drift + outbox 路径，不再这里重复。

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

void _ensureSuccess(Map<String, dynamic>? body) {
  if (body == null || !body.containsKey('code')) return;
  if (body['code'] != 0) {
    throw DioException(
      requestOptions: RequestOptions(path: '/app-api/todo'),
      error: body['msg'] ?? '请求失败',
    );
  }
}

List<dynamic> _unwrapListBody(Map<String, dynamic>? body) {
  if (body == null) return const [];
  if (body.containsKey('code')) {
    final code = body['code'];
    if (code != 0) {
      throw DioException(
        requestOptions: RequestOptions(path: '/app-api/todo'),
        error: body['msg'] ?? '请求失败',
      );
    }
    return (body['data'] as List?)?.toList(growable: false) ?? const [];
  }
  return (body['data'] as List?)?.toList(growable: false) ?? const [];
}

/// 一条服务端全局搜索结果。UI 不直接消费该类型：工作区继续通过
/// `TaskQueryRepository` 查询本地 Drift；此 API 供同步后的契约/A-B 对照使用。
class TodoGlobalSearchResult {
  const TodoGlobalSearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.listId,
  });

  final String type;
  final int id;
  final String title;
  final int? listId;

  factory TodoGlobalSearchResult.fromJson(Map<String, dynamic> json) =>
      TodoGlobalSearchResult(
        type: json['type']?.toString() ?? '',
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        listId: (json['listId'] as num?)?.toInt(),
      );
}

/// 服务端稳定分页的搜索页。
class TodoGlobalSearchPage {
  const TodoGlobalSearchPage({required this.items, required this.total});

  final List<TodoGlobalSearchResult> items;
  final int total;
}

/// `GET /task/global-search` 的契约封装。
///
/// 它只属于 API 边界及真实 HTTP A/B Drift 验收；离线 UI 不以网络响应作为
/// 真相源，避免违反 B3 的 Repository/use-case 约束。
class TodoGlobalSearchApi {
  TodoGlobalSearchApi(this._client);

  final ApiClient _client;

  Future<TodoGlobalSearchPage> search({
    required String keyword,
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw ArgumentError.value(keyword, 'keyword', '关键词不能为空');
    }
    if (pageNo < 1 || pageSize < 1) {
      throw ArgumentError('pageNo 和 pageSize 必须为正数');
    }

    final resp = await _client.get<Map<String, dynamic>>(
      '/task/global-search',
      query: {
        'keyword': normalizedKeyword,
        'pageNo': pageNo,
        'pageSize': pageSize,
      },
    );
    final data = _unwrapBody(resp.data);
    final raw = (data['list'] as List?) ?? const [];
    return TodoGlobalSearchPage(
      items: raw
          .map(
            (item) => TodoGlobalSearchResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      total: (data['total'] as num?)?.toInt() ?? raw.length,
    );
  }
}

/// 服务端已保存过滤器命中的单条任务。
///
/// 该模型只描述 `/filter/apply` 的只读分页结果。离线工作区仍通过
/// `TaskQueryRepository` 查询 Drift，不能用网络结果取代本地真相源。
class TodoFilterTaskResult {
  const TodoFilterTaskResult({
    required this.id,
    required this.title,
    required this.priority,
  });

  final int id;
  final String title;
  final int priority;

  factory TodoFilterTaskResult.fromJson(Map<String, dynamic> json) =>
      TodoFilterTaskResult(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );
}

/// 服务端过滤器应用结果的稳定分页。
class TodoFilterApplyPage {
  const TodoFilterApplyPage({required this.items, required this.total});

  final List<TodoFilterTaskResult> items;
  final int total;
}

/// `POST /filter/apply` 的契约封装。
///
/// 用于真实 HTTP 及同步 A/B 对照，不供 Widget 绕过 Repository/use-case 直连。
class TodoFilterApplyApi {
  TodoFilterApplyApi(this._client);

  final ApiClient _client;

  Future<TodoFilterApplyPage> apply({
    required int filterId,
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    if (filterId <= 0 || pageNo < 1 || pageSize < 1 || pageSize > 200) {
      throw ArgumentError('filterId、pageNo 和 pageSize 必须在有效范围内');
    }
    final resp = await _client.post<Map<String, dynamic>>(
      '/filter/apply',
      data: {'id': filterId, 'pageNo': pageNo, 'pageSize': pageSize},
    );
    final data = _unwrapBody(resp.data);
    final raw = (data['list'] as List?) ?? const [];
    return TodoFilterApplyPage(
      items: raw
          .map(
            (item) => TodoFilterTaskResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      total: (data['total'] as num?)?.toInt() ?? raw.length,
    );
  }
}

/// 一次服务端批量更新的冻结请求。
///
/// 与本地 [TaskBatchEditRepository] 的 Drift/outbox 写路径分离：该类型用于
/// 显式 HTTP 消费、逐项结果显示和可重试幂等契约，绝不替代离线本地写入。
class TodoTaskBatchUpdateRequest {
  const TodoTaskBatchUpdateRequest({
    required this.taskIds,
    this.listId,
    this.priority,
    this.dueAt,
    this.clearDueAt,
    this.completed,
    this.isPinned,
    this.tagIds,
    this.deviceId,
    this.clientMutationId,
  });

  final List<int> taskIds;
  final int? listId;
  final int? priority;
  final DateTime? dueAt;
  final bool? clearDueAt;
  final bool? completed;
  final bool? isPinned;
  final List<int>? tagIds;
  final String? deviceId;
  final String? clientMutationId;

  bool get hasChanges =>
      listId != null ||
      priority != null ||
      dueAt != null ||
      clearDueAt == true ||
      completed != null ||
      isPinned != null ||
      tagIds != null;

  Map<String, dynamic> toJson() => {
    'taskIds': taskIds,
    'listId': ?listId,
    'priority': ?priority,
    'dueAt': ?dueAt?.toIso8601String(),
    'clearDueAt': ?clearDueAt,
    'completed': ?completed,
    'isPinned': ?isPinned,
    'tagIds': ?tagIds,
    'deviceId': ?deviceId,
    'clientMutationId': ?clientMutationId,
  };
}

/// 服务端批量更新的一项结果；[errorCode] 可用于失败项重试提示。
class TodoTaskBatchUpdateResult {
  const TodoTaskBatchUpdateResult({
    required this.taskId,
    required this.status,
    this.errorCode,
  });

  final int? taskId;
  final String status;
  final String? errorCode;

  factory TodoTaskBatchUpdateResult.fromJson(Map<String, dynamic> json) =>
      TodoTaskBatchUpdateResult(
        taskId: (json['taskId'] as num?)?.toInt(),
        status: json['status']?.toString() ?? 'failed',
        errorCode: json['errorCode']?.toString(),
      );
}

/// `PUT /task/batch-update` 的逐项、可重试 HTTP 契约。
class TodoTaskBatchApi {
  TodoTaskBatchApi(this._client);

  final ApiClient _client;

  Future<List<TodoTaskBatchUpdateResult>> update(
    TodoTaskBatchUpdateRequest request,
  ) async {
    if (request.taskIds.isEmpty) {
      throw ArgumentError.value(request.taskIds, 'taskIds', '任务编号不能为空');
    }
    if (!request.hasChanges) {
      throw ArgumentError.value(request, 'request', '至少提供一个批量修改字段');
    }
    final hasDeviceId = (request.deviceId?.trim().isNotEmpty ?? false);
    final hasMutationId =
        (request.clientMutationId?.trim().isNotEmpty ?? false);
    if (hasDeviceId != hasMutationId) {
      throw ArgumentError('deviceId 和 clientMutationId 必须成对提供');
    }
    final resp = await _client.put<Map<String, dynamic>>(
      '/task/batch-update',
      data: request.toJson(),
    );
    return _unwrapListBody(resp.data)
        .whereType<Map>()
        .map(
          (item) => TodoTaskBatchUpdateResult.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }
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
  }) => _client.put(
    '/task/checklist/update',
    data: {
      'id': checklistId,
      'title': ?title,
      'completed': ?completed,
      'sortOrder': ?sortOrder,
    },
  );

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

  /// `DELETE /folder/delete?id=...`
  Future<void> deleteFolder(int serverId) async {
    final response = await _client.raw.delete<Map<String, dynamic>>(
      '/app-api/todo/folder/delete',
      queryParameters: {'id': serverId},
    );
    _ensureSuccess(response.data);
  }

  /// `POST /folder/move-list` — 批量把清单挪到目标文件夹；传 null 表示移出文件夹。
  Future<void> moveLists({
    required List<int> listServerIds,
    int? folderServerId,
  }) async {
    if (listServerIds.isEmpty) {
      throw ArgumentError.value(listServerIds, 'listServerIds', '清单不能为空');
    }
    final response = await _client.post<Map<String, dynamic>>(
      '/folder/move-list',
      data: {'listIds': listServerIds, 'folderId': ?folderServerId},
    );
    _ensureSuccess(response.data);
  }
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

/// 服务端按当前用户可见任务实时计算的推荐项。
class RecommendationTask {
  const RecommendationTask({
    required this.taskServerId,
    required this.title,
    this.dueAt,
    required this.reasonCode,
    required this.reason,
    required this.score,
  });

  final int taskServerId;
  final String title;
  final DateTime? dueAt;
  final String reasonCode;
  final String reason;
  final int score;

  factory RecommendationTask.fromJson(Map<String, dynamic> json) {
    final dueRaw = json['dueAt'];
    return RecommendationTask(
      taskServerId: (json['taskId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      dueAt: dueRaw is String ? DateTime.tryParse(dueRaw) : null,
      reasonCode: json['reasonCode']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 推荐任务只读接口；不参与任务写入的 outbox 协议。
class RecommendationApi {
  RecommendationApi(this._client);

  final ApiClient _client;

  /// `GET /help/recommend-tasks?limit=10`。
  Future<List<RecommendationTask>> list({int limit = 10}) async {
    final response = await _client.get<dynamic>(
      '/help/recommend-tasks',
      query: {'limit': limit.clamp(1, 50)},
    );
    final body = response.data;
    final data = body is Map<String, dynamic> && body.containsKey('code')
        ? body['data']
        : body;
    final rows = data is List ? data : const <dynamic>[];
    return rows
        .whereType<Map>()
        .map(
          (row) => RecommendationTask.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.taskServerId > 0 && item.reasonCode.isNotEmpty)
        .toList(growable: false);
  }
}

/// 标签 - 任务绑定（直接 REST；本地同步写仍由 TagRepository 负责 offline 安全）。
class TagApi {
  TagApi(this._client);

  final ApiClient _client;

  /// `POST /tag/task-bind`
  Future<void> taskBind({required String taskId, required int tagServerId}) =>
      _client.post(
        '/tag/task-bind',
        data: {'taskId': taskId, 'tagId': tagServerId},
      );

  /// `DELETE /tag/task-unbind`
  Future<void> taskUnbind({required String taskId, required int tagServerId}) =>
      _client.delete(
        '/tag/task-unbind',
        data: {'taskId': taskId, 'tagId': tagServerId},
      );
}

class TaskActivityRecord {
  const TaskActivityRecord({
    required this.id,
    required this.taskId,
    required this.action,
    required this.occurredAt,
    this.actorUserId,
    this.actorUserName,
    this.detail,
  });

  final int id;
  final int taskId;
  final int? actorUserId;
  final String? actorUserName;
  final String action;
  final String? detail;
  final DateTime occurredAt;

  factory TaskActivityRecord.fromJson(Map<String, dynamic> json) =>
      TaskActivityRecord(
        id: (json['id'] as num?)?.toInt() ?? 0,
        taskId: (json['taskId'] as num?)?.toInt() ?? 0,
        actorUserId: (json['actorUserId'] as num?)?.toInt(),
        actorUserName: json['actorUserName']?.toString(),
        action: json['action']?.toString() ?? 'unknown',
        detail: json['detail']?.toString(),
        occurredAt: ReminderActionApi.parseTime(json['createTime']),
      );
}

class ActivityApi {
  ActivityApi(this._client);

  final ApiClient _client;

  Future<List<TaskActivityRecord>> listTask(int taskServerId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/task/$taskServerId/activities',
      query: {'limit': 100},
    );
    final body = response.data ?? const <String, dynamic>{};
    if (body['code'] != null && body['code'] != 0) {
      throw DioException(
        requestOptions: RequestOptions(path: '/task/$taskServerId/activities'),
        error: body['msg'] ?? '动态加载失败',
      );
    }
    final raw = body['data'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => TaskActivityRecord.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }
}

/// 单个数据导出记录（`/security/export/list` 返回行）。
class DataExportItem {
  DataExportItem({
    required this.id,
    required this.exportType,
    required this.exportUrl,
    required this.status,
  });

  final int id;
  final String exportType;
  final String exportUrl;
  final String status;

  factory DataExportItem.fromJson(Map<String, dynamic> j) => DataExportItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    exportType: j['exportType']?.toString() ?? 'FULL',
    exportUrl: j['exportUrl']?.toString() ?? '',
    status: j['status']?.toString() ?? 'PENDING',
  );
}

/// 账户安全 REST（`/security/**`）：2FA 状态 / 开关 + 数据导出，直连 REST。
class SecurityApi {
  SecurityApi(this._client);

  final ApiClient _client;

  /// 统一响应信封 `{code, msg, data}`：`code != 0` 抛异常，返回 `data`。
  dynamic _unwrap(Map<String, dynamic>? body) {
    if (body == null) return null;
    if (body.containsKey('code')) {
      final code = body['code'];
      if (code != 0) {
        throw Exception(body['msg'] ?? '安全请求失败');
      }
      return body['data'];
    }
    return body;
  }

  /// `GET /security/2fa/status` — 当前用户 2FA 是否开启。
  Future<bool> isTwoFactorEnabled() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/security/2fa/status',
    );
    final data = _unwrap(resp.data);
    return data == true || data == 'true';
  }

  /// `POST /security/2fa/enable` — 开启 2FA，返回 2FA 记录 ID。
  Future<int> enableTwoFactor() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/security/2fa/enable',
    );
    final data = _unwrap(resp.data);
    return (data as num?)?.toInt() ?? 0;
  }

  /// `POST /security/2fa/disable` — 关闭 2FA。
  Future<void> disableTwoFactor() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/security/2fa/disable',
    );
    _unwrap(resp.data);
  }

  /// `POST /security/export?exportType=FULL` — 请求数据导出。
  Future<int> requestExport({String exportType = 'FULL'}) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/security/export',
      data: {'exportType': exportType},
    );
    final data = _unwrap(resp.data);
    return (data as num?)?.toInt() ?? 0;
  }

  /// `GET /security/export/list` — 我的导出记录。
  Future<List<DataExportItem>> listExports() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/security/export/list',
    );
    final data = _unwrap(resp.data);
    final raw = (data is List ? data : <dynamic>[])
        .cast<Map<String, dynamic>>();
    return raw.map(DataExportItem.fromJson).toList();
  }
}

/// 直连 REST helper 容器：一次性拿到所有子 helper，便于页面注入。
class TodoRestApi {
  TodoRestApi(ApiClient client)
    : task = TaskRestApi(client),
      taskBatch = TodoTaskBatchApi(client),
      globalSearch = TodoGlobalSearchApi(client),
      filter = TodoFilterApplyApi(client),
      checklist = ChecklistApi(client),
      folder = FolderApi(client),
      nlp = NlpApi(client),
      recommendation = RecommendationApi(client),
      tag = TagApi(client),
      activity = ActivityApi(client),
      reminder = ReminderActionApi(client),
      listCollaboration = ListCollaborationApi(client),
      taskAssign = TaskAssignApi(client),
      comment = TaskCommentApi(client),
      calSubscription = CalendarSubscriptionApi(client),
      security = SecurityApi(client);

  final TaskRestApi task;
  final TodoTaskBatchApi taskBatch;
  final TodoGlobalSearchApi globalSearch;
  final TodoFilterApplyApi filter;
  final ChecklistApi checklist;
  final FolderApi folder;
  final NlpApi nlp;
  final RecommendationApi recommendation;
  final TagApi tag;
  final ActivityApi activity;
  final ReminderActionApi reminder;
  final ListCollaborationApi listCollaboration;
  final TaskAssignApi taskAssign;
  final TaskCommentApi comment;
  final CalendarSubscriptionApi calSubscription;
  final SecurityApi security;
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
    id:
        (j['reminderDispatchId'] as num?)?.toInt() ??
        (j['id'] as num?)?.toInt() ??
        0,
    reminderId: (j['reminderId'] as num?)?.toInt(),
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
      final code = body['code'];
      if (code != 0) {
        throw DioException(
          requestOptions: RequestOptions(
            path: '/app-api/todo/reminder-action/inbox',
          ),
          error: body['msg'] ?? '请求失败',
        );
      }
      // 收件箱成功信封的 data 是列表而非通用 REST helper 所假定的 Map。
      return normalize(body['data']);
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
  Future<void> complete(int reminderId) => _client.post<Map<String, dynamic>>(
    '/reminder-action/complete',
    data: {'reminderId': reminderId},
  );

  /// `POST /reminder-action/dismiss` body `{reminderId}`。
  Future<void> dismiss(int reminderId) => _client.post<Map<String, dynamic>>(
    '/reminder-action/dismiss',
    data: {'reminderId': reminderId},
  );

  /// `POST /reminder-action/snooze` body `{reminderId, minutes}`。
  Future<void> snooze(int reminderId, {int minutes = 10}) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/snooze',
        data: {'reminderId': reminderId, 'minutes': minutes},
      );

  /// `POST /reminder-action/{id}/persistent` — 启用持续提醒。
  Future<void> persistent(
    int reminderId, {
    int intervalMinutes = 30,
    String? timeZone,
    bool fixedTimezone = false,
  }) => _client.post<Map<String, dynamic>>(
    '/reminder-action/$reminderId/persistent',
    data: {
      'intervalMinutes': intervalMinutes,
      'timeZone': ?timeZone,
      'fixedTimezone': fixedTimezone,
    },
  );
}

/// 收件箱中一个待处理的提醒（来自 `GET /reminder-action/inbox`）。
class ReminderInboxItem {
  const ReminderInboxItem({
    required this.id,
    int? reminderId,
    required this.taskId,
    required this.taskTitle,
    required this.remindAt,
    this.status = 'PENDING',
  }) : reminderId = reminderId ?? id;

  /// 派发记录 ID：用于完成、忽略和稍后动作。
  /// 提醒自身服务端 id。
  final int id;

  /// 提醒规则 ID：用于启用或关闭持续提醒，不能替代 [id]。
  final int reminderId;

  /// 关联任务服务端 id（int）。
  final int taskId;

  /// 关联任务标题（优先后端冗余字段，否则由页面层按 taskId 解析填充）。
  final String taskTitle;

  /// 触发时刻。
  final DateTime remindAt;

  /// PENDING / DISMISSED / DONE 等。
  final String status;

  bool get pending => status == 'PENDING' || status == 'SENT';
}

/// 清单成员：后端 `members.int` 响应单项。
class ListMember {
  const ListMember({
    required this.userId,
    required this.role,
    this.mobile,
    this.displayName,
  });

  final int userId;

  /// `owner` / `member`（后端约定）。
  final String role;

  /// 后端可能冗余（脱敏后）的手机号 / 显示名，仅供 UI 展示；可能为 null。
  final String? mobile;
  final String? displayName;

  bool get isOwner => role == 'owner';
}

/// 清单协作助手：成员增删改 + 加入 / 退出。
/// 不走 sync 协议：协作权限直接在后端维护，本地仅缓存展示。
class ListCollaborationApi {
  ListCollaborationApi(this._client);

  final ApiClient _client;

  ListMember _m(Map<String, dynamic> j) => ListMember(
    userId: (j['userId'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
    role: j['role']?.toString() ?? 'member',
    mobile: j['mobile']?.toString(),
    displayName: j['displayName']?.toString() ?? j['name']?.toString(),
  );

  /// 兼容 `{code,data:[…]}`, `{code,data:{members:[…]}}`,
  /// `{data:[…]}`, `{data:{members:[…]}}`, 纯数组, `{members:[…]}` 多形态。
  List<ListMember> _list(Map<String, dynamic> body) {
    if (body.containsKey('code')) {
      // data 字段可能是 List（直接成员数组）或 Map（含 members/list/items 任一）。
      final dynamic data = _unwrapBody(body);
      if (data is List) {
        return data
            .map((e) => _m(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (data is Map) {
        final raw =
            (data['members'] as List?) ??
            (data['list'] as List?) ??
            (data['items'] as List?) ??
            const [];
        return raw.map((e) => _m(Map<String, dynamic>.from(e as Map))).toList();
      }
      return const [];
    }
    if (body['data'] is List) {
      return (body['data'] as List)
          .map((e) => _m(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (body['data'] is Map) {
      final d = Map<String, dynamic>.from(body['data'] as Map);
      final raw =
          (d['members'] as List?) ??
          (d['list'] as List?) ??
          (d['items'] as List?) ??
          const [];
      return raw.map((e) => _m(Map<String, dynamic>.from(e as Map))).toList();
    }
    return const [];
  }

  List<ListMember> _listFromArray(Object? raw) {
    if (raw is List) {
      return raw.map((e) => _m(Map<String, dynamic>.from(e as Map))).toList();
    }
    return const [];
  }

  /// `GET /list/{listId}/members`
  Future<List<ListMember>> list(int listId) async {
    final resp = await _client.get('/list/$listId/members');
    final body = resp.data;
    if (body is Map<String, dynamic>) return _list(body);
    return _listFromArray(body);
  }

  /// `POST /list/{listId}/members` body `{userId, role}`。
  Future<void> addMember({
    required int listId,
    required int userId,
    String role = 'member',
  }) async {
    await _client.post(
      '/list/$listId/members',
      data: {'userId': userId, 'role': role},
    );
  }

  /// `PUT /list/{listId}/members/{userId}` body `{role}`。
  /// 备注：ApiClient 仅有 GET/POST/PUT/DELETE，故 PATCH 改用 PUT。
  Future<void> updateRole({
    required int listId,
    required int userId,
    required String role,
  }) async {
    await _client.put('/list/$listId/members/$userId', data: {'role': role});
  }

  /// `DELETE /list/{listId}/members/{userId}`。
  Future<void> removeMember({required int listId, required int userId}) async {
    await _client.delete('/list/$listId/members/$userId');
  }

  /// `POST /list/{listId}/member/join`（通过链接加入）。
  Future<void> join(int listId) => _client.post('/list/$listId/member/join');

  /// `POST /list/{listId}/member/exit`（主动退出）。
  Future<void> exit(int listId) => _client.post('/list/$listId/member/exit');
}

/// 任务协作者：指派 / 移除执行人。
class TaskAssignApi {
  TaskAssignApi(this._client);

  final ApiClient _client;

  /// `GET /task/{taskId}/assignee` — 返回 null 或 `int`（userId）。
  Future<int?> assignee(int taskId) async {
    final resp = await _client.get('/task/$taskId/assignee');
    final body = resp.data;
    if (body is Map<String, dynamic>) {
      if (body.containsKey('code')) {
        final data = _unwrapBody(body);
        if (data.isEmpty) return null;
        return (data['userId'] as num?)?.toInt() ?? data['id'] as int?;
      }
      if (body.containsKey('userId')) {
        return (body['userId'] as num?)?.toInt();
      }
      return null;
    }
    if (body is num) return body.toInt();
    return null;
  }

  /// `PUT /task/{taskId}/assignee` body `{userId}`（null 表示移除）。
  Future<void> setAssignee({required int taskId, required int? userId}) =>
      _client.put('/task/$taskId/assignee', data: {'userId': userId});

  Future<void> removeAssignee(int taskId) =>
      _client.delete('/task/$taskId/assignee');
}

/// 一条任务评论。
class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.content,
    this.userId,
    this.createdAt,
  });

  final int id;
  final int taskId;
  final String content;
  final int? userId;
  final DateTime? createdAt;
}

/// 任务评论助手：列出 / 添加 / 编辑 / 删除。
class TaskCommentApi {
  TaskCommentApi(this._client);

  final ApiClient _client;

  TaskComment _c(Map<String, dynamic> j) => TaskComment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    taskId: (j['taskId'] as num?)?.toInt() ?? 0,
    content: j['content']?.toString() ?? j['text']?.toString() ?? '',
    userId: (j['userId'] as num?)?.toInt(),
    createdAt: ReminderActionApi.parseTime(j['createdAt']),
  );

  List<TaskComment> _list(Map<String, dynamic> body) {
    final List raw;
    if (body.containsKey('code')) {
      final dynamic data = _unwrapBody(body);
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw =
            (data['list'] as List?) ??
            (data['items'] as List?) ??
            (data['comments'] as List?) ??
            const [];
      } else {
        raw = const [];
      }
    } else {
      raw =
          (body['list'] as List?) ??
          (body['items'] as List?) ??
          (body['data'] is List ? body['data'] as List : const []);
    }
    return raw.map((e) => _c(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// `GET /task/{taskId}/comments`
  Future<List<TaskComment>> list(int taskId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/task/$taskId/comments',
    );
    final body = resp.data;
    if (body is Map<String, dynamic>) return _list(body);
    return const [];
  }

  /// `POST /comment/create` body `{taskId, content}`。
  /// 备注：后端也兼容 `POST /task/{taskId}/comments`；优先 `/comment/create`。
  Future<int> add({required int taskId, required String content}) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/comment/create',
      data: {'taskId': taskId, 'content': content},
    );
    final data = _unwrapBody(resp.data);
    return (data['id'] as num?)?.toInt() ?? 0;
  }

  /// `PUT /comment/update` body `{id, content}`（首选）。
  Future<void> update({required int commentId, required String content}) async {
    await _client.put(
      '/comment/update',
      data: {'id': commentId, 'content': content},
    );
  }

  /// `POST /comment/delete` body `{id}`。
  Future<void> delete(int commentId) =>
      _client.delete('/comment/delete', data: {'id': commentId});
}

/// 一行后端 ICS 订阅。
class CalSubscription {
  const CalSubscription({
    required this.id,
    required this.url,
    required this.name,
    this.enabled = true,
    this.lastSyncAt,
    this.syncToken,
  });

  final int id;
  final String url;
  final String name;
  final bool enabled;
  final DateTime? lastSyncAt;
  final String? syncToken;
}

/// ICS 订阅助手：创建 / 删除 / 列表。
class CalendarSubscriptionApi {
  CalendarSubscriptionApi(this._client);

  final ApiClient _client;

  CalSubscription _s(Map<String, dynamic> j) => CalSubscription(
    id: (j['id'] as num?)?.toInt() ?? 0,
    url: j['url']?.toString() ?? '',
    name: j['name']?.toString() ?? (j['url']?.toString() ?? ''),
    enabled: j['enabled'] != false,
    lastSyncAt: ReminderActionApi.parseTime(j['lastSyncAt']),
    syncToken: j['syncToken']?.toString(),
  );

  List<CalSubscription> _list(Map<String, dynamic> body) {
    final List raw;
    if (body.containsKey('code')) {
      final dynamic data = _unwrapBody(body);
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw =
            (data['list'] as List?) ??
            (data['items'] as List?) ??
            (data['subscriptions'] as List?) ??
            const [];
      } else {
        raw = const [];
      }
    } else {
      raw = (body['list'] as List?) ?? (body['items'] as List?) ?? const [];
    }
    return raw.map((e) => _s(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// `GET /cal-sub/list`
  Future<List<CalSubscription>> list() async {
    final resp = await _client.get<Map<String, dynamic>>('/cal-sub/list');
    final body = resp.data;
    if (body is Map<String, dynamic>) return _list(body);
    return const [];
  }

  /// `POST /cal-sub/create` body `{url,name?,enabled?}`。
  Future<int> create({
    required String url,
    String? name,
    bool enabled = true,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/cal-sub/create',
      data: {'url': url, 'name': ?name, 'enabled': enabled},
    );
    final data = _unwrapBody(resp.data);
    return (data['id'] as num?)?.toInt() ?? 0;
  }

  /// `POST /cal-sub/delete` body `{id}`。
  Future<void> delete(int id) =>
      _client.delete('/cal-sub/delete', data: {'id': id});
}
