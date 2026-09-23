import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/home/recommendation_page.dart';
import 'package:zh_cloud_todo_flutter/features/home/recommendation_panel.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/recommendation_repository.dart';

/// 嘀嗒《推荐任务》：独立页按四类分组，行内「+」添加到今天，点行进任务详情。
void main() {
  final today = DateTime(2026, 9, 23, 9);

  Future<AppDatabase> seedDb(
    WidgetTester tester,
    List<
      ({
        int id,
        String title,
        String code,
        String reason,
        DateTime? dueAt,
        int score,
      })
    >
    rows,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final row in rows) {
      await db
          .into(db.todoRecommendations)
          .insert(
            TodoRecommendationsCompanion.insert(
              taskServerId: Value(row.id),
              title: row.title,
              dueAt: Value(row.dueAt),
              reasonCode: row.code,
              reason: row.reason,
              score: row.score,
              refreshedAt: DateTime.utc(2026, 9, 23),
            ),
          );
    }
    return db;
  }

  Future<RecommendationRepository> pumpPage(
    WidgetTester tester, {
    required AppDatabase db,
    RecommendationApi? api,
    Size size = const Size(760, 900),
    void Function(int)? onTaskSelected,
    Future<void> Function(int)? onAddToToday,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = RecommendationRepository(
      db,
      api ?? _OfflineRecommendationApi(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: RecommendationPage(
            now: () => today,
            onTaskSelected: onTaskSelected ?? (_) {},
            onAddToToday: onAddToToday ?? (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  /// Drift 在 StreamBuilder 退订时会排一个 zero-delay 的关闭定时器，
  /// 用例结尾必须先卸载再推一帧把它跑掉，否则报 `A Timer is still pending`。
  Future<void> settleDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('推荐任务独立页', () {
    testWidgets('四类成组且顺序照嘀嗒，空组不占位', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 3,
          title: '搁置很久的重构',
          code: 'LONG_UNFINISHED',
          reason: '已超过 14 天未完成',
          dueAt: null,
          score: 800,
        ),
        (
          id: 1,
          title: '刚加的调研',
          code: 'RECENTLY_ADDED',
          reason: '刚刚添加，建议安排下一步',
          dueAt: null,
          score: 700,
        ),
        (
          id: 4,
          title: '明天的评审',
          code: 'DUE_SOON',
          reason: '即将到期',
          dueAt: DateTime(2026, 9, 24, 10),
          score: 900,
        ),
      ]);

      await pumpPage(tester, db: db);

      expect(find.byKey(const ValueKey('recommendation-page')), findsOneWidget);
      expect(find.textContaining('最近添加'), findsOneWidget);
      expect(find.textContaining('长时间未完成'), findsOneWidget);
      expect(find.textContaining('即将到来'), findsOneWidget);
      expect(
        find.textContaining('多次修改时间'),
        findsNothing,
        reason: '嘀嗒没有这一类的候选时不摆空组',
      );

      final order = tester
          .widgetList<Text>(find.textContaining(RegExp('最近添加|长时间未完成|即将到来')))
          .map((text) => text.data!.split('（').first)
          .toList();
      expect(order, [
        '最近添加',
        '长时间未完成',
        '即将到来',
      ], reason: '分组顺序是嘀嗒的信息架构，不是本地按分数排');
      await settleDown(tester);
    });

    testWidgets('即将到来按 dueAt 拆明天/后天（当前契约唯一能算的子档）', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 11,
          title: '明天交付',
          code: 'DUE_SOON',
          reason: '即将到期',
          dueAt: DateTime(2026, 9, 24, 9),
          score: 900,
        ),
        (
          id: 12,
          title: '后天交付',
          code: 'DUE_SOON',
          reason: '即将到期',
          dueAt: DateTime(2026, 9, 25, 9),
          score: 900,
        ),
        (
          id: 13,
          title: '大后天交付',
          code: 'DUE_SOON',
          reason: '即将到期',
          dueAt: DateTime(2026, 9, 26, 9),
          score: 900,
        ),
      ]);

      await pumpPage(tester, db: db);

      expect(
        find.byKey(const ValueKey('recommendation-bucket-tomorrow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recommendation-bucket-day-after')),
        findsOneWidget,
      );
      expect(find.text('明天'), findsOneWidget);
      expect(find.text('后天'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recommendation-item-11')),
        findsOneWidget,
        reason: '明天到期要落进「明天」子档',
      );
      expect(
        find.byKey(const ValueKey('recommendation-item-12')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recommendation-item-13')),
        findsOneWidget,
        reason: '超出明天/后天两档的仍要留在组里，不能被静默丢掉',
      );
      await settleDown(tester);
    });

    testWidgets('点行进任务详情：把本地 serverId 交给回调', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 21,
          title: '多次改期的验收',
          code: 'REPEATEDLY_RESCHEDULED',
          reason: '已多次改期，建议重新安排',
          dueAt: null,
          score: 1003,
        ),
      ]);
      int? selected;
      await pumpPage(tester, db: db, onTaskSelected: (id) => selected = id);

      await tester.tap(find.byKey(const ValueKey('recommendation-item-21')));
      await tester.pumpAndSettle();

      expect(selected, 21);
      await settleDown(tester);
    });

    testWidgets('「+」添加到今天：在飞只提交一次，完成后该行消失', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 31,
          title: '待安排任务',
          code: 'RECENTLY_ADDED',
          reason: '刚刚添加，建议安排下一步',
          dueAt: null,
          score: 700,
        ),
      ]);
      final completion = Completer<void>();
      var calls = 0;
      final repository = await pumpPage(
        tester,
        db: db,
        onAddToToday: (_) {
          calls++;
          return completion.future;
        },
      );

      final addButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.key == const ValueKey('recommendation-add-31'),
      );
      await tester.tap(addButton);
      await tester.pump();
      expect(calls, 1);
      expect(
        tester.widget<IconButton>(addButton).onPressed,
        isNull,
        reason: '「+」在飞必须变禁用态：这是重复点击的唯一屏障（早退守卫是死代码，摘了探针仍绿）',
      );
      await tester.tap(addButton);
      await tester.pump();
      expect(calls, 1);

      completion.complete();
      await tester.pumpAndSettle();
      await repository.removeTask(31);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recommendation-item-31')),
        findsNothing,
        reason: '服务端返回后该行不再是候选，不能再被添加',
      );
      await settleDown(tester);
    });

    testWidgets('添加到今天失败：行还在、要说出来并能重试', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 41,
          title: '失败也要留痕',
          code: 'LONG_UNFINISHED',
          reason: '已超过 14 天未完成',
          dueAt: null,
          score: 800,
        ),
      ]);
      await pumpPage(
        tester,
        db: db,
        onAddToToday: (_) => Future<void>.error(StateError('write failed')),
      );

      await tester.tap(find.byKey(const ValueKey('recommendation-add-41')));
      await tester.pumpAndSettle();

      expect(find.textContaining('添加到今天失败'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recommendation-item-41')),
        findsOneWidget,
        reason: '失败不能把已加载的推荐抹掉',
      );
      await settleDown(tester);
    });

    testWidgets('刷新失败保留分组结果并说明', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 51,
          title: '缓存里的推荐',
          code: 'DUE_SOON',
          reason: '即将到期',
          dueAt: DateTime(2026, 9, 24, 9),
          score: 900,
        ),
      ]);
      await pumpPage(tester, db: db, api: _OfflineRecommendationApi());

      await tester.tap(find.byTooltip('刷新推荐任务'));
      await tester.pumpAndSettle();

      expect(find.text('缓存里的推荐'), findsOneWidget);
      expect(find.textContaining('刷新推荐任务失败'), findsOneWidget);
      await settleDown(tester);
    });

    testWidgets('入口在推荐面板标题行，点开就是独立页', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 61,
          title: '面板里的推荐',
          code: 'RECENTLY_ADDED',
          reason: '刚刚添加，建议安排下一步',
          dueAt: null,
          score: 700,
        ),
      ]);
      final repository = RecommendationRepository(
        db,
        _OfflineRecommendationApi(),
      );
      tester.view.physicalSize = const Size(760, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

      await tester.tap(find.byTooltip('查看推荐任务'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('recommendation-page')),
        findsOneWidget,
        reason: '面板只摊前几条，嘀嗒的完整四类要在独立页里看',
      );
      await settleDown(tester);
    });

    testWidgets('320px + 1.3 倍字体：页面自身继承档位且不溢出', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 71,
          title: '一条非常长足以在窄屏挤爆标题栏的推荐任务名称',
          code: 'REPEATEDLY_RESCHEDULED',
          reason: '已多次改期，建议重新安排',
          dueAt: null,
          score: 1099,
        ),
      ]);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPage(tester, db: db, size: const Size(320, 640));

      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const ValueKey('recommendation-page'))),
        ).scale(10),
        closeTo(13, 0.001),
        reason: '档位没传进页面就等于整条用例在 1.0 上排版',
      );
      expect(tester.takeException(), isNull);
      await settleDown(tester);
    });

    testWidgets('组标题与每条任务各自成读屏节点', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final db = await seedDb(tester, [
          (
            id: 81,
            title: '读屏可见的推荐',
            code: 'RECENTLY_ADDED',
            reason: '刚刚添加，建议安排下一步',
            dueAt: null,
            score: 700,
          ),
        ]);
        await pumpPage(tester, db: db);

        final groupNode = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^最近添加')),
        );
        expect(
          groupNode.hasFlag(SemanticsFlag.isHeader),
          isTrue,
          reason: '组标题要标成 header，读屏才知道它是标题而不是正文',
        );
        expect(
          find.bySemanticsLabel(RegExp('^最近添加')),
          findsOneWidget,
          reason: '组标题要被念出来，且带上组内条数',
        );
        final taskNode = tester.getSemantics(
          find.byKey(const ValueKey('recommendation-item-81')),
        );
        expect(taskNode.label, contains('读屏可见的推荐'));
        expect(
          find.bySemanticsLabel(RegExp('^添加到今天')),
          findsWidgets,
          reason: '「+」是动作，不能只是个没有名字的图标',
        );
        await settleDown(tester);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('四组全空给空态，不是一片白', (tester) async {
      final db = await seedDb(tester, const []);
      await pumpPage(tester, db: db);

      expect(find.byKey(const ValueKey('recommendation-page')), findsOneWidget);
      expect(
        find.textContaining('暂无'),
        findsOneWidget,
        reason: '没有推荐也要说清楚，而不是空页面',
      );
      await settleDown(tester);
    });
  });
}

class _OfflineRecommendationApi extends RecommendationApi {
  _OfflineRecommendationApi() : super(ApiClient());

  @override
  Future<List<RecommendationTask>> list({int limit = 10}) =>
      Future<List<RecommendationTask>>.error(StateError('offline'));
}
