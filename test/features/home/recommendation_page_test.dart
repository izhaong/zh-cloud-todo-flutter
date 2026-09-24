import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
    RecommendationRepository? repository,
    Size size = const Size(760, 900),
    void Function(int)? onTaskSelected,
    Future<void> Function(int)? onAddToToday,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final resolvedRepository =
        repository ??
        RecommendationRepository(db, api ?? _OfflineRecommendationApi());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(
            resolvedRepository,
          ),
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
    return resolvedRepository;
  }

  /// Drift 在 StreamBuilder 退订时会排一个 zero-delay 的关闭定时器，
  /// 用例结尾必须先卸载再推一帧把它跑掉，否则报 `A Timer is still pending`。
  Future<void> settleDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('推荐任务独立页', () {
    testWidgets('四类成组且顺序照嘀嗒，中间空组不占位', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 1,
          title: '刚加的调研',
          code: 'RECENTLY_ADDED',
          reason: '刚刚添加，建议安排下一步',
          dueAt: null,
          score: 700,
        ),
        (
          id: 2,
          title: '改了三次期的申报',
          code: 'REPEATEDLY_RESCHEDULED',
          reason: '已多次改期，建议重新安排',
          dueAt: null,
          score: 1003,
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
      expect(find.textContaining('多次修改时间'), findsOneWidget);
      expect(find.textContaining('即将到来'), findsOneWidget);
      expect(
        find.textContaining('长时间未完成'),
        findsNothing,
        reason: '嘀嗒没有这一类的候选时不摆空组（本例故意抽掉中间那一组）',
      );

      final order = tester
          .widgetList<Text>(
            find.textContaining(RegExp('最近添加|多次修改时间|长时间未完成|即将到来')),
          )
          .map((text) => text.data!.split('（').first)
          .toList();
      expect(
        order,
        ['最近添加', '多次修改时间', '即将到来'],
        reason:
            '分组顺序是嘀嗒的信息架构：「多次修改时间」固定占第二档，'
            '不是本地按分数排（本例它的 score 最高，若按分数排就会跳到第一位）',
      );
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
          // 故意比「明天」高：仓储按 score desc 返回，「后天」会先回来。
          // 若子档顺序跟着数据走，后面两条顺序断言就会红。
          dueAt: DateTime(2026, 9, 25, 9),
          score: 910,
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

      const tomorrow = ValueKey('recommendation-bucket-tomorrow');
      const dayAfter = ValueKey('recommendation-bucket-day-after');
      expect(find.byKey(tomorrow), findsOneWidget);
      expect(find.byKey(dayAfter), findsOneWidget);
      expect(find.text('明天'), findsOneWidget);
      expect(find.text('后天'), findsOneWidget);
      // 断「这一行属于这一档」，不是断「两档和两行都在树里」：
      // 后者在 明天↔后天 互换时仍然全绿（键都还在、文案都还找得到）。
      expect(
        find.descendant(
          of: find.byKey(tomorrow),
          matching: find.byKey(const ValueKey('recommendation-item-11')),
        ),
        findsOneWidget,
        reason: '9/24 到期必须落在「明天」这一档内部，而不是只落在同一个组里',
      );
      expect(
        find.descendant(
          of: find.byKey(dayAfter),
          matching: find.byKey(const ValueKey('recommendation-item-12')),
        ),
        findsOneWidget,
        reason: '9/25 到期必须落在「后天」这一档内部',
      );
      expect(
        find.descendant(
          of: find.byKey(tomorrow),
          matching: find.byKey(const ValueKey('recommendation-item-12')),
        ),
        findsNothing,
        reason: '两档互换时上面的正向断言会同时骗人，这条把互换钉死',
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('recommendation-item-11')))
            .top,
        lessThan(
          tester
              .getRect(find.byKey(const ValueKey('recommendation-item-12')))
              .top,
        ),
        reason: '嘀嗒是 明天 → 后天；「后天」分数更高也不能排到前面',
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
        reason: '「+」在飞要变禁用态：这是**跨帧**重复点击的屏障（同帧靠 _addToToday 的早退守卫）',
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

    testWidgets('同一帧内连点两次「+」：早退守卫要挡住第二次', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 32,
          title: '双击就重复安排的任务',
          code: 'RECENTLY_ADDED',
          reason: '刚刚添加，建议安排下一步',
          dueAt: null,
          score: 700,
        ),
      ]);
      final completion = Completer<void>();
      var calls = 0;
      await pumpPage(
        tester,
        db: db,
        onAddToToday: (_) {
          calls++;
          return completion.future;
        },
      );

      final addButton = find.byKey(const ValueKey('recommendation-add-32'));
      // 两次 tap 之间不 pump ⇒ 不重排版，第二次的命中目标仍是**上一次 build 里
      // onPressed 非 null** 的那个按钮：禁用态这时救不了，只有早退守卫能。
      await tester.tap(addButton);
      await tester.tap(addButton);
      await tester.pump();

      expect(calls, 1, reason: '同一帧两次点击各跑一遍 handler，会把同一任务安排两次');
      if (!completion.isCompleted) completion.complete();
      await tester.pumpAndSettle();
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
      int? selected;
      int? addedToToday;
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
                onTaskSelected: (id) => selected = id,
                onAddToToday: (id) async => addedToToday = id,
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
      // 独立页必须把面板自己的两个回调传下去（首页那套打开详情/添加到今天的动作
      // 是 home_shell 给的）：只断「页面出现了」的话，把回调换成空函数照样绿。
      await tester.tap(find.byKey(const ValueKey('recommendation-item-61')));
      await tester.pumpAndSettle();
      expect(selected, 61, reason: '点独立页的行程要落到面板同一个任务详情回调');

      await tester.tap(find.byKey(const ValueKey('recommendation-add-61')));
      await tester.pumpAndSettle();
      expect(addedToToday, 61, reason: '「+」也要转发到面板回调：否则会绕过首页成功后的移除逻辑');
      await settleDown(tester);
    });

    testWidgets('320px + 1.3 倍字体：页面自身继承档位且不溢出', (tester) async {
      final db = await seedDb(tester, [
        (
          id: 71,
          title: '一条非常长足以在窄屏挤爆标题栏的推荐任务名称',
          // 必须走 `DUE_SOON` + 明天：第 11 轮此前种的是 `REPEATEDLY_RESCHEDULED`/`dueAt: null`，
          // 数据根本不经过子档那个 `Column`（复核员在 /tmp 副本上往该 Column 注入溢出，
          // 原用用例照样绿 ⇒ 覆盖缺口）。
          code: 'DUE_SOON',
          reason: '即将到期',
          dueAt: DateTime(2026, 9, 24, 9),
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
      expect(
        find.byKey(const ValueKey('recommendation-bucket-tomorrow')),
        findsOneWidget,
        reason: '数据得真的经过子档容器，否则"这条用例覆盖了新布局"就是假的',
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

        // 不用 matchesSemantics：节点 textDirection 为 null 时它的 describeMismatch
        // 自己会抛 `Null is not a subtype of String`，把真实差异盖掉。
        expect(
          tester
              .widgetList<Semantics>(
                find.ancestor(
                  of: find.textContaining('最近添加'),
                  matching: find.byType(Semantics),
                ),
              )
              .any((widget) => widget.properties.header == true),
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
          findsOneWidget,
          reason:
              '「+」是动作，不能只是个没有名字的图标；'
              '外层 `Semantics(container+label)` + 内层 `ExcludeSemantics` 必须只留一个节点，'
              '多一个（例如 tooltip 自己成节点）就说明这层包装是重复暴露',
        );
        await settleDown(tester);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('子档标题「明天」也是 header 节点，读屏不会只念组标题', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final db = await seedDb(tester, [
          (
            id: 82,
            title: '明天的评审',
            code: 'DUE_SOON',
            reason: '即将到期',
            dueAt: DateTime(2026, 9, 24, 9),
            score: 900,
          ),
        ]);
        await pumpPage(tester, db: db);

        final bucketFinder = find.ancestor(
          of: find.text('明天'),
          matching: find.byType(Semantics),
        );
        expect(
          tester
              .widgetList<Semantics>(bucketFinder)
              .any((widget) => widget.properties.header == true),
          isTrue,
          reason:
              '第 11 轮此前只 seed 了 RECENTLY_ADDED 一组 ⇒ 子档标题是裸 Text，'
              '读屏念得出"即将到来"却念不出"明天"这一档的层级',
        );
        expect(find.bySemanticsLabel(RegExp('^明天')), findsOneWidget);
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

    testWidgets('缓存流自己报错：说「读取失败」而不是伪装成没有推荐', (tester) async {
      final db = await seedDb(tester, const []);
      await pumpPage(
        tester,
        db: db,
        repository: _FailingStreamRecommendationRepository(db),
      );

      expect(
        find.textContaining('读取推荐任务失败'),
        findsOneWidget,
        reason: '快照有错误时 data 为 null，与「真的没有推荐」在界面上必须可分辨',
      );
      expect(
        find.textContaining('暂无'),
        findsNothing,
        reason: '把失败念成「暂无推荐任务」会让用户以为真的没有任务',
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

/// 真实场景是「provider 被换成绑定已关闭 DB 的仓储」，Drift 关库后抛什么类型不该由用例赌；
/// 这里钉住的是**同一条通道**：`watchAll()` 返回的流抛错。
class _FailingStreamRecommendationRepository extends RecommendationRepository {
  _FailingStreamRecommendationRepository(AppDatabase db)
    : super(db, _OfflineRecommendationApi());

  @override
  Stream<List<TodoRecommendation>> watchAll() =>
      Stream<List<TodoRecommendation>>.error(StateError('database closed'));
}
