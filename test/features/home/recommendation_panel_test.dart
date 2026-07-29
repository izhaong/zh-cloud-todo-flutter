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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecommendationPanel(
              onTaskSelected: (taskId) => selected = taskId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('推荐任务'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('推荐任务')), findsOneWidget);
    expect(find.text('即将到期的任务'), findsOneWidget);
    expect(find.text('即将到期'), findsOneWidget);
    await tester.tap(find.text('即将到期的任务'));
    expect(selected, 7);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    semantics.dispose();
  });
}

class _OfflineRecommendationApi extends RecommendationApi {
  _OfflineRecommendationApi() : super(ApiClient());

  @override
  Future<List<RecommendationTask>> list({int limit = 10}) =>
      Future<List<RecommendationTask>>.error(StateError('offline'));
}
