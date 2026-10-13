import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/task/task_swipe_preferences.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/settings/settings_route.dart';
import 'package:zh_cloud_todo_flutter/features/settings/task_swipe_settings_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_swipe_preference_repository.dart';

import '../../support/todo_visual_fixture.dart';

/// 嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md》`:75`
/// 「还可以在「设置」-「更多设置」-「滑动操作」中，进行自定义配置。」
///
/// 路径差一处（本应用的设置页没有「更多设置」那一层，这一项直接落在「任务」分组），
/// 已在 FL #601 与 specs/117 台账里记成"有意差异"。这里测的是"自定义配置"那半句：
/// 勾选真的落库、上限真的挡得住、顺序真的看得见。
void main() {
  testWidgets('设置页「任务」分组里有「滑动操作」，一次点击直达配置页', (tester) async {
    await _pump(tester, SettingsRoute());

    expect(find.text('滑动操作'), findsOneWidget);
    final tileTitles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .whereType<String>()
        .toList();
    expect(
      tileTitles.indexOf('滑动操作'),
      lessThan(tileTitles.indexOf('日历订阅')),
      reason: '它得留在「任务」分组里、排在清单类设置附近，被搬去「关于」就要红',
    );

    await tester.tap(find.byKey(const Key('todo-settings-swipe-actions')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskSwipeSettingsPage), findsOneWidget);
  });

  testWidgets('配置页的默认勾选就是原文那两组，序号就是按钮顺序', (tester) async {
    await _pump(tester, TaskSwipeSettingsPage());

    for (final (index, action) in [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.delete,
      TaskSwipeAction.changeDueDate,
    ].indexed) {
      expect(
        _tileChecked(tester, TaskSwipeSide.swipeLeft, action),
        isTrue,
        reason: '`:66` 左滑三件：${action.label} 默认勾着',
      );
      expect(
        _orderOf(tester, TaskSwipeSide.swipeLeft, action),
        index + 1,
        reason: '${action.label} 是左滑那一侧的第 ${index + 1} 个按钮',
      );
    }
    for (final action in [TaskSwipeAction.complete, TaskSwipeAction.pin]) {
      expect(
        _tileChecked(tester, TaskSwipeSide.swipeRight, action),
        isTrue,
        reason: '`:71` 右滑两件：${action.label} 默认勾着',
      );
    }
    expect(
      _tileChecked(tester, TaskSwipeSide.swipeRight, TaskSwipeAction.delete),
      isFalse,
      reason: '左滑那一档不该同时出现在右滑里',
    );
  });

  testWidgets('取消勾选「删除任务」就写进库，行上那一档随之没了', (tester) async {
    final fixture = await _pump(tester, TaskSwipeSettingsPage());

    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeLeft-delete')),
    );
    await tester.pumpAndSettle();

    final stored = await TaskSwipePreferenceRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).get();
    expect(stored.swipeLeft, const [
      TaskSwipeAction.moveTo,
      TaskSwipeAction.changeDueDate,
    ], reason: '取消勾选必须真落库，不然第二台设备看到的还是旧的一整套');
    expect(find.text('滑动操作已保存，等待同步'), findsOneWidget);
    expect(
      _tileChecked(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.delete),
      isFalse,
    );
    expect(
      _orderOf(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.delete),
      isNull,
      reason: '取消勾选后不该还挂着一个序号',
    );
  });

  testWidgets('一侧已经三个 ⇒ 第四个按不动，但取消勾选仍然可以', (tester) async {
    await _pump(tester, TaskSwipeSettingsPage());

    // 默认就是满的：这时点「完成」不该把它挤进左滑那一侧。
    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeLeft-complete')),
    );
    await tester.pumpAndSettle();
    expect(
      _tileChecked(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.complete),
      isFalse,
      reason: '满一侧的第四个必须勾不上（`maxActionsPerSide` 的界面侧闸门）',
    );
    expect(
      _tileToggleable(
        tester,
        TaskSwipeSide.swipeLeft,
        TaskSwipeAction.complete,
      ),
      isFalse,
      reason: '量的是"按不动"本身：onChanged 是 null，不是点下去又被改回来',
    );
    expect(
      _tileToggleable(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.moveTo),
      isTrue,
      reason: '反向对照：同一侧已勾的那一档点得动，否则上面那条 isFalse 是整张表都失灵',
    );

    // 反向对照：同一张表上，已勾的那一档是点得动的（否则上面那条 findsNothing
    // 只是因为整张表都按不动）。
    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeLeft-move')),
    );
    await tester.pumpAndSettle();
    expect(
      _tileChecked(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.moveTo),
      isFalse,
    );
  });

  testWidgets('先勾后取消再勾回来 ⇒ 顺序按勾选的先后重排', (tester) async {
    final fixture = await _pump(tester, TaskSwipeSettingsPage());

    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeLeft-move')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeLeft-move')),
    );
    await tester.pumpAndSettle();

    final stored = await TaskSwipePreferenceRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).get();
    expect(stored.swipeLeft, const [
      TaskSwipeAction.delete,
      TaskSwipeAction.changeDueDate,
      TaskSwipeAction.moveTo,
    ], reason: '重新勾回来的排在最后 —— 界面上的序号 3 就是这句话的证据');
    expect(
      _orderOf(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.moveTo),
      3,
      reason: '界面上的序号 3 就是"重新勾回来的排在最后"这句的可见证据',
    );
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: '连点两次只该留最新那条确认，不该排成一串过期的',
    );
  });

  testWidgets('「恢复默认」回到原文那两组', (tester) async {
    final fixture = await _pump(tester, TaskSwipeSettingsPage());

    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeLeft-delete')),
    );
    await tester.pumpAndSettle();
    expect(
      _tileChecked(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.delete),
      isFalse,
    );
    // 正对照：确认条真的在播。没有它，下面那颗「恢复默认」点得动只是因为页面上
    // 没有遮挡物，这条用例就测不出"按钮被确认条盖住"那一类回归。
    expect(find.byType(SnackBar), findsOneWidget);

    final reset = find.byKey(const Key('todo-settings-swipe-reset'));
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();

    final stored = await TaskSwipePreferenceRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).get();
    expect(
      stored.swipeLeft,
      TaskSwipePreferences.defaults.swipeLeft,
      reason: '恢复默认要改的是左滑那一侧：现在存的是 ${stored.swipeLeft}',
    );
    expect(
      stored.swipeRight,
      TaskSwipePreferences.defaults.swipeRight,
      reason: '右滑那一侧：现在存的是 ${stored.swipeRight}',
    );
    expect(
      _tileChecked(tester, TaskSwipeSide.swipeLeft, TaskSwipeAction.delete),
      isTrue,
    );
  });

  testWidgets('滚到底时「恢复默认」不被确认条盖住（用户就是这么点的）', (tester) async {
    await _pump(tester, TaskSwipeSettingsPage());

    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeLeft-delete')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget, reason: '正对照：确认条在播，才有遮挡这回事');

    final reset = find.byKey(const Key('todo-settings-swipe-reset'));
    await tester.dragUntilVisible(
      reset,
      find.byType(ListView),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    final button = tester.getRect(reset);
    final bar = tester.getRect(find.byType(SnackBar));
    expect(
      button.bottom,
      lessThanOrEqualTo(bar.top),
      reason: '钮在 $button、确认条在 $bar —— 压在一起就是"点了没反应"的那个形状',
    );
  });

  testWidgets('仓储不可用时给可见提示，不静默失败', (tester) async {
    await _pump(
      tester,
      TaskSwipeSettingsPage(),
      overrides: (database) => [
        taskSwipePreferenceRepositoryProvider.overrideWithValue(null),
      ],
    );

    await tester.tap(
      find.byKey(const Key('todo-settings-swipe-swipeRight-pin')),
    );
    await tester.pumpAndSettle();

    expect(find.text('滑动操作暂不可保存，请稍后重试'), findsOneWidget);
  });
}

bool _tileChecked(
  WidgetTester tester,
  TaskSwipeSide side,
  TaskSwipeAction action,
) {
  final checkbox = tester.widget<Checkbox>(
    find.descendant(
      of: find.byKey(Key('todo-settings-swipe-${side.wire}-${action.wire}')),
      matching: find.byType(Checkbox),
    ),
  );
  return checkbox.value ?? false;
}

bool _tileToggleable(
  WidgetTester tester,
  TaskSwipeSide side,
  TaskSwipeAction action,
) {
  final checkbox = tester.widget<Checkbox>(
    find.descendant(
      of: find.byKey(Key('todo-settings-swipe-${side.wire}-${action.wire}')),
      matching: find.byType(Checkbox),
    ),
  );
  return checkbox.onChanged != null;
}

/// 那一档在这一侧排第几（没勾上就是 null）。序号是"勾选顺序 = 按钮顺序"
/// 唯一能在界面上核对的通道，所以它必须能被量到，而不是只在实现里写一句。
int? _orderOf(WidgetTester tester, TaskSwipeSide side, TaskSwipeAction action) {
  final finder = find.descendant(
    of: find.byKey(Key('todo-settings-swipe-${side.wire}-${action.wire}')),
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && int.tryParse(widget.data ?? '') != null,
    ),
  );
  final hits = finder.evaluate();
  if (hits.isEmpty) return null;
  return int.parse(tester.widget<Text>(finder).data!);
}

Future<TodoVisualFixture> _pump(
  WidgetTester tester,
  Widget page, {
  List<Override> Function(AppDatabase database)? overrides,
}) async {
  final fixture = await TodoVisualFixture.create(
    set: TodoVisualFixtureSet.populated,
    overridesBuilder: overrides,
  );
  addTearDown(fixture.dispose);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}
