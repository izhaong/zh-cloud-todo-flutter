import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/home/recommendation_panel.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/recommendation_repository.dart';

void main() {
  testWidgets('推荐任务展示原因并通过本地 serverId 交给选择回调', (tester) async {
    final semantics = tester.ensureSemantics();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '即将到期的任务',
            reasonCode: 'DUE_SOON',
            reason: '即将到期',
            score: 900,
            refreshedAt: DateTime.utc(2026, 7, 16),
          ),
        );
    final repository = RecommendationRepository(
      db,
      _OfflineRecommendationApi(),
    );
    int? selected;
    int? addedToToday;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationPanel(
              onTaskSelected: (taskId) => selected = taskId,
              onAddToToday: (taskId) async => addedToToday = taskId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('推荐任务'), findsOneWidget);
    final panelSemanticsFinder = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == '推荐任务',
    );
    expect(panelSemanticsFinder, findsOneWidget);
    expect(find.byTooltip('刷新推荐任务'), findsOneWidget);
    expect(find.byTooltip('添加到今天'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('即将到期的任务')), findsOneWidget);
    final panelNode = tester.getSemantics(panelSemanticsFinder);
    final refreshNode = tester.getSemantics(find.byTooltip('刷新推荐任务'));
    final taskNode = tester.getSemantics(find.text('即将到期的任务'));
    expect(refreshNode.id, isNot(panelNode.id));
    expect(taskNode.id, isNot(panelNode.id));
    expect(taskNode.id, isNot(refreshNode.id));
    expect(find.text('即将到期的任务'), findsOneWidget);
    expect(find.text('即将到期'), findsOneWidget);
    await tester.tap(find.text('即将到期的任务'));
    expect(selected, 7);
    expect(addedToToday, isNull);
    await tester.tap(find.byTooltip('添加到今天'));
    await tester.pumpAndSettle();
    expect(addedToToday, 7);
    expect(selected, 7);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    semantics.dispose();
  });

  testWidgets('刷新失败时保留缓存并通过 live region 说明恢复状态', (tester) async {
    final semantics = tester.ensureSemantics();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '即将到期的任务',
            reasonCode: 'DUE_SOON',
            reason: '即将到期',
            score: 900,
            refreshedAt: DateTime.utc(2026, 7, 16),
          ),
        );
    final repository = RecommendationRepository(
      db,
      _OfflineRecommendationApi(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationPanel(
              onTaskSelected: (_) {},
              onAddToToday: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('即将到期的任务'), findsOneWidget);
    expect(find.text('刷新推荐任务失败，已保留上次结果'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('刷新推荐任务失败，已保留上次结果')),
      matchesSemantics(label: '刷新推荐任务失败，已保留上次结果', isLiveRegion: true),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    semantics.dispose();
  });

  testWidgets('重试成功后清除刷新失败状态', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '缓存任务',
            reasonCode: 'DUE_SOON',
            reason: '即将到期',
            score: 900,
            refreshedAt: DateTime.utc(2026, 7, 16),
          ),
        );
    final repository = RecommendationRepository(
      db,
      _RecoveringRecommendationApi(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationPanel(
              onTaskSelected: (_) {},
              onAddToToday: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('刷新推荐任务失败，已保留上次结果'), findsOneWidget);

    await tester.tap(find.byTooltip('刷新推荐任务'));
    await tester.pumpAndSettle();

    expect(find.text('刷新推荐任务失败，已保留上次结果'), findsNothing);
    expect(find.text('已恢复的任务'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('刷新进行中复用同一请求并在完成后允许再次刷新', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '缓存任务',
            reasonCode: 'DUE_SOON',
            reason: '即将到期',
            score: 900,
            refreshedAt: DateTime.utc(2026, 7, 16),
          ),
        );
    final api = _BlockingRecommendationApi();
    final repository = RecommendationRepository(db, api);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recommendationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RecommendationPanel(
                onTaskSelected: (_) {},
                onAddToToday: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(api.calls, 1);

      await tester.tap(find.byTooltip('刷新推荐任务'));
      await tester.tap(find.byTooltip('刷新推荐任务'));
      await tester.pump();

      expect(api.calls, 1);
      api.completeNext(_recommendations);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('刷新推荐任务'));
      await tester.pump();
      expect(api.calls, 2);
      api.completeNext(_recommendations);
      await tester.pumpAndSettle();
    } finally {
      api.completeAll(_recommendations);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });

  testWidgets('添加到今天失败时保留推荐并发布可恢复的 live region', (tester) async {
    final semantics = tester.ensureSemantics();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '待安排任务',
            reasonCode: 'LONG_UNFINISHED',
            reason: '长期未完成',
            score: 800,
            refreshedAt: DateTime.utc(2026, 8, 2),
          ),
        );
    final repository = RecommendationRepository(
      db,
      _OfflineRecommendationApi(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationPanel(
              onTaskSelected: (_) {},
              onAddToToday: (_) =>
                  Future<void>.error(StateError('write failed')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加到今天'));
    await tester.pumpAndSettle();

    expect(find.text('待安排任务'), findsOneWidget);
    expect(find.text('添加到今天失败，请重试'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('添加到今天失败，请重试')),
      matchesSemantics(label: '添加到今天失败，请重试', isLiveRegion: true),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    semantics.dispose();
  });

  testWidgets('添加到今天进行中禁用按钮并忽略重复点击', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '待安排任务',
            reasonCode: 'LONG_UNFINISHED',
            reason: '长期未完成',
            score: 800,
            refreshedAt: DateTime.utc(2026, 8, 2),
          ),
        );
    final repository = RecommendationRepository(
      db,
      _OfflineRecommendationApi(),
    );
    final completion = Completer<void>();
    var calls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationPanel(
              onTaskSelected: (_) {},
              onAddToToday: (_) {
                calls++;
                return completion.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == '添加到今天',
    );
    try {
      await tester.tap(addButton);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<IconButton>(addButton).onPressed, isNull);
      await tester.tap(addButton);
      await tester.pump();
      expect(calls, 1);
    } finally {
      if (!completion.isCompleted) completion.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}

const _recommendations = [
  RecommendationTask(
    taskServerId: 8,
    title: '已刷新的任务',
    reasonCode: 'RECENTLY_ADDED',
    reason: '最近添加',
    score: 700,
  ),
];

class _OfflineRecommendationApi extends RecommendationApi {
  _OfflineRecommendationApi() : super(ApiClient());

  @override
  Future<List<RecommendationTask>> list({int limit = 10}) =>
      Future<List<RecommendationTask>>.error(StateError('offline'));
}

class _RecoveringRecommendationApi extends RecommendationApi {
  _RecoveringRecommendationApi() : super(ApiClient());

  var _calls = 0;

  @override
  Future<List<RecommendationTask>> list({int limit = 10}) async {
    _calls++;
    if (_calls == 1) throw StateError('offline');
    return const [
      RecommendationTask(
        taskServerId: 8,
        title: '已恢复的任务',
        reasonCode: 'RECENTLY_ADDED',
        reason: '最近添加',
        score: 700,
      ),
    ];
  }
}

class _BlockingRecommendationApi extends RecommendationApi {
  _BlockingRecommendationApi() : super(ApiClient());

  final _pending = <Completer<List<RecommendationTask>>>[];
  var calls = 0;

  @override
  Future<List<RecommendationTask>> list({int limit = 10}) {
    calls++;
    final request = Completer<List<RecommendationTask>>();
    _pending.add(request);
    return request.future;
  }

  void completeNext(List<RecommendationTask> recommendations) {
    _pending.removeAt(0).complete(recommendations);
  }

  void completeAll(List<RecommendationTask> recommendations) {
    for (final request in _pending) {
      if (!request.isCompleted) request.complete(recommendations);
    }
    _pending.clear();
  }
}
