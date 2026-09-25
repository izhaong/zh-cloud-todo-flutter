import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';

/// 嘀嗒《01-任务/09-如何管理海量任务/04-用标签管理任务.md》:46/:48/:61。
///
/// 词法本身在 `test/features/tag/hash_tag_input_test.dart`，这一层钉的是
/// "快速添加这个界面上，用户真的能用 # 把标签带进提交"。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  /// 桌面输入条：直接 pump，宽度给足（真实页面里它只在 tabletMinWidth 以上出现）。
  Future<void> pumpDesktop(
    WidgetTester tester, {
    required QuickAddSubmitCallback onSubmit,
    List<QuickAddTagOption> tagOptions = const [],
    QuickAddTagIdsEnsurer? ensureTagIds,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: themed(),
        home: Scaffold(
          body: QuickAddBar(
            onSubmit: onSubmit,
            tagOptions: tagOptions,
            ensureTagIds: ensureTagIds,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 移动弹层：点 FAB 打开 `_MobileQuickAddSheet`。
  Future<void> pumpMobile(
    WidgetTester tester, {
    required QuickAddSubmitCallback onSubmit,
    List<QuickAddTagOption> tagOptions = const [],
    QuickAddTagIdsEnsurer? ensureTagIds,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: themed(),
        home: Scaffold(
          body: MobileQuickAddButton(
            onSubmit: onSubmit,
            tagOptions: tagOptions,
            ensureTagIds: ensureTagIds,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-mobile-add')));
    await tester.pumpAndSettle();
  }

  for (final surface in ['desktop', 'mobile']) {
    final isDesktop = surface == 'desktop';
    final pump = isDesktop ? pumpDesktop : pumpMobile;

    testWidgets('$surface：输入「#周会」提交 ⇒ 标题里没有井号，标签进 request', (tester) async {
      QuickAddRequest? submitted;
      List<String>? ensuredNames;
      await pump(
        tester,
        onSubmit: (request) => submitted = request,
        ensureTagIds: (names) async {
          ensuredNames = names;
          return const ['tag-meeting'];
        },
      );

      final input = isDesktop
          ? find.byKey(const Key('todo-quick-add-input'))
          : find.byKey(const Key('todo-mobile-add-field'));
      await tester.enterText(input, '写周报 #周会');
      if (isDesktop) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        await tester.tap(
          find.bySemanticsIdentifier('todo_mobile_quick_add_submit'),
        );
      }
      await tester.pumpAndSettle();

      expect(submitted, isNotNull, reason: '点了提交却没走 onSubmit ⇒ 后面全是空断言');
      expect(submitted!.input, '写周报');
      expect(submitted!.input, isNot(contains('#')));
      expect(ensuredNames, ['周会']);
      expect(submitted!.tagIds, ['tag-meeting']);
    });

    testWidgets('$surface：按钮所选标签与「#」标签合并去重后一起提交', (tester) async {
      QuickAddRequest? submitted;
      await pump(
        tester,
        onSubmit: (request) => submitted = request,
        tagOptions: const [QuickAddTagOption(id: 'focus', name: '专注')],
        ensureTagIds: (names) async => names.map((n) => 'by-name-$n').toList(),
      );

      if (isDesktop) {
        await tester.tap(find.byTooltip('标签'));
      } else {
        await tester.tap(
          find.bySemanticsIdentifier('todo_mobile_quick_add_tags'),
        );
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('专注'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final input = isDesktop
          ? find.byKey(const Key('todo-quick-add-input'))
          : find.byKey(const Key('todo-mobile-add-field'));
      await tester.enterText(input, '复盘 #专注 #复盘');
      await tester.pump();
      if (isDesktop) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        await tester.tap(
          find.bySemanticsIdentifier('todo_mobile_quick_add_submit'),
        );
      }
      await tester.pumpAndSettle();

      expect(
        submitted!.tagIds,
        unorderedEquals(['focus', 'by-name-复盘']),
        reason: '#专注 要复用按钮已选的 focus，而不是再建一个同名标签',
      );
    });
  }

  testWidgets('「标签 N」的计数含 # 里的名字（视觉与读屏都跟着走）', (tester) async {
    await pumpMobile(
      tester,
      onSubmit: (_) {},
      ensureTagIds: (names) async => names.map((n) => n).toList(),
    );
    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      '写周报 #周会 #评审',
    );
    await tester.pump();

    expect(find.text('标签 2'), findsOneWidget);
    expect(find.text('标签 2'), findsOneWidget, reason: '计数只该出现一处');

    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      '写周报 #周会',
    );
    await tester.pump();
    expect(
      find.text('标签 1'),
      findsOneWidget,
      reason: '删掉一个 # 计数要跟着退——不跟着退说明读的是输入时的快照',
    );
  });

  testWidgets('桌面：# 让标签工具图标带出数量角标与读屏标签', (tester) async {
    await pumpDesktop(
      tester,
      onSubmit: (_) {},
      ensureTagIds: (names) async => names,
    );
    await tester.enterText(
      find.byKey(const Key('todo-quick-add-input')),
      '写周报 #周会',
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('todo-quick-add')),
        matching: find.text('标签 1'),
      ),
      findsOneWidget,
      reason:
          '桌面输入条原来只有 tooltip 里的「标签」，而 tooltip 进不了读屏（实测见 '
          'task_quick_add_sheet.dart:203）⇒ 计数必须是看得见的文字，才能同时被看见和被念到',
    );

    await tester.enterText(
      find.byKey(const Key('todo-quick-add-input')),
      '写周报',
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('todo-quick-add')),
        matching: find.text('标签 1'),
      ),
      findsNothing,
      reason: '删掉 # 后文案要收回，不然输入条会永远自称带着一个标签',
    );
  });

  testWidgets('整段只有「#周会」⇒ 不静默早退：给可见提示且不建标签（Issue #292 同口径）', (tester) async {
    var submits = 0;
    var ensuredCalls = 0;
    await pumpMobile(
      tester,
      onSubmit: (_) => submits++,
      ensureTagIds: (names) async {
        ensuredCalls++;
        return const [];
      },
    );

    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      '#周会',
    );
    await tester.pump();
    await tester.tap(
      find.bySemanticsIdentifier('todo_mobile_quick_add_submit'),
    );
    await tester.pumpAndSettle();

    expect(submits, 0);
    expect(ensuredCalls, 0, reason: '标题为空却先把标签建出来 ⇒ 留下一条挂在空气上的标签');
    expect(
      find.text('请输入任务标题'),
      findsOneWidget,
      reason: '早退必须是看得见的：静默 return 让人以为按钮坏了',
    );

    // 补上正文后提示要自己收掉，否则下一次提交看起来还是错
    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      '写周报 #周会',
    );
    await tester.pump();
    expect(find.text('请输入任务标题'), findsNothing);
  });

  testWidgets('没接线 ensureTagIds 时 # 就是普通文字（别偷偷改变其它入口的行为）', (tester) async {
    QuickAddRequest? submitted;
    await pumpDesktop(tester, onSubmit: (request) => submitted = request);

    await tester.enterText(
      find.byKey(const Key('todo-quick-add-input')),
      '进度 50% #待办',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submitted!.input, '进度 50% #待办');
    expect(submitted!.tagIds, isEmpty);
  });

  testWidgets('标签 sheet 里能直接创建新标签（嘀嗒 :46「或创建新标签」）', (tester) async {
    QuickAddRequest? submitted;
    final ensured = <List<String>>[];
    // 一个标签都没有：develop 上这条路径只会回一句「请先在标签页创建标签」。
    await pumpMobile(
      tester,
      onSubmit: (request) => submitted = request,
      ensureTagIds: (names) async {
        ensured.add(names);
        return const ['tag-new'];
      },
    );

    await tester.tap(find.bySemanticsIdentifier('todo_mobile_quick_add_tags'));
    await tester.pumpAndSettle();

    expect(
      find.text('请先在标签页创建标签'),
      findsNothing,
      reason: 'sheet 里就能建 ⇒ 那句"先去哪儿建"的死路提示不该再出现',
    );
    await tester.tap(find.byKey(const Key('todo-quick-add-create-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-quick-add-create-tag-field')),
      '周会',
    );
    await tester.tap(
      find.byKey(const Key('todo-quick-add-create-tag-confirm')),
    );
    await tester.pumpAndSettle();

    expect(ensured, [
      ['周会'],
    ]);
    // 建完立刻被选中：不用人再回列表里找一遍
    final checkbox = tester.widget<CheckboxListTile>(
      find.descendant(
        of: find.byKey(const Key('todo-quick-add-created-tag-row')),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(checkbox.value, isTrue);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      '写周报',
    );
    await tester.tap(
      find.bySemanticsIdentifier('todo_mobile_quick_add_submit'),
    );
    await tester.pumpAndSettle();

    expect(submitted!.tagIds, contains('tag-new'));
  });

  testWidgets('创建标签失败：sheet 不关、已选保留、给可见提示', (tester) async {
    var submits = 0;
    await pumpMobile(
      tester,
      onSubmit: (_) => submits++,
      tagOptions: const [QuickAddTagOption(id: 'focus', name: '专注')],
      ensureTagIds: (names) async => throw Exception('模拟建标签失败'),
    );

    await tester.tap(find.bySemanticsIdentifier('todo_mobile_quick_add_tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('专注'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-quick-add-create-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-quick-add-create-tag-field')),
      '周会',
    );
    await tester.tap(
      find.byKey(const Key('todo-quick-add-create-tag-confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('标签创建失败，请重试'),
      findsOneWidget,
      reason: '吞掉异常 ⇒ 用户以为建好了，任务上却什么标签都没有',
    );
    expect(
      find.byKey(const Key('todo-quick-add-created-tag-row')),
      findsNothing,
      reason: '失败却把没建成的标签摆进列表 ⇒ 提交时挂一个不存在的 id',
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.ancestor(
              of: find.text('专注'),
              matching: find.byType(CheckboxListTile),
            ),
          )
          .value,
      isTrue,
      reason: '四件套第 3 条：一次失败不许把 sheet 里已经选好的东西一起清掉',
    );

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      '写周报',
    );
    await tester.tap(
      find.bySemanticsIdentifier('todo_mobile_quick_add_submit'),
    );
    await tester.pumpAndSettle();

    expect(submits, 1, reason: '失败的那一次不该把 sheet 里的已选一起清掉');
  });

  testWidgets('连点两次「确定」只建一个标签', (tester) async {
    var calls = 0;
    await pumpMobile(
      tester,
      onSubmit: (_) {},
      ensureTagIds: (names) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return const ['tag-new'];
      },
    );

    await tester.tap(find.bySemanticsIdentifier('todo_mobile_quick_add_tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-quick-add-create-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-quick-add-create-tag-field')),
      '周会',
    );
    await tester.tap(
      find.byKey(const Key('todo-quick-add-create-tag-confirm')),
    );
    await tester.tap(
      find.byKey(const Key('todo-quick-add-create-tag-confirm')),
    );
    await tester.pumpAndSettle();

    expect(calls, 1, reason: '在飞的那次还没回来就允许第二次 ⇒ 库里长两条同名标签');
  });

  testWidgets('320px + 1.3 倍：新建标签行与「标签 N」都排得下、可命中、读屏分得清', (tester) async {
    // 字号与视口都要走 platformDispatcher（ThemeData 没有 textScaler 这一项），
    // 否则断言的是"我以为设过了"，实际全程按 1.0 跑。
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: themed(),
        home: Scaffold(
          body: MobileQuickAddButton(
            onSubmit: (_) {},
            tagOptions: const [QuickAddTagOption(id: 'focus', name: '专注')],
            ensureTagIds: (names) async => names,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-mobile-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-mobile-add-field')),
      '写周报 #周会',
    );
    await tester.pump();

    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('todo-mobile-add-field'))),
      ).scale(10),
      closeTo(13, 0.001),
      reason: '字号没真按 1.3 倍走的话，这条用例从头到尾都是假的',
    );

    // 弹层里才有的那一行：先打开标签弹层，再断言它可命中
    await tester.tap(find.bySemanticsIdentifier('todo_mobile_quick_add_tags'));
    await tester.pumpAndSettle();
    // 先真的建一个标签：`created-tag-row` 只有建完才在树上，
    // 不建就断言它"排得下"是在断言一个不存在的东西。
    await tester.tap(find.byKey(const Key('todo-quick-add-create-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-quick-add-create-tag-field')),
      '周会',
    );
    await tester.tap(
      find.byKey(const Key('todo-quick-add-create-tag-confirm')),
    );
    await tester.pumpAndSettle();
    for (final key in [
      const Key('todo-quick-add-create-tag'),
      const Key('todo-quick-add-created-tag-row'),
    ]) {
      expect(
        find.byKey(key).hitTestable(),
        findsOneWidget,
        reason: '$key 在 320px + 1.3 倍字号下被挤出可点区域',
      );
    }
    expect(
      find.bySemanticsIdentifier('todo_mobile_quick_add_tags'),
      findsOneWidget,
      reason: '标签入口要有自己的语义节点，读屏才念得出"标签 1"而不是整行糊成一团',
    );
    expect(
      find.descendant(
        of: find.bySemanticsIdentifier('todo_mobile_quick_add_tags'),
        matching: find.text('标签 1'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
