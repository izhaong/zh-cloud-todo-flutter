import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/note/note_page.dart';
import 'package:zh_cloud_todo_flutter/features/note/task_summary.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/note_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/summary_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 与 `TodoVisualFixture` 的 `fixedNow` 对齐；摘要区间全部以它为锚点。
final _now = DateTime(2026, 7, 11, 9);

SummaryTaskRow _row({
  required String taskId,
  required String title,
  String listId = 'sum-l1',
  String listName = '摘要工作',
  bool completed = false,
  DateTime? completedAt,
  DateTime? dueAt,
  DateTime? createdAt,
  int checklistDone = 0,
  int checklistTotal = 0,
  int subtaskDone = 0,
  int subtaskTotal = 0,
}) {
  return SummaryTaskRow(
    taskId: taskId,
    title: title,
    listId: listId,
    listName: listName,
    completed: completed,
    completedAt: completedAt,
    dueAt: dueAt,
    createdAt: createdAt ?? DateTime(2026, 7, 8),
    sortOrder: 0,
    checklistDone: checklistDone,
    checklistTotal: checklistTotal,
    subtaskDone: subtaskDone,
    subtaskTotal: subtaskTotal,
  );
}

TaskSummaryRange _lastSevenDays({
  TaskSummaryPreset preset = TaskSummaryPreset.lastSevenDays,
}) => summaryRangeForPreset(preset, _now);

void main() {
  group('摘要区间', () {
    test('近 7 天以今天为末位，含当日 00:00 到次日 00:00 的左闭右开区间', () {
      final range = summaryRangeForPreset(
        TaskSummaryPreset.lastSevenDays,
        _now,
      );
      expect(range.from, DateTime(2026, 7, 5));
      expect(range.to, DateTime(2026, 7, 12));
      expect(range.label, '近 7 天');
      expect('${range.from.month}-${range.to.day}', '7-12');
    });

    test('今天 / 本月分别落在日与月边界', () {
      final today = summaryRangeForPreset(TaskSummaryPreset.today, _now);
      expect(today.from, DateTime(2026, 7, 11));
      expect(today.to, DateTime(2026, 7, 12));
      expect(today.label, '今天');

      final month = summaryRangeForPreset(TaskSummaryPreset.thisMonth, _now);
      expect(month.from, DateTime(2026, 7, 1));
      expect(month.to, DateTime(2026, 8, 1));
      expect(month.label, '本月');
    });

    test('自定义区间按整天对齐，且始终保留 from<=to', () {
      final range = summaryRangeForPreset(
        TaskSummaryPreset.custom,
        _now,
        customFrom: DateTime(2026, 7, 3, 23, 30),
        customTo: DateTime(2026, 7, 4, 1),
      );
      expect(range.from, DateTime(2026, 7, 3));
      expect(range.to, DateTime(2026, 7, 5));
      expect(range.label, '自定义');
    });
  });

  group('摘要文本', () {
    test('默认口径：按清单分组、时间倒序、显示完成日期与进度，逐字节确定', () {
      final text =
          buildTaskSummary(TaskSummaryOptions(range: _lastSevenDays()), [
            _row(
              taskId: 'a',
              title: '写周报',
              completed: true,
              completedAt: DateTime(2026, 7, 9, 18),
              checklistDone: 2,
              checklistTotal: 3,
            ),
            _row(taskId: 'b', title: '评审 PR', createdAt: DateTime(2026, 7, 8)),
            _row(
              taskId: 'c',
              title: '买牛奶',
              listId: 'sum-l2',
              listName: '个人',
              completed: true,
              completedAt: DateTime(2026, 7, 11, 8),
            ),
          ]);

      expect(
        text,
        [
          '## 任务摘要 · 近 7 天（2026-07-05 ~ 2026-07-11）',
          '',
          '已完成 2 项 · 未完成 1 项',
          '',
          '### 个人',
          '- [x] 买牛奶 · 完成于 07-11',
          '',
          '### 摘要工作',
          '- [x] 写周报 · 完成于 07-09 · 进度 2/3',
          '- [ ] 评审 PR',
        ].join('\n'),
        reason: '清单按名称排序；组内按发生时间倒序；无检查事项与子任务的行不输出进度',
      );
    });

    test('不分组时每行带清单名，避免丢失归属信息', () {
      final text = buildTaskSummary(
        TaskSummaryOptions(
          range: _lastSevenDays(),
          group: SummaryGroupMode.none,
        ),
        [
          _row(taskId: 'a', title: '写周报'),
          _row(
            taskId: 'c',
            title: '买牛奶',
            listId: 'sum-l2',
            listName: '个人',
            createdAt: DateTime(2026, 7, 10),
          ),
        ],
      );

      expect(text, contains('- [ ] 买牛奶 · 个人'));
      expect(text, contains('- [ ] 写周报 · 摘要工作'));
      expect(text, isNot(contains('### ')));
    });

    test('按完成状态分组时先已完成再未完成', () {
      final text = buildTaskSummary(
        TaskSummaryOptions(
          range: _lastSevenDays(),
          group: SummaryGroupMode.byStatus,
        ),
        [
          _row(taskId: 'a', title: '写周报'),
          _row(
            taskId: 'b',
            title: '复盘会议',
            completed: true,
            completedAt: DateTime(2026, 7, 10, 9),
          ),
        ],
      );

      final summary = text!;
      final lines = summary.split('\n');
      expect(lines.indexOf('### 已完成') < lines.indexOf('### 未完成'), isTrue);
      expect(
        summary.indexOf('- [x] 复盘会议') < summary.indexOf('- [ ] 写周报'),
        isTrue,
      );
    });

    test('进度优先检查事项，无检查事项时退到子任务', () {
      final text =
          buildTaskSummary(TaskSummaryOptions(range: _lastSevenDays()), [
            _row(
              taskId: 'a',
              title: '检查事项优先',
              checklistDone: 1,
              checklistTotal: 4,
              subtaskDone: 3,
              subtaskTotal: 3,
            ),
            _row(
              taskId: 'b',
              title: '只有子任务',
              createdAt: DateTime(2026, 7, 10),
              subtaskDone: 2,
              subtaskTotal: 5,
            ),
          ]);
      expect(text, contains('- [ ] 检查事项优先 · 进度 1/4'));
      expect(text, contains('- [ ] 只有子任务 · 进度 2/5'));
    });

    test('清单筛选与状态筛选各自生效，且计数只统计筛选后的集合', () {
      final rows = [
        _row(
          taskId: 'a',
          title: '写周报',
          completed: true,
          completedAt: DateTime(2026, 7, 9),
        ),
        _row(
          taskId: 'c',
          title: '买牛奶',
          listId: 'sum-l2',
          listName: '个人',
          createdAt: DateTime(2026, 7, 10),
        ),
      ];

      final onlyWork = buildTaskSummary(
        TaskSummaryOptions(range: _lastSevenDays(), listIds: {'sum-l1'}),
        rows,
      );
      expect(onlyWork, contains('写周报'));
      expect(onlyWork, isNot(contains('买牛奶')));

      final onlyDone = buildTaskSummary(
        TaskSummaryOptions(range: _lastSevenDays(), completed: true),
        rows,
      );
      expect(onlyDone, contains('已完成 1 项'));
      expect(onlyDone, isNot(contains('未完成')));
      expect(onlyDone, isNot(contains('买牛奶')));
    });

    test('筛选后为空返回 null，交给界面禁用插入而不是塞占位符', () {
      expect(
        buildTaskSummary(
          TaskSummaryOptions(range: _lastSevenDays(), listIds: {'不存在的清单'}),
          [_row(taskId: 'a', title: '写周报')],
        ),
        isNull,
      );
      expect(
        buildTaskSummary(TaskSummaryOptions(range: _lastSevenDays()), []),
        isNull,
      );
    });

    test('标题排序按标题字典序，时间排序按发生时间倒序', () {
      final rows = [
        _row(taskId: 'a', title: 'beta', createdAt: DateTime(2026, 7, 10)),
        _row(taskId: 'b', title: 'alpha', createdAt: DateTime(2026, 7, 6)),
      ];
      final byTitle = buildTaskSummary(
        TaskSummaryOptions(
          range: _lastSevenDays(),
          group: SummaryGroupMode.none,
          sort: SummarySortMode.title,
        ),
        rows,
      )!;
      expect(byTitle.indexOf('alpha') < byTitle.indexOf('beta'), isTrue);

      final byTime = buildTaskSummary(
        TaskSummaryOptions(
          range: _lastSevenDays(),
          group: SummaryGroupMode.none,
        ),
        rows,
      )!;
      expect(byTime.indexOf('beta') < byTime.indexOf('alpha'), isTrue);
    });
  });

  group('摘要取数', () {
    testWidgets('区间归属：已完成看 completedAt、未完成看到期日、无到期退回创建日，取消任务永不进', (
      tester,
    ) async {
      final fixture = await _pump(tester, home: const SizedBox.shrink());
      await _seedSummaryTasks(fixture.database);
      final repo = fixture.container.read(summaryRepositoryProvider)!;

      final range = _lastSevenDays();
      final rows = await repo.loadInRange(from: range.from, to: range.to);
      final titles = rows.map((row) => row.title).toSet();

      expect(titles, {
        '摘要区间内已完成',
        '摘要区间内无到期按创建',
        '摘要区间内未完成任务带到期',
      }, reason: '区间外完成、区间外到期、以及 cancelled 都不得混进来');
      expect(
        rows.firstWhere((row) => row.title == '摘要区间内已完成').checklistTotal,
        2,
        reason: '进度需要检查事项计数',
      );
      expect(
        rows.firstWhere((row) => row.title == '摘要区间内无到期按创建').completed,
        isFalse,
      );
      expect(
        rows.firstWhere((row) => row.title == '摘要区间内无到期按创建').subtaskTotal,
        1,
        reason: '子任务只进父任务的进度，不单独成行',
      );
    });

    testWidgets('未登录（本地库不可用）时界面给出可读原因并禁用插入', (tester) async {
      await _pump(
        tester,
        home: const NotePage(),
        overridesBuilder: (_) => [appDatabaseProvider.overrideWithValue(null)],
      );

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      await tester.pumpAndSettle();

      expect(
        find.text('未登录或本地任务库不可用，暂时无法生成摘要'),
        findsOneWidget,
        reason: '空摘要之外还要说清为什么空',
      );
      expect(
        find.byKey(const Key('note-summary-retry')),
        findsNothing,
        reason: '没有本地库时重试必然再失败，不给假希望',
      );
      final insert = tester.widget<FilledButton>(
        find.byKey(const Key('note-summary-insert')),
      );
      expect(insert.onPressed, isNull);
    });
  });

  group('笔记插入摘要', () {
    testWidgets('笔记编辑器点「插入摘要」把预览文本写进光标处，草稿原文保留', (tester) async {
      final fixture = await _pump(tester, home: const NotePage());
      await _seedSummaryTasks(fixture.database);

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('todo-note-title')), '周报');
      await tester.enterText(find.byKey(const Key('todo-note-content')), '本周：');

      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('note-summary-preview')),
        findsOneWidget,
        reason: '插入前必须能预览，嘀嗒是「摘要预览」而不是盲插',
      );
      expect(find.text('已完成 1 项 · 未完成 2 项'), findsOneWidget);

      await tester.tap(find.byKey(const Key('note-summary-insert')));
      await tester.pumpAndSettle();

      final content = tester
          .widget<TextField>(find.byKey(const Key('todo-note-content')))
          .controller!
          .text;
      expect(content, startsWith('本周：\n'));
      expect(content, contains('## 任务摘要 · 近 7 天（2026-07-05 ~ 2026-07-11）'));
      expect(content, contains('### 摘要工作'));
      expect(content, contains('- [x] 摘要区间内已完成 · 完成于 07-09 · 进度 1/2'));
      expect(find.byKey(const Key('note-summary-preview')), findsNothing);
    });

    testWidgets('取消摘要弹层不改草稿一个字节', (tester) async {
      final fixture = await _pump(tester, home: const NotePage());
      await _seedSummaryTasks(fixture.database);

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('todo-note-content')),
        '原有正文',
      );

      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note-summary-cancel')));
      await tester.pumpAndSettle();

      final content = tester
          .widget<TextField>(find.byKey(const Key('todo-note-content')))
          .controller!
          .text;
      expect(content, '原有正文');
    });

    testWidgets('区间内没有任务时提示空态并禁用插入，不产生空摘要', (tester) async {
      await _pump(
        tester,
        home: const NotePage(),
        fixtureSet: TodoVisualFixtureSet.empty,
      );

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      await tester.pumpAndSettle();

      expect(find.text('该区间内没有任务'), findsOneWidget);
      final insert = tester.widget<FilledButton>(
        find.byKey(const Key('note-summary-insert')),
      );
      expect(insert.onPressed, isNull, reason: '空摘要不允许插入');
    });

    testWidgets('切换时间区间后过期响应不得覆盖新响应', (tester) async {
      final slow = Completer<List<SummaryTaskRow>>();
      final fake = _SequencedSummaryRepository([
        () => slow.future,
        () async => [_row(taskId: 'new', title: '新响应任务')],
      ]);
      await _pump(
        tester,
        home: const NotePage(),
        overridesBuilder: (_) => [
          summaryRepositoryProvider.overrideWithValue(fake),
        ],
      );

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      // 首个请求故意挂住不返回，加载指示器会永动，因此只能用定时 pump。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fake.calls, 1);

      await tester.tap(
        find.byKey(const ValueKey('note-summary-preset-lastThirtyDays')),
      );
      await tester.pump();
      await tester.pump();
      expect(fake.calls, 2);
      expect(find.textContaining('新响应任务'), findsOneWidget);

      slow.complete([_row(taskId: 'stale', title: '过期响应任务')]);
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('过期响应任务'),
        findsNothing,
        reason: '先发但后到的旧请求必须被丢弃',
      );
    });

    testWidgets('刷新失败保留上一次摘要并提供重试', (tester) async {
      final fake = _SequencedSummaryRepository([
        () async => [_row(taskId: 'keep', title: '保留下来的任务')],
        () => Future.error(StateError('本地库读不出来')),
      ]);
      await _pump(
        tester,
        home: const NotePage(),
        overridesBuilder: (_) => [
          summaryRepositoryProvider.overrideWithValue(fake),
        ],
      );

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      await tester.pumpAndSettle();
      expect(find.textContaining('保留下来的任务'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('note-summary-preset-today')));
      await tester.pumpAndSettle();

      expect(find.textContaining('刷新失败'), findsOneWidget);
      expect(
        find.textContaining('保留下来的任务'),
        findsOneWidget,
        reason: '失败时不得清空已经看到的摘要',
      );
      expect(
        find.textContaining('## 任务摘要 · 近 7 天（'),
        findsOneWidget,
        reason: '留着的是上一次区间的取数，标题不能改口称今天',
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('note-summary-insert')))
            .onPressed,
        isNull,
        reason: '数据与当前选的区间不匹配时不许插入',
      );
      expect(find.byKey(const Key('note-summary-retry')), findsOneWidget);
    });

    testWidgets('320px + 1.3 倍字体下弹层自身按该档位布局且不溢出', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final fixture = await _pump(tester, home: const NotePage());
      await _seedSummaryTasks(fixture.database);

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('todo-note-title')), '周报');
      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      await tester.pumpAndSettle();

      final sheetContext = tester.element(
        find.byKey(const Key('note-summary-sheet')),
      );
      expect(
        MediaQuery.textScalerOf(sheetContext).scale(10).round(),
        13,
        reason: '字号档位必须在弹层自己的 context 上自检，home 包层到不了模态',
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('note-summary-insert')), findsOneWidget);
    });

    testWidgets('「插入摘要」与弹层选项都具备独立可读屏语义', (tester) async {
      final fixture = await _pump(tester, home: const NotePage());
      await _seedSummaryTasks(fixture.database);
      final handle = tester.ensureSemantics();
      try {
        await tester.tap(find.byKey(const Key('todo-note-add')));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp(r'^插入摘要$')),
          findsOneWidget,
          reason: '读屏用户要能单独找到这个动作',
        );

        // 编辑器对话框还开着，不能再点 FAB（会被对话框屏障挡住）。
        await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(RegExp(r'^按清单$')),
          findsOneWidget,
          reason: '分组口径不能只有键，读屏要念得出',
        );
        expect(find.bySemanticsLabel(RegExp(r'^插入$')), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('清单 / 分组 / 排序 / 状态四个口径都真的驱动预览', (tester) async {
      final fixture = await _pump(tester, home: const NotePage());
      await _seedSummaryTasks(fixture.database);
      await _seedSecondSummaryList(fixture.database);
      await _openSheet(tester);

      expect(find.text('### 摘要工作'), findsOneWidget);
      expect(find.text('### 摘要个人'), findsOneWidget);

      await _tapOption(tester, 'note-summary-list-sum-l2');
      expect(
        find.textContaining('摘要另一清单任务'),
        findsNothing,
        reason: '取消勾选的清单必须真的从摘要里消失',
      );

      await _tapOption(tester, 'note-summary-group-none');
      expect(find.textContaining('### '), findsNothing);
      expect(
        find.textContaining('摘要区间内无到期按创建 · 进度 1/1 · 摘要工作'),
        findsOneWidget,
        reason: '不分组时行内要带清单名；子任务计入父任务进度',
      );

      await _tapOption(tester, 'note-summary-sort-title');
      final byTitle = _previewText(tester);
      await _tapOption(tester, 'note-summary-sort-time');
      final byTime = _previewText(tester);
      expect(
        byTitle.indexOf('摘要区间内无到期按创建') < byTitle.indexOf('摘要区间内未完成任务带到期'),
        isTrue,
      );
      expect(
        byTime.indexOf('摘要区间内无到期按创建') > byTime.indexOf('摘要区间内未完成任务带到期'),
        isTrue,
        reason: '两种排序必须真的相反，否则选择只是被存起来没用',
      );

      await _tapOption(tester, 'note-summary-status-completed');
      expect(find.textContaining('- [ ] '), findsNothing);
    });

    testWidgets('光标落在文字前部时，摘要插在光标处而不是追加到末尾', (tester) async {
      final fixture = await _pump(tester, home: const NotePage());
      await _seedSummaryTasks(fixture.database);

      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('todo-note-content'));
      await tester.enterText(field, '后文');
      await tester.tapAt(tester.getTopLeft(field) + const Offset(2, 4));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note-summary-insert')));
      await tester.pumpAndSettle();

      final content = tester.widget<TextField>(field).controller!.text;
      expect(content, contains('后文'));
      expect(
        content.indexOf('## 任务摘要') < content.indexOf('后文'),
        isTrue,
        reason: '插在末尾等于忽略光标',
      );
    });

    testWidgets('自定义区间：取消日期选择就不换区间', (tester) async {
      final fixture = await _pump(tester, home: const NotePage());
      await _seedSummaryTasks(fixture.database);
      await _openSheet(tester);

      await _tapOption(tester, 'note-summary-preset-custom');
      // 日期选择器以对话框盖在弹层之上；pop 最上层路由 = 用户取消（返回 null）。
      Navigator.of(
        tester.element(find.byKey(const Key('note-summary-sheet'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('note-summary-sheet')),
        findsOneWidget,
        reason: 'pageBack 只应弹掉日期选择器，摘要弹层还得在',
      );

      expect(
        find.textContaining('## 任务摘要 · 近 7 天（'),
        findsOneWidget,
        reason: '没选成日期就不能把「自定义」悄悄当成今天',
      );
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('note-summary-preset-lastSevenDays')),
            )
            .selected,
        isTrue,
      );
    });
  });
}

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  required Widget home,
  TodoVisualFixtureSet fixtureSet = TodoVisualFixtureSet.empty,
  List<Override> Function(AppDatabase database)? overridesBuilder,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: fixtureSet,
    overridesBuilder: (database) => [
      noteRepositoryProvider.overrideWithValue(_FakeNoteRepository()),
      ...?overridesBuilder?.call(database),
    ],
  );
  addTearDown(fixture.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return fixture;
}

/// 选项在弹层内部的滚动区里：先滚到可见再点，否则点击落在视口外。
Future<void> _tapOption(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 新建笔记 → 打开摘要弹层。
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('todo-note-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('todo-note-insert-summary')));
  await tester.pumpAndSettle();
}

/// 预览按行渲染；按树序拼回整段文本用于顺序断言。
String _previewText(WidgetTester tester) {
  return find
      .descendant(
        of: find.byKey(const Key('note-summary-preview')),
        matching: find.byType(Text),
      )
      .evaluate()
      .map((element) => (element.widget as Text).data ?? '')
      .join('\n');
}

Future<void> _seedSecondSummaryList(AppDatabase db) async {
  final now = DateTime(2026, 7, 1);
  await db.batch((batch) {
    batch.insert(
      db.todoLists,
      TodoListsCompanion.insert(
        id: 'sum-l2',
        name: '摘要个人',
        updatedAt: now,
        createdAt: now,
      ),
    );
    batch.insert(
      db.todoTasks,
      TodoTasksCompanion.insert(
        id: 'sum-l2-task',
        listId: 'sum-l2',
        title: '摘要另一清单任务',
        updatedAt: now,
        createdAt: DateTime(2026, 7, 9),
      ),
    );
  });
}

/// 覆盖近 7 天区间内外的完成时间、到期时间与取消标记。
Future<void> _seedSummaryTasks(AppDatabase db) async {
  final createdAt = DateTime(2026, 7, 1);
  await db.batch((batch) {
    batch.insert(
      db.todoLists,
      TodoListsCompanion.insert(
        id: 'sum-l1',
        name: '摘要工作',
        updatedAt: createdAt,
        createdAt: createdAt,
      ),
    );
    batch.insertAll(db.todoTasks, [
      TodoTasksCompanion.insert(
        id: 'sum-in-done',
        listId: 'sum-l1',
        title: '摘要区间内已完成',
        completed: const Value(true),
        completedAt: Value(DateTime(2026, 7, 9, 18)),
        updatedAt: createdAt,
        createdAt: createdAt,
      ),
      TodoTasksCompanion.insert(
        id: 'sum-in-due',
        listId: 'sum-l1',
        title: '摘要区间内未完成任务带到期',
        dueAt: Value(DateTime(2026, 7, 10, 10)),
        updatedAt: createdAt,
        createdAt: createdAt,
      ),
      TodoTasksCompanion.insert(
        id: 'sum-in-created',
        listId: 'sum-l1',
        title: '摘要区间内无到期按创建',
        updatedAt: createdAt,
        createdAt: DateTime(2026, 7, 8),
      ),
      TodoTasksCompanion.insert(
        id: 'sum-out-done',
        listId: 'sum-l1',
        title: '摘要区间外已完成',
        completed: const Value(true),
        completedAt: Value(DateTime(2026, 6, 1, 9)),
        // 到期时间落在区间内：只有「已完成看完成时间」的口径才该把它排除。
        dueAt: Value(DateTime(2026, 7, 10, 12)),
        updatedAt: createdAt,
        createdAt: createdAt,
      ),
      TodoTasksCompanion.insert(
        id: 'sum-child',
        listId: 'sum-l1',
        parentTaskId: const Value('sum-in-created'),
        title: '摘要子任务不进摘要',
        completed: const Value(true),
        completedAt: Value(DateTime(2026, 7, 10, 8)),
        updatedAt: createdAt,
        createdAt: createdAt,
      ),
      TodoTasksCompanion.insert(
        id: 'sum-cancelled',
        listId: 'sum-l1',
        title: '摘要取消任务',
        cancelled: const Value(true),
        updatedAt: createdAt,
        createdAt: DateTime(2026, 7, 10),
      ),
    ]);
    batch.insertAll(db.todoChecklistItems, [
      TodoChecklistItemsCompanion.insert(
        id: 'sum-cl-1',
        taskId: 'sum-in-done',
        title: '已完成事项',
        completed: const Value(true),
        updatedAt: createdAt,
        createdAt: createdAt,
      ),
      TodoChecklistItemsCompanion.insert(
        id: 'sum-cl-2',
        taskId: 'sum-in-done',
        title: '未完成事项',
        updatedAt: createdAt,
        createdAt: createdAt,
      ),
    ]);
  });
}

/// 每次调用才创建 future：提前构造的 `Future.error` 会被框架判成未处理异常。
class _SequencedSummaryRepository implements SummaryRepository {
  _SequencedSummaryRepository(this._factories);

  final List<Future<List<SummaryTaskRow>> Function()> _factories;
  int calls = 0;

  @override
  Future<List<SummaryTaskRow>> loadInRange({
    required DateTime from,
    required DateTime to,
  }) {
    final factory = _factories[calls.clamp(0, _factories.length - 1)];
    calls++;
    return factory();
  }
}

class _FakeNoteRepository implements NoteRepository {
  @override
  Future<List<TodoNoteItem>> list() async => const [];

  @override
  Future<int> create({required String title, required String content}) async =>
      1;

  @override
  Future<void> update({
    required int id,
    required String title,
    required String content,
    int sortOrder = 0,
  }) async {}

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> archive(int id, {required bool archived}) async {}

  @override
  Future<int> convertFromTask(int taskId) async => 1;
}
