import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'envelope.dart';

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
      throw envelopeFailure(body, path: '/app-api/todo');
    }
    return (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  }
  return body;
}

void _ensureSuccess(Map<String, dynamic>? body) {
  if (body == null || !body.containsKey('code')) return;
  if (body['code'] != 0) {
    throw envelopeFailure(body, path: '/app-api/todo');
  }
}

List<dynamic> _unwrapListBody(Map<String, dynamic>? body) {
  if (body == null) return const [];
  if (body.containsKey('code')) {
    final code = body['code'];
    if (code != 0) {
      throw envelopeFailure(body, path: '/app-api/todo');
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
    this.assigneeUserId,
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

  /// 批量指派执行人（FL #357）。`null` = 这一档不改，与其它字段同一约定。
  ///
  /// 服务端**逐条按每条任务自己的清单**校验"这个人能不能当执行人"，
  /// 所以同一批里可能有的成功、有的以 `TODO_TASK_ASSIGNEE_INVALID` 失败 ——
  /// 调用方要按**逐项结果**处理，不能假定整批同命。
  final int? assigneeUserId;
  final String? deviceId;
  final String? clientMutationId;

  bool get hasChanges =>
      listId != null ||
      priority != null ||
      dueAt != null ||
      clearDueAt == true ||
      completed != null ||
      isPinned != null ||
      tagIds != null ||
      assigneeUserId != null;

  Map<String, dynamic> toJson() => {
    'taskIds': taskIds,
    'listId': ?listId,
    'priority': ?priority,
    'dueAt': ?dueAt?.toIso8601String(),
    'clearDueAt': ?clearDueAt,
    'completed': ?completed,
    'isPinned': ?isPinned,
    'tagIds': ?tagIds,
    'assigneeUserId': ?assigneeUserId,
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

/// 服务端任务排序项。
class TodoTaskReorderItem {
  const TodoTaskReorderItem({required this.id, required this.sortOrder});

  final int id;
  final int sortOrder;

  Map<String, dynamic> toJson() => {'id': id, 'sortOrder': sortOrder};
}

/// 任务动作：完成 / 取消完成 / 重排顺序（直接 REST）。

/// 日历增强信息（农历 / 节假日；specs/125，矩阵 #31 ①）。
///
/// 判据源《02-日历/06-日历显示设置.md》:5-21——「在『设置』-『日期与时间』里
/// 开启『显示农历』和『显示节假日调休』」。服务端端点已存在：
/// `GET /todo/calendar/holidays?year&region`、`GET /todo/calendar/lunar-date?date`
/// （`AppTodoCalendarController`）。
class CalendarInfoApi {
  CalendarInfoApi(this._client);

  final ApiClient _client;

  static const _holidaysPath = '/calendar/holidays';
  static const _lunarPath = '/calendar/lunar-date';

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  dynamic _data(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('code')
      ? body['data']
      : body;

  /// 一年的节假日/调休表（含日期、名称、isHoliday/isWorkday）。
  Future<List<CalendarHoliday>> holidays({
    required int year,
    String? region,
  }) async {
    final response = await _client.get<dynamic>(
      _holidaysPath,
      query: {
        'year': year,
        if (region != null && region.isNotEmpty) 'region': region,
      },
    );
    final rows = _data(response.data);
    return rows is List
        ? rows
              .whereType<Map>()
              .map(
                (row) =>
                    CalendarHoliday.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(growable: false)
        : const <CalendarHoliday>[];
  }

  /// 单日农历（含节气/干支）。月视图一格 42 天会打多次 —— 调用方按可见月缓存。
  Future<CalendarLunarDate?> lunarDate(DateTime date) async {
    final response = await _client.get<dynamic>(
      _lunarPath,
      query: {'date': _formatDate(date)},
    );
    final data = _data(response.data);
    if (data is! Map) return null;
    return CalendarLunarDate.fromJson(Map<String, dynamic>.from(data));
  }
}

/// 节假日/调休一行（`AppTodoCalendarHolidayVO`）。
class CalendarHoliday {
  const CalendarHoliday({
    required this.date,
    this.name,
    this.isHoliday = false,
    this.isWorkday = false,
  });

  final DateTime date;
  final String? name;

  /// true = 休（放假）；false 且 isWorkday = 班（调休上班）。
  final bool isHoliday;
  final bool isWorkday;

  static DateTime _parseDate(dynamic value) {
    final raw = value?.toString() ?? '';
    final parts = raw.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory CalendarHoliday.fromJson(Map<String, dynamic> json) =>
      CalendarHoliday(
        date: _parseDate(json['date']),
        name: json['name']?.toString(),
        isHoliday: json['isHoliday'] == true,
        isWorkday: json['isWorkday'] == true,
      );
}

/// 单日农历（`AppTodoCalendarLunarRespVO`）。
class CalendarLunarDate {
  const CalendarLunarDate({
    required this.date,
    this.lunarDate,
    this.solarTerm,
    this.ganZhi,
  });

  final DateTime date;
  final String? lunarDate;
  final String? solarTerm;
  final String? ganZhi;

  factory CalendarLunarDate.fromJson(Map<String, dynamic> json) =>
      CalendarLunarDate(
        date: CalendarHoliday._parseDate(json['date']),
        lunarDate: json['lunarDate']?.toString(),
        solarTerm: json['solarTerm']?.toString(),
        ganZhi: json['ganZhi']?.toString(),
      );
}

class TaskRestApi {
  TaskRestApi(this._client);

  final ApiClient _client;

  /// `POST /task/complete`
  Future<void> complete(int serverId) =>
      _client.post('/task/complete', queryParameters: {'id': serverId});

  /// `POST /task/uncomplete`
  Future<void> uncomplete(int serverId) =>
      _client.post('/task/uncomplete', queryParameters: {'id': serverId});

  /// `PUT /task/reorder` — 请求体与服务端
  /// `AppTodoTaskReorderReqVO(listId, items)` 保持一致。
  Future<void> reorder({
    required int listId,
    required List<TodoTaskReorderItem> items,
  }) async {
    if (listId <= 0) {
      throw ArgumentError.value(listId, 'listId', '清单编号必须为正数');
    }
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', '排序项不能为空');
    }
    final resp = await _client.put<Map<String, dynamic>>(
      '/task/reorder',
      data: {
        'listId': listId,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      },
    );
    _ensureSuccess(resp.data);
  }
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
    taskId: (j['taskId'] ?? j['parentTaskId'])?.toString(),
    title: j['title']?.toString() ?? '',
    completed: j['completed'] == true,
    sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
  );

  /// `GET /task-hierarchy/checklist?taskId=...`
  Future<List<ChecklistItem>> list(int taskId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/task-hierarchy/checklist',
      query: {'taskId': taskId},
    );
    _ensureSuccess(resp.data);
    final dynamic data = resp.data?.containsKey('code') == true
        ? resp.data!['data']
        : resp.data;
    final raw = data is List
        ? data
        : data is Map
        ? (data['list'] as List?) ?? (data['items'] as List?) ?? const []
        : const [];
    return raw
        .map((e) => _fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// `POST /task-hierarchy/checklist/create`
  Future<int> create({
    required int taskId,
    required String name,
    int? assigneeUserId,
    int sortOrder = 0,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/task-hierarchy/checklist/create',
      data: {
        'taskId': taskId,
        'name': name,
        'assigneeUserId': ?assigneeUserId,
        'sortOrder': sortOrder,
      },
    );
    _ensureSuccess(resp.data);
    final dynamic data = resp.data?.containsKey('code') == true
        ? resp.data!['data']
        : (resp.data?['id'] ?? resp.data?['data']);
    if (data is num) return data.toInt();
    if (data is Map) return (data['id'] as num?)?.toInt() ?? 0;
    return int.tryParse(data?.toString() ?? '') ?? 0;
  }

  /// `PUT /task-hierarchy/checklist/update`
  Future<void> update(int checklistId, {String? name, bool? done}) =>
      _client.put(
        '/task-hierarchy/checklist/update',
        data: {'id': checklistId, 'name': ?name, 'done': ?done},
      );

  /// `DELETE /task-hierarchy/checklist/delete?id=...`
  Future<void> delete(int checklistId) => _client.delete(
    '/task-hierarchy/checklist/delete',
    queryParameters: {'id': checklistId},
  );
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

/// NLP 自然语言解析结果，对齐 JDK 25 后端
/// `AppTodoNlpParseRespVO(planDate, reminderTime, priority)`。
class NlpParseResult {
  const NlpParseResult({this.planDate, this.reminderTime, this.priority});

  final DateTime? planDate;
  final DateTime? reminderTime;
  final String? priority;

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
    }
    return null;
  }

  factory NlpParseResult.fromJson(Map<String, dynamic> json) => NlpParseResult(
    planDate: _parseDateTime(json['planDate']),
    reminderTime: _parseDateTime(json['reminderTime']),
    priority: json['priority']?.toString(),
  );
}

/// NLP 自然语言日期、提醒与优先级解析（`POST /nlp/parse`）。
class NlpApi {
  NlpApi(this._client);

  final ApiClient _client;

  Future<NlpParseResult> parse(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty || normalized.length > 200) {
      throw ArgumentError.value(text, 'text', '文本长度必须为 1 到 200 个字符');
    }
    final response = await _client.post<Map<String, dynamic>>(
      '/nlp/parse',
      data: {'text': normalized},
    );
    return NlpParseResult.fromJson(_unwrapBody(response.data));
  }

  /// 返回解析出的截止时间；无法解析时返回 null。
  Future<DateTime?> parseDue(Iterable<String> texts) async {
    for (final text in texts.where((t) => t.trim().isNotEmpty)) {
      final result = await parse(text);
      if (result.planDate != null) return result.planDate;
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
    this.createdAt,
    this.rescheduleCount,
    this.unfinishedDays,
  });

  final int taskServerId;
  final String title;
  final DateTime? dueAt;
  final String reasonCode;
  final String reason;
  final int score;

  /// #271 契约三列：⑥⑦⑧ 子档的算法输入；旧服务端或缺列时为 null。
  final DateTime? createdAt;
  final int? rescheduleCount;
  final int? unfinishedDays;

  factory RecommendationTask.fromJson(Map<String, dynamic> json) {
    // 服务端 `AppTodoRecommendTaskRespVO.dueAt` 是裸 `LocalDateTime` 且无 `@JsonFormat`，
    // 被 `TimestampLocalDateTimeSerializer` 写成 **epoch 毫秒数字**（同文件 1113/1495/1598 已是毫秒口径）；
    // 只认字符串会让 dueAt 恒 null ⇒ 「即将到来」的明天/后天子档在真实数据下永远不出现。
    final dueRaw = json['dueAt'];
    final createdRaw = json['createdAt'];
    return RecommendationTask(
      taskServerId: (json['taskId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      dueAt: dueRaw is num
          ? DateTime.fromMillisecondsSinceEpoch(dueRaw.toInt())
          : (dueRaw is String && dueRaw.isNotEmpty
                ? DateTime.tryParse(dueRaw)
                : null),
      reasonCode: json['reasonCode']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      // createdAt 与 dueAt 同为裸 LocalDateTime，同样只可能是 epoch 毫秒或字符串。
      createdAt: createdRaw is num
          ? DateTime.fromMillisecondsSinceEpoch(createdRaw.toInt())
          : (createdRaw is String && createdRaw.isNotEmpty
                ? DateTime.tryParse(createdRaw)
                : null),
      rescheduleCount: (json['rescheduleCount'] as num?)?.toInt(),
      unfinishedDays: (json['unfinishedDays'] as num?)?.toInt(),
    );
  }
}

/// 推荐任务只读接口；不参与任务写入的 outbox 协议。
class RecommendationApi {
  RecommendationApi(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiClient _client;
  final DateTime Function() _now;

  /// `GET /help/recommend-tasks?limit=10`。
  Future<List<RecommendationTask>> list({int limit = 10}) async {
    final current = _now();
    final today = DateTime(current.year, current.month, current.day);
    final tomorrow = DateTime(current.year, current.month, current.day + 1);
    final upcomingEnd = DateTime(current.year, current.month, current.day + 3);
    final response = await _client.get<dynamic>(
      '/help/recommend-tasks',
      query: {
        'limit': limit.clamp(1, 50),
        'today': _formatLocalDate(today),
        'todayStartEpochMillis': today.millisecondsSinceEpoch,
        'tomorrowStartEpochMillis': tomorrow.millisecondsSinceEpoch,
        'upcomingEndEpochMillis': upcomingEnd.millisecondsSinceEpoch,
      },
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

  String _formatLocalDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// 标签 - 任务绑定（直接 REST；本地同步写仍由 TagRepository 负责 offline 安全）。
class TagApi {
  TagApi(this._client);

  final ApiClient _client;

  /// `POST /tag/task-bind`
  Future<int> taskBind({
    required int taskId,
    required List<int> tagServerIds,
  }) async {
    if (tagServerIds.isEmpty) {
      throw ArgumentError.value(tagServerIds, 'tagServerIds', '标签不能为空');
    }
    final response = await _client.post<Map<String, dynamic>>(
      '/tag/task-bind',
      data: {'taskId': taskId, 'tagIds': tagServerIds},
    );
    _ensureSuccess(response.data);
    final dynamic data = response.data?.containsKey('code') == true
        ? response.data!['data']
        : response.data;
    return data is num ? data.toInt() : int.tryParse('$data') ?? 0;
  }

  /// `DELETE /tag/task-unbind`
  Future<void> taskUnbind({
    required int taskId,
    required int tagServerId,
  }) async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/tag/task-unbind',
      data: {'taskId': taskId, 'tagId': tagServerId},
    );
    _ensureSuccess(response.data);
  }
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

  String get actionLabel => actionLabelFor(action);

  static String actionLabelFor(String action) => switch (action) {
    'task_created' => '创建了任务',
    'task_updated' => '更新了任务',
    'task_due_rescheduled' => '调整了任务时间',
    'task_deleted' => '删除了任务',
    'task_completed' => '完成了任务',
    'task_uncompleted' => '取消完成任务',
    'task_assignee_set' => '设置了执行人',
    'task_assignee_cleared' => '移除了执行人',
    'comment_created' => '添加了评论',
    'comment_updated' => '修改了评论',
    'comment_deleted' => '删除了评论',
    _ => action,
  };

  factory TaskActivityRecord.fromJson(Map<String, dynamic> json) =>
      TaskActivityRecord(
        id: (json['id'] as num?)?.toInt() ?? 0,
        taskId: (json['taskId'] as num?)?.toInt() ?? 0,
        actorUserId: (json['actorUserId'] as num?)?.toInt(),
        actorUserName:
            json['actorUserName']?.toString() ??
            json['actorUserEmail']?.toString(),
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
      throw envelopeFailure(
        body,
        path: '/task/$taskServerId/activities',
        fallback: '动态加载失败',
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

/// 已鉴权下载的数据导出文件。
class DataExportDownload {
  const DataExportDownload({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
}

/// 便携 JSON 中可提交给 `/import-health/tasks` 的单个任务。
class PortableTaskImportTask {
  const PortableTaskImportTask({
    this.sourceTaskId,
    required this.title,
    this.description,
    this.dueAt,
    this.priority = 0,
    this.completed = false,
  });

  final String? sourceTaskId;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final int priority;
  final bool completed;

  Map<String, dynamic> toJson() => {
    if (sourceTaskId != null) 'sourceTaskId': sourceTaskId,
    'title': title,
    if (description != null) 'description': description,
    if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
    'priority': priority,
    'completed': completed,
  };
}

/// 当前用户的一条任务导入批次。
class TodoTaskImportBatch {
  const TodoTaskImportBatch({
    required this.batchId,
    required this.requestId,
    required this.source,
    required this.targetListId,
    required this.status,
    required this.importedCount,
    required this.rolledBackCount,
    required this.idempotentReplay,
    this.createTime,
    this.updateTime,
  });

  factory TodoTaskImportBatch.fromJson(Map<String, dynamic> json) =>
      TodoTaskImportBatch(
        batchId: (json['batchId'] as num?)?.toInt() ?? 0,
        requestId: json['requestId']?.toString() ?? '',
        source: json['source']?.toString() ?? 'PORTABLE_JSON',
        targetListId: (json['targetListId'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? 'IMPORTED',
        importedCount: (json['importedCount'] as num?)?.toInt() ?? 0,
        rolledBackCount: (json['rolledBackCount'] as num?)?.toInt() ?? 0,
        idempotentReplay: json['idempotentReplay'] == true,
        createTime: DateTime.tryParse(json['createTime']?.toString() ?? ''),
        updateTime: DateTime.tryParse(json['updateTime']?.toString() ?? ''),
      );

  final int batchId;
  final String requestId;
  final String source;
  final int targetListId;
  final String status;
  final int importedCount;
  final int rolledBackCount;
  final bool idempotentReplay;
  final DateTime? createTime;
  final DateTime? updateTime;
}

/// 导入接口业务异常；保留业务码用于区分“相同请求处理中”等可重试状态。
class TodoTaskImportException implements Exception {
  const TodoTaskImportException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => message;
}

/// 可追踪任务导入、批次历史与回滚 REST。
class TodoTaskImportApi {
  TodoTaskImportApi(this._client);

  static const int busyCode = 1032022006;

  final ApiClient _client;

  dynamic _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const TodoTaskImportException(-1, '导入服务响应为空');
    }
    if (body.containsKey('code')) {
      final code = (body['code'] as num?)?.toInt() ?? -1;
      if (code != 0) {
        throw TodoTaskImportException(
          code,
          body['msg']?.toString() ?? '任务导入失败',
        );
      }
      return body['data'];
    }
    return body;
  }

  Future<TodoTaskImportBatch> importTasks({
    required String requestId,
    required int targetListId,
    required List<PortableTaskImportTask> tasks,
    String source = 'PORTABLE_JSON',
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/import-health/tasks',
      data: {
        'requestId': requestId,
        'source': source,
        'targetListId': targetListId,
        'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
      },
    );
    final data = _unwrap(response.data);
    if (data is! Map) {
      throw const TodoTaskImportException(-1, '任务导入响应格式无效');
    }
    return TodoTaskImportBatch.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<TodoTaskImportBatch>> listBatches() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/import-health/task-batches',
    );
    final data = _unwrap(response.data);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) =>
              TodoTaskImportBatch.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<TodoTaskImportBatch> rollback(int batchId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/import-health/rollback',
      queryParameters: {'batchId': batchId},
    );
    final data = _unwrap(response.data);
    if (data is! Map) {
      throw const TodoTaskImportException(-1, '任务回滚响应格式无效');
    }
    return TodoTaskImportBatch.fromJson(Map<String, dynamic>.from(data));
  }
}

/// 认证器注册所需的 TOTP 密钥与标准 URI。
class TwoFactorSetup {
  const TwoFactorSetup({required this.secret, required this.otpauthUri});

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) => TwoFactorSetup(
    secret: json['secret']?.toString() ?? '',
    otpauthUri: json['otpauthUri']?.toString() ?? '',
  );

  final String secret;
  final String otpauthUri;
}

/// 账户安全 REST：会员改密 + Todo 2FA 状态 / 开关与数据导出。
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

  /// `PUT /app-api/todo-member/user/update-password` — 验证短信后修改密码。
  Future<void> changePassword({
    required String code,
    required String password,
  }) async {
    final resp = await _client.memberPut<Map<String, dynamic>>(
      '/user/update-password',
      data: {'code': code, 'password': password},
    );
    final data = _unwrap(resp.data);
    if (data != true) {
      throw Exception('修改密码失败');
    }
  }

  /// `GET /security/2fa/status` — 当前用户 2FA 是否开启。
  Future<bool> isTwoFactorEnabled() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/security/2fa/status',
    );
    final data = _unwrap(resp.data);
    return data == true || data == 'true';
  }

  /// `POST /security/2fa/setup` — 创建待确认的 TOTP 配置。
  Future<TwoFactorSetup> setupTwoFactor({String? currentCode}) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/security/2fa/setup',
      queryParameters: {
        if (currentCode != null && currentCode.isNotEmpty)
          'currentCode': currentCode,
      },
    );
    final data = _unwrap(resp.data);
    if (data is! Map) {
      throw Exception('双重验证配置响应无效');
    }
    return TwoFactorSetup.fromJson(Map<String, dynamic>.from(data));
  }

  /// `POST /security/2fa/confirm?code=...` — 校验首个动态码并正式启用。
  Future<bool> confirmTwoFactor(String code) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/security/2fa/confirm',
      queryParameters: {'code': code},
    );
    return _unwrap(resp.data) == true;
  }

  /// `POST /security/2fa/disable?code=...` — 校验当前动态码后关闭。
  Future<void> disableTwoFactor(String code) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/security/2fa/disable',
      queryParameters: {'code': code},
    );
    if (_unwrap(resp.data) != true) {
      throw Exception('关闭双重验证失败');
    }
  }

  /// `POST /security/export?exportType=FULL` — 请求数据导出。
  Future<int> requestExport({String exportType = 'FULL'}) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/security/export',
      queryParameters: {'exportType': exportType},
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

  /// `GET /security/export/{id}/download` — 使用当前登录态下载 JSON 快照。
  Future<DataExportDownload> downloadExport(int id) async {
    final resp = await _client.raw.get<List<int>>(
      '${ApiConfig.todoPrefix}/security/export/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = resp.data;
    if (data == null || data.isEmpty) {
      throw Exception('导出文件为空');
    }
    return DataExportDownload(
      filename: _exportFilename(resp.headers, id),
      bytes: Uint8List.fromList(data),
    );
  }

  String _exportFilename(Headers headers, int id) {
    final disposition = headers.value('content-disposition') ?? '';
    final encoded = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return Uri.decodeComponent(encoded);
      } on FormatException {
        // 响应头编码损坏时使用安全的后备文件名。
      }
    }
    final plain = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    if (plain != null && plain.isNotEmpty) {
      return plain;
    }
    return 'todo-export-$id.json';
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
      note = NoteApi(client),
      calSubscription = CalendarSubscriptionApi(client),
      taskImport = TodoTaskImportApi(client),
      security = SecurityApi(client),
      calendarInfo = CalendarInfoApi(client);

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
  final NoteApi note;
  final CalendarSubscriptionApi calSubscription;
  final CalendarInfoApi calendarInfo;
  final TodoTaskImportApi taskImport;
  final SecurityApi security;
}

/// 提醒动作（`/reminder-action/**`）直达 REST：收件箱 / 完成 / 忽略 / 延后；不走
/// sync 协议，由页面与通知 service 直接调用。
/// 站内通知（FL #358）。**与提醒收件箱是两个端点**，故意不合并：
///
/// 提醒那套（`ReminderActionApi.inbox`）由 `ReminderNotificationPoller` 消费，
/// 那条链路会按 `timeMode` 重解释触发时刻、把未来项**交给 OS 持久调度**、文案写死「到期提醒」。
/// 提及**不该**走那条路（它不是"到点提醒你"，而是"有人叫你了"）⇒ 单独一个端点、单独一个模型。
class TodoNotificationApi {
  TodoNotificationApi(this._client);

  final ApiClient _client;

  static const _base = '/todo/notification';

  /// 未读通知（新的在前）。
  Future<List<TodoNotificationItem>> unread() async {
    final response = await _client.get<dynamic>('$_base/unread');
    final body = response.data;
    final payload = body is Map && body.containsKey('data')
        ? body['data']
        : body;
    return TodoNotificationItem.normalize(payload);
  }

  /// 标记已读。**不是自己的通知**服务端当作不存在（不报错）。
  Future<void> markRead(int id) async {
    await _client.put<dynamic>('$_base/read', queryParameters: {'id': id});
  }
}

/// 一条站内通知。
class TodoNotificationItem {
  const TodoNotificationItem({
    required this.id,
    required this.type,
    this.taskId,
    this.actorUserId,
    this.refId,
    this.content,
    this.readAt,
  });

  final int id;

  /// `REMINDER` / `MENTION`。
  ///
  /// **消费方必须按它分流**：`MENTION` 只展示，**不许**交给 `LocalNotificationService`
  /// 去调度 —— 那套调度是提醒专用的。
  final String type;

  final int? taskId;
  final int? actorUserId;
  final int? refId;
  final String? content;
  final DateTime? readAt;

  bool get isMention => type == 'MENTION';

  static List<TodoNotificationItem> normalize(Object? data) {
    final list = data is Map ? data['list'] : data;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((raw) {
          final id = (raw['id'] as num?)?.toInt();
          if (id == null) return null;
          return TodoNotificationItem(
            id: id,
            type: (raw['type'] ?? '').toString(),
            taskId: (raw['taskId'] as num?)?.toInt(),
            actorUserId: (raw['actorUserId'] as num?)?.toInt(),
            refId: (raw['refId'] as num?)?.toInt(),
            content: raw['content']?.toString(),
            readAt: raw['readAt'] is String
                ? DateTime.tryParse(raw['readAt'] as String)
                : null,
          );
        })
        .whereType<TodoNotificationItem>()
        .toList(growable: false);
  }
}

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
        throw envelopeFailure(
          body,
          path: '/app-api/todo/reminder-action/inbox',
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

  /// `POST /reminder-action/complete` body `{reminderDispatchId}`。
  Future<void> complete(int reminderDispatchId) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/complete',
        data: {'reminderDispatchId': reminderDispatchId},
      );

  /// `POST /reminder-action/dismiss` body `{reminderDispatchId}`。
  Future<void> dismiss(int reminderDispatchId) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/dismiss',
        data: {'reminderDispatchId': reminderDispatchId},
      );

  /// `POST /reminder-action/snooze` body `{reminderDispatchId, minutes}`。
  Future<void> snooze(int reminderDispatchId, {int minutes = 10}) =>
      _client.post<Map<String, dynamic>>(
        '/reminder-action/snooze',
        data: {'reminderDispatchId': reminderDispatchId, 'minutes': minutes},
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
    this.status = 'active',
    this.mobile,
    this.displayName,
    this.email,
  });

  final int userId;

  /// `owner` / `editor` / `viewer`（后端约定）。
  final String role;

  /// `invited` / `active` / `exited` / `removed`。
  final String status;

  /// 后端可能冗余的用户资料，仅供 UI 展示；可能为 null。
  final String? mobile;
  final String? displayName;
  final String? email;

  bool get isOwner => role == 'owner';
  bool get isEditor => role == 'editor';
  bool get isViewer => role == 'viewer';

  String get roleLabel => switch (role) {
    'owner' => '所有者',
    'editor' => '可编辑',
    'viewer' => '只读',
    _ => role,
  };

  String get statusLabel => switch (status) {
    'invited' => '待接受',
    'active' => '已加入',
    'exited' => '已退出',
    'removed' => '已移除',
    _ => status,
  };
}

/// 清单协作助手：成员增删改 + 加入 / 退出。
/// 不走 sync 协议：协作权限直接在后端维护，本地仅缓存展示。
class ListCollaborationApi {
  ListCollaborationApi(this._client);

  final ApiClient _client;

  ListMember _m(Map<String, dynamic> j) => ListMember(
    userId: (j['userId'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
    role: j['role']?.toString() ?? 'viewer',
    status: j['status']?.toString() ?? 'active',
    mobile: j['mobile']?.toString(),
    displayName:
        j['displayName']?.toString() ??
        j['userName']?.toString() ??
        j['name']?.toString(),
    email: j['userEmail']?.toString() ?? j['email']?.toString(),
  );

  /// 兼容 `{code,data:[…]}`, `{code,data:{members:[…]}}`,
  /// `{data:[…]}`, `{data:{members:[…]}}`, 纯数组, `{members:[…]}` 多形态。
  List<ListMember> _list(Map<String, dynamic> body) {
    if (body.containsKey('code')) {
      // data 字段可能是 List（直接成员数组）或 Map（含 members/list/items 任一）。
      _ensureSuccess(body);
      final dynamic data = body['data'];
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

  /// 当前用户是否为清单所有者；任务批量导入只允许选择本人拥有的清单。
  Future<bool> isOwner({required int listId, required int userId}) async {
    final members = await list(listId);
    return members.any((member) => member.userId == userId && member.isOwner);
  }

  /// `POST /list/{listId}/members` body `{userMobile, role}`。
  Future<void> addMember({
    required int listId,
    required String userMobile,
    String role = 'editor',
  }) async {
    await _client.post(
      '/list/$listId/members',
      data: {'userMobile': userMobile.trim(), 'role': role},
    );
  }

  /// `PATCH /list/{listId}/members/{userId}` body `{role}`。
  Future<void> updateRole({
    required int listId,
    required int userId,
    required String role,
  }) async {
    await _client.patch('/list/$listId/members/$userId', data: {'role': role});
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
class TaskAssignee {
  const TaskAssignee({required this.userId, this.displayName, this.email});

  final int userId;
  final String? displayName;
  final String? email;
}

class TaskAssignApi {
  TaskAssignApi(this._client);

  final ApiClient _client;

  /// `GET /task/{taskId}/assignee`。
  Future<TaskAssignee?> assignee(int taskId) async {
    final resp = await _client.get('/task/$taskId/assignee');
    final body = resp.data;
    if (body is Map<String, dynamic>) {
      final data = body.containsKey('code') ? _unwrapBody(body) : body;
      final userId = (data['assigneeUserId'] as num?)?.toInt();
      if (userId == null) return null;
      return TaskAssignee(
        userId: userId,
        displayName: data['assigneeUserName']?.toString(),
        email: data['assigneeUserEmail']?.toString(),
      );
    }
    return null;
  }

  /// `PUT /task/{taskId}/assignee` body `{assigneeUserId}`。
  Future<void> setAssignee({required int taskId, required int userId}) =>
      _client.put('/task/$taskId/assignee', data: {'assigneeUserId': userId});

  Future<void> removeAssignee(int taskId) =>
      _client.delete('/task/$taskId/assignee');
}

/// 一条任务评论。
class TaskComment {
  const TaskComment({
    required this.id,
    required this.listId,
    required this.taskId,
    required this.content,
    this.userId,
    this.userName,
    this.userEmail,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int listId;
  final int taskId;
  final String content;
  final int? userId;
  final String? userName;
  final String? userEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// 任务评论助手：列出 / 添加 / 编辑 / 删除。
class TaskCommentApi {
  TaskCommentApi(this._client);

  final ApiClient _client;

  TaskComment _c(Map<String, dynamic> j) => TaskComment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    listId: (j['listId'] as num?)?.toInt() ?? 0,
    taskId: (j['taskId'] as num?)?.toInt() ?? 0,
    content: j['content']?.toString() ?? j['text']?.toString() ?? '',
    userId: (j['userId'] as num?)?.toInt(),
    userName: j['userName']?.toString(),
    userEmail: j['userEmail']?.toString(),
    createdAt: _commentTime(j['createTime']),
    updatedAt: _commentTime(j['updateTime']),
  );

  DateTime? _commentTime(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  List<TaskComment> _list(Map<String, dynamic> body) {
    final List raw;
    if (body.containsKey('code')) {
      _ensureSuccess(body);
      final dynamic data = body['data'];
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

  /// `DELETE /task/{taskId}/comments/{commentId}`。
  Future<void> delete({required int taskId, required int commentId}) =>
      _client.delete('/task/$taskId/comments/$commentId');
}

/// 一条服务端笔记。
class TodoNoteItem {
  const TodoNoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.contentType,
    required this.archived,
    this.taskId,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String content;
  final int contentType;
  final bool archived;
  final int? taskId;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TodoNoteItem.fromJson(Map<String, dynamic> json) => TodoNoteItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    contentType: (json['contentType'] as num?)?.toInt() ?? 1,
    archived: json['archived'] == true,
    taskId: (json['taskId'] as num?)?.toInt(),
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    createdAt: _parseOptionalTime(json['createTime'] ?? json['createdAt']),
    updatedAt: _parseOptionalTime(json['updateTime'] ?? json['updatedAt']),
  );

  static DateTime? _parseOptionalTime(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}

/// 笔记 REST 合同：列表、创建、编辑、删除、归档以及任务转笔记。
class NoteApi {
  NoteApi(this._client);

  final ApiClient _client;

  Future<List<TodoNoteItem>> list() async {
    final response = await _client.get<Map<String, dynamic>>('/note/list');
    final raw = _unwrapListBody(response.data);
    return raw
        .map(
          (item) =>
              TodoNoteItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<int> create({
    required String title,
    required String content,
    int contentType = 2,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/note/create',
      data: {'title': title, 'content': content, 'contentType': contentType},
    );
    return _unwrapId(response.data);
  }

  Future<void> update({
    required int id,
    required String title,
    required String content,
    int contentType = 2,
    int sortOrder = 0,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/note/update',
      data: {
        'id': id,
        'title': title,
        'content': content,
        'contentType': contentType,
        'sortOrder': sortOrder,
      },
    );
    _ensureSuccess(response.data);
  }

  Future<void> delete(int id) async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/note/delete',
      queryParameters: {'id': id},
    );
    _ensureSuccess(response.data);
  }

  Future<void> archive(int id, {required bool archived}) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/note/archive',
      queryParameters: {'id': id, 'archived': archived},
    );
    _ensureSuccess(response.data);
  }

  Future<int> convertFromTask(int taskId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/note/convert-from-task',
      queryParameters: {'taskId': taskId},
    );
    return _unwrapId(response.data);
  }

  int _unwrapId(Map<String, dynamic>? body) {
    if (body == null) return 0;
    _ensureSuccess(body);
    final data = body.containsKey('code') ? body['data'] : body['id'];
    if (data is num) return data.toInt();
    if (data is Map) return (data['id'] as num?)?.toInt() ?? 0;
    return int.tryParse(data?.toString() ?? '') ?? 0;
  }
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
    this.status = 'ACTIVE',
  });

  final int id;
  final String url;
  final String name;
  final bool enabled;
  final DateTime? lastSyncAt;
  final String? syncToken;
  final String status;
}

/// 外部 ICS 中的只读事件。
class CalendarExternalEvent {
  const CalendarExternalEvent({
    required this.subscriptionId,
    required this.sourceName,
    required this.uid,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.readOnly,
  });

  factory CalendarExternalEvent.fromJson(Map<String, dynamic> json) {
    return CalendarExternalEvent(
      subscriptionId: (json['subscriptionId'] as num?)?.toInt() ?? 0,
      sourceName: json['sourceName']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      title: json['title']?.toString() ?? '无标题事件',
      description: json['description']?.toString() ?? '',
      startAt: DateTime.parse(json['startAt'].toString()),
      endAt: DateTime.parse(json['endAt'].toString()),
      allDay: json['allDay'] == true,
      readOnly: json['readOnly'] != false,
    );
  }

  final int subscriptionId;
  final String sourceName;
  final String uid;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final bool readOnly;
}

/// ICS 订阅助手：创建 / 删除 / 列表。
class CalendarSubscriptionApi {
  CalendarSubscriptionApi(this._client);

  final ApiClient _client;

  CalSubscription _s(Map<String, dynamic> j) => CalSubscription(
    id: (j['id'] as num?)?.toInt() ?? 0,
    url: j['sourceUrl']?.toString() ?? j['url']?.toString() ?? '',
    name:
        j['name']?.toString() ??
        j['sourceUrl']?.toString() ??
        j['url']?.toString() ??
        '',
    enabled:
        (j['status']?.toString().toUpperCase() ?? 'ACTIVE') == 'ACTIVE' &&
        j['enabled'] != false,
    lastSyncAt: j['lastSyncedAt'] == null && j['lastSyncAt'] == null
        ? null
        : ReminderActionApi.parseTime(j['lastSyncedAt'] ?? j['lastSyncAt']),
    syncToken: j['subscribeToken']?.toString() ?? j['syncToken']?.toString(),
    status: j['status']?.toString().toUpperCase() ?? 'ACTIVE',
  );

  List<CalSubscription> _list(Map<String, dynamic> body) {
    final List raw;
    if (body.containsKey('code')) {
      _ensureSuccess(body);
      final dynamic data = body['data'];
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

  /// `POST /cal-sub/create` body `{sourceUrl,name}`。
  Future<int> create({required String url, String? name}) async {
    final resolvedName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : (Uri.tryParse(url)?.host ?? url);
    final resp = await _client.post<Map<String, dynamic>>(
      '/cal-sub/create',
      data: {'sourceUrl': url, 'name': resolvedName},
    );
    _ensureSuccess(resp.data);
    final dynamic data = resp.data?.containsKey('code') == true
        ? resp.data!['data']
        : (resp.data?['id'] ?? resp.data?['data']);
    if (data is num) return data.toInt();
    if (data is Map) return (data['id'] as num?)?.toInt() ?? 0;
    return int.tryParse(data?.toString() ?? '') ?? 0;
  }

  /// `DELETE /cal-sub/delete?id=...`。
  Future<void> delete(int id) async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/cal-sub/delete',
      queryParameters: {'id': id},
    );
    _ensureSuccess(response.data);
  }

  /// 获取当前账号可供第三方日历订阅的任务 ICS 地址。
  Future<String> exportUrl() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cal-sub/export-url',
    );
    _ensureSuccess(response.data);
    final dynamic data = response.data?.containsKey('code') == true
        ? response.data!['data']
        : response.data?['url'];
    return data?.toString() ?? '';
  }

  /// 读取时间窗口内的外部只读事件。
  Future<List<CalendarExternalEvent>> events({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/cal-sub/events',
      query: {'start': _dateOnly(start), 'end': _dateOnly(end)},
    );
    final body = response.data;
    if (body == null) return const [];
    _ensureSuccess(body);
    final dynamic data = body.containsKey('code')
        ? body['data']
        : body['items'];
    if (data is! List) return const [];
    return data
        .map(
          (item) => CalendarExternalEvent.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static String _dateOnly(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}
