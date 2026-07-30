import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/recommendation_repository.dart';

void main() {
  test('刷新推荐任务会落入 Drift 缓存，并保留可解释原因和排序', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = RecommendationRepository(
      db,
      _FakeRecommendationApi([
        RecommendationTask(
          taskServerId: 7,
          title: '即将到期的任务',
          dueAt: DateTime.utc(2026, 7, 17, 8),
          reasonCode: 'DUE_SOON',
          reason: '即将到期',
          score: 900,
        ),
        RecommendationTask(
          taskServerId: 8,
          title: '多次改期的任务',
          reasonCode: 'REPEATEDLY_RESCHEDULED',
          reason: '已多次改期，建议重新安排',
          score: 1002,
        ),
        RecommendationTask(
          taskServerId: 9,
          title: '长期未完成的任务',
          reasonCode: 'LONG_UNFINISHED',
          reason: '已超过 14 天未完成',
          score: 800,
        ),
        RecommendationTask(
          taskServerId: 10,
          title: '最近添加的任务',
          reasonCode: 'RECENTLY_ADDED',
          reason: '刚刚添加，建议安排下一步',
          score: 700,
        ),
      ]),
    );

    await repository.refresh();
    final cached = await repository.watchAll().first;

    expect(cached.map((item) => item.taskServerId), [8, 7, 9, 10]);
    expect(cached.map((item) => item.reasonCode), [
      'REPEATEDLY_RESCHEDULED',
      'DUE_SOON',
      'LONG_UNFINISHED',
      'RECENTLY_ADDED',
    ]);
    expect(cached.first.reasonCode, 'REPEATEDLY_RESCHEDULED');
    expect(cached.first.reason, '已多次改期，建议重新安排');
    expect(cached[1].dueAt?.toUtc(), DateTime.utc(2026, 7, 17, 8));
    expect(cached[2].reason, '已超过 14 天未完成');
    expect(cached.last.reason, '刚刚添加，建议安排下一步');
  });

  test('推荐读取失败时不覆盖已有的 Drift 缓存', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = RecommendationRepository(
      db,
      _FakeRecommendationApi(const [], fail: true),
    );
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '已缓存任务',
            reasonCode: 'DUE_SOON',
            reason: '即将到期',
            score: 900,
            refreshedAt: DateTime.utc(2026, 7, 16),
          ),
        );

    await expectLater(repository.refresh(), throwsStateError);
    final cached = await repository.watchAll().first;

    expect(cached.single.title, '已缓存任务');
  });

  test('成功返回空推荐时会替换并清空过期 Drift 缓存', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = RecommendationRepository(
      db,
      _FakeRecommendationApi(const []),
    );
    await db
        .into(db.todoRecommendations)
        .insert(
          TodoRecommendationsCompanion.insert(
            taskServerId: const Value(7),
            title: '已过期推荐',
            reasonCode: 'DUE_SOON',
            reason: '即将到期',
            score: 900,
            refreshedAt: DateTime.utc(2026, 7, 16),
          ),
        );

    await repository.refresh();

    expect(await repository.watchAll().first, isEmpty);
  });
}

class _FakeRecommendationApi extends RecommendationApi {
  _FakeRecommendationApi(this.items, {this.fail = false}) : super(ApiClient());

  final List<RecommendationTask> items;
  final bool fail;

  @override
  Future<List<RecommendationTask>> list({int limit = 10}) async {
    if (fail) throw StateError('offline');
    return items;
  }
}
