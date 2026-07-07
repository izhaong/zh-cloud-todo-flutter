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
        tag = TagApi(client);

  final TaskRestApi task;
  final ChecklistApi checklist;
  final FolderApi folder;
  final NlpApi nlp;
  final TagApi tag;
}
