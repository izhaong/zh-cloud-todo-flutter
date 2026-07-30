import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/notification/local_notification_service.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

/// Stable datasets shared by widget and golden tests.
enum TodoVisualFixtureSet { populated, empty, longContent }

/// Deterministic, offline-only data and providers for Todo visual tests.
class TodoVisualFixture {
  TodoVisualFixture._({
    required this.set,
    required this.fixedNow,
    required this.database,
    required this.container,
  });

  static const inboxListId = 'inbox';
  static const workListId = 'visual-list-work';
  static const personalListId = 'visual-list-personal';
  static const readingListId = 'visual-list-reading';

  static const pinnedTaskId = 'visual-task-pinned';
  static const todayTaskId = 'visual-task-today-primary';
  static const secondaryTodayTaskId = 'visual-task-today-secondary';
  static const metadataTaskId = 'visual-task-metadata';
  static const longContentTaskId = 'visual-task-long-content';
  static const todayTaskIds = <String>[
    pinnedTaskId,
    todayTaskId,
    secondaryTodayTaskId,
    metadataTaskId,
    longContentTaskId,
  ];

  static const focusTagId = 'visual-tag-focus';
  static const reviewTagId = 'visual-tag-review';
  static const followUpTagId = 'visual-tag-follow-up';
  static const collaborationTagId = 'visual-tag-collaboration';

  static const _fixedDeviceId = 'visual-fixture-device';

  final TodoVisualFixtureSet set;
  final DateTime fixedNow;
  final AppDatabase database;
  final ProviderContainer container;

  bool _disposed = false;

  static Future<TodoVisualFixture> create({
    TodoVisualFixtureSet set = TodoVisualFixtureSet.populated,
    List<Override> Function(AppDatabase database)? overridesBuilder,
  }) async {
    final fixedNow = DateTime(2026, 7, 11, 9);
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    ProviderContainer? container;

    try {
      await _seed(database, set: set, now: fixedNow);
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          apiClientProvider.overrideWithValue(_NoNetworkApiClient()),
          currentDateTimeProvider.overrideWithValue(() => fixedNow),
          connectivityChangesProvider.overrideWithValue(
            const Stream<List<ConnectivityResult>>.empty(),
          ),
          connectivityInitialStateProvider.overrideWithValue(
            () async => const [ConnectivityResult.wifi],
          ),
          deviceIdProvider.overrideWith((ref) async => _fixedDeviceId),
          syncApiProvider.overrideWith((ref) => null),
          syncCoordinatorProvider.overrideWith((ref) => null),
          localNotificationServiceProvider.overrideWithValue(
            _NoopLocalNotificationService(),
          ),
          ...?overridesBuilder?.call(database),
        ],
      );
      return TodoVisualFixture._(
        set: set,
        fixedNow: fixedNow,
        database: database,
        container: container,
      );
    } catch (_) {
      container?.dispose();
      await database.close();
      rethrow;
    }
  }

  /// Releases provider subscriptions before closing the in-memory database.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
    await database.close();
  }

  static Future<void> _seed(
    AppDatabase database, {
    required TodoVisualFixtureSet set,
    required DateTime now,
  }) async {
    final projectFolderServerId = 7101;
    await database.batch((batch) {
      batch.insert(
        database.todoFolders,
        TodoFoldersCompanion.insert(
          id: 'visual-folder-projects',
          serverId: Value(projectFolderServerId),
          name: '项目',
          sortOrder: const Value(0),
          updatedAt: now,
          createdAt: now.subtract(const Duration(days: 90)),
        ),
      );
      batch.insertAll(database.todoLists, [
        TodoListsCompanion.insert(
          id: workListId,
          name: '工作',
          folderId: Value(projectFolderServerId),
          sortOrder: const Value(0),
          updatedAt: now,
          createdAt: now.subtract(const Duration(days: 60)),
        ),
        TodoListsCompanion.insert(
          id: personalListId,
          name: '生活',
          sortOrder: const Value(1),
          updatedAt: now,
          createdAt: now.subtract(const Duration(days: 50)),
        ),
        TodoListsCompanion.insert(
          id: readingListId,
          name: '稍后阅读',
          sortOrder: const Value(2),
          updatedAt: now,
          createdAt: now.subtract(const Duration(days: 40)),
        ),
      ]);
      batch.insertAll(database.todoTags, [
        _tag(
          id: focusTagId,
          name: '专注',
          color: '#2B7EFD',
          now: now,
          createdDaysAgo: 30,
        ),
        _tag(
          id: reviewTagId,
          name: '评审',
          color: '#FB8C00',
          now: now,
          createdDaysAgo: 29,
        ),
        _tag(
          id: followUpTagId,
          name: '跟进',
          color: '#43A047',
          now: now,
          createdDaysAgo: 28,
        ),
        _tag(
          id: collaborationTagId,
          name: set == TodoVisualFixtureSet.longContent ? '需要跨团队协作确认' : '协作',
          color: '#5E35B1',
          now: now,
          createdDaysAgo: 27,
        ),
      ]);
    });

    if (set == TodoVisualFixtureSet.empty) return;

    final tasks = _tasks(
      now,
      longContent: set == TodoVisualFixtureSet.longContent,
    );
    await database.batch((batch) {
      batch.insertAll(database.todoTasks, tasks);
      batch.insertAll(database.todoTaskTags, [
        TodoTaskTagsCompanion.insert(taskId: metadataTaskId, tagId: focusTagId),
        TodoTaskTagsCompanion.insert(
          taskId: metadataTaskId,
          tagId: reviewTagId,
        ),
        TodoTaskTagsCompanion.insert(
          taskId: metadataTaskId,
          tagId: followUpTagId,
        ),
        TodoTaskTagsCompanion.insert(
          taskId: longContentTaskId,
          tagId: reviewTagId,
        ),
        TodoTaskTagsCompanion.insert(
          taskId: longContentTaskId,
          tagId: collaborationTagId,
        ),
        if (set == TodoVisualFixtureSet.longContent) ...[
          TodoTaskTagsCompanion.insert(
            taskId: longContentTaskId,
            tagId: focusTagId,
          ),
          TodoTaskTagsCompanion.insert(
            taskId: longContentTaskId,
            tagId: followUpTagId,
          ),
        ],
      ]);
    });
  }

  static List<TodoTasksCompanion> _tasks(
    DateTime now, {
    required bool longContent,
  }) {
    DateTime at(int dayOffset, int hour, [int minute = 0]) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: dayOffset));
      return DateTime(date.year, date.month, date.day, hour, minute);
    }

    return [
      _task(
        id: pinnedTaskId,
        title: '确定今天最重要的三件事',
        description: '先完成视觉母版，再处理交互细节。',
        listId: inboxListId,
        priority: 3,
        isPinned: true,
        dueAt: at(0, 9, 30),
        now: now,
        sortOrder: 0,
      ),
      _task(
        id: todayTaskId,
        title: '完成 Todo 工作区视觉评审',
        listId: inboxListId,
        priority: 2,
        dueAt: at(0, 11),
        now: now,
        sortOrder: 1,
      ),
      _task(
        id: secondaryTodayTaskId,
        title: '回复设计反馈并确认下一步',
        listId: inboxListId,
        dueAt: at(0, 14, 30),
        now: now,
        sortOrder: 2,
      ),
      _task(
        id: metadataTaskId,
        title: '准备项目周会材料',
        description: '整理进度、风险和下一阶段计划。',
        listId: inboxListId,
        priority: 1,
        dueAt: at(0, 16),
        now: now,
        sortOrder: 3,
      ),
      _task(
        id: 'visual-task-metadata-child-1',
        title: '汇总已完成事项',
        listId: inboxListId,
        parentTaskId: metadataTaskId,
        completed: true,
        now: now,
        sortOrder: 0,
      ),
      _task(
        id: 'visual-task-metadata-child-2',
        title: '补充风险与依赖',
        listId: inboxListId,
        parentTaskId: metadataTaskId,
        now: now,
        sortOrder: 1,
      ),
      _task(
        id: longContentTaskId,
        title: longContent
            ? '整理 Todo 在网页、手机与桌面端的高保真交互验收反馈，并与设计和研发确认不会影响既有离线同步能力的下一轮修改范围'
            : '整理跨端交互验收反馈',
        description: longContent
            ? '这是一段用于验证详情区、任务列表和窄窗口截断策略的稳定长文本，不应改变布局宽度，也不应产生水平溢出。'
            : '确认 Web、手机与桌面端保持一致的信息层级。',
        listId: inboxListId,
        dueAt: at(0, 18, 30),
        now: now,
        sortOrder: 4,
      ),
      _task(
        id: 'visual-task-submit-expense',
        title: '提交本月报销单',
        listId: inboxListId,
        dueAt: at(1, 10),
        now: now,
        sortOrder: 5,
      ),
      _task(
        id: 'visual-task-book-dentist',
        title: '预约下周牙科检查',
        listId: inboxListId,
        dueAt: at(2, 15),
        now: now,
        sortOrder: 6,
      ),
      _task(
        id: 'visual-task-groceries',
        title: '购买咖啡豆和早餐食材',
        listId: inboxListId,
        now: now,
        sortOrder: 7,
      ),
      _task(
        id: 'visual-task-call-family',
        title: '给家人打电话',
        listId: inboxListId,
        dueAt: at(1, 20),
        now: now,
        sortOrder: 8,
      ),
      _task(
        id: 'visual-task-weekly-review',
        title: '整理本周复盘笔记',
        listId: inboxListId,
        priority: 1,
        now: now,
        sortOrder: 9,
      ),
      _task(
        id: 'visual-task-backup-photos',
        title: '备份手机照片',
        listId: inboxListId,
        now: now,
        sortOrder: 10,
      ),
      _task(
        id: 'visual-task-read-article',
        title: '阅读 Flutter 响应式布局笔记',
        listId: inboxListId,
        now: now,
        sortOrder: 11,
      ),
      _task(
        id: 'visual-task-completed',
        title: '清理收集箱中的旧任务',
        listId: inboxListId,
        completed: true,
        dueAt: at(-1, 17),
        now: now,
        sortOrder: 12,
      ),
      _task(
        id: 'visual-task-work-list',
        title: '确认下周发布窗口',
        listId: workListId,
        dueAt: at(3, 10),
        now: now,
        sortOrder: 0,
      ),
      _task(
        id: 'visual-task-personal-list',
        title: '规划周末骑行路线',
        listId: personalListId,
        dueAt: at(1, 8),
        now: now,
        sortOrder: 0,
      ),
      _task(
        id: 'visual-task-reading-list',
        title: '阅读离线优先架构文章',
        listId: readingListId,
        now: now,
        sortOrder: 0,
      ),
    ];
  }
}

TodoTagsCompanion _tag({
  required String id,
  required String name,
  required String color,
  required DateTime now,
  required int createdDaysAgo,
}) {
  return TodoTagsCompanion.insert(
    id: id,
    name: name,
    color: Value(color),
    updatedAt: now,
    createdAt: now.subtract(Duration(days: createdDaysAgo)),
  );
}

TodoTasksCompanion _task({
  required String id,
  required String title,
  required String listId,
  required DateTime now,
  required int sortOrder,
  String? description,
  String? parentTaskId,
  bool completed = false,
  int priority = 0,
  bool isPinned = false,
  DateTime? dueAt,
}) {
  final createdAt = now.subtract(Duration(days: 14, minutes: sortOrder));
  return TodoTasksCompanion.insert(
    id: id,
    listId: listId,
    parentTaskId: Value(parentTaskId),
    title: title,
    description: Value(description),
    completed: Value(completed),
    priority: Value(priority),
    isPinned: Value(isPinned),
    sortOrder: Value(sortOrder),
    dueAt: Value(dueAt),
    updatedAt: createdAt.add(const Duration(days: 13)),
    createdAt: createdAt,
  );
}

class _NoopLocalNotificationService extends LocalNotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermissions() async => false;
}

/// Any unexpected API use fails immediately instead of reaching the network.
class _NoNetworkApiClient extends ApiClient {
  Future<Response<T>> _blocked<T>(String method, String path) {
    return Future<Response<T>>.error(
      StateError('Network disabled in TodoVisualFixture: $method $path'),
    );
  }

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    if (path == '/task/checklist') {
      final body = <String, dynamic>{
        'code': 0,
        'data': <String, dynamic>{'list': <Object>[]},
      };
      return Future.value(
        Response<T>(
          requestOptions: RequestOptions(path: path),
          data: body as T,
          statusCode: 200,
        ),
      );
    }
    return _blocked('GET', path);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _blocked('POST', path);

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _blocked('PUT', path);

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _blocked('DELETE', path);

  @override
  Future<Response<T>> memberGet<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) => _blocked('MEMBER GET', path);

  @override
  Future<Response<T>> memberPost<T>(String path, {Object? data}) =>
      _blocked('MEMBER POST', path);

  @override
  Future<Response<T>> memberPut<T>(String path, {Object? data}) =>
      _blocked('MEMBER PUT', path);
}
