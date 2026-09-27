import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/home/workspace_companion.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';
import 'package:zh_cloud_todo_flutter/features/task/views/calendar_view.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》的三条文案（术语照抄）。
const _showCalendar = '同时显示日历';
const _showTasks = '同时显示任务';
const _closeCompanion = '关闭同时显示';

/// 自创同义词一旦出现就说明文案漂了（源页只用这三个词）。
const _inventedSynonyms = ['分栏', '双栏', '并排', '并列显示'];

/// 用一份内存存储替换 SharedPreferences，这样"重进工作区"能被同一个值复放。
class _InMemoryCompanionStorage implements WorkspaceCompanionStorage {
  _InMemoryCompanionStorage([this.value]);

  String? value;
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> readString(String key) async {
    reads++;
    return value;
  }

  @override
  Future<bool> writeString(String key, String value) async {
    writes++;
    this.value = value;
    return true;
  }
}

/// 写盘必抛，用来验"存储层坏了不影响已经画出来的界面"。
class _ThrowingCompanionStorage implements WorkspaceCompanionStorage {
  int writeAttempts = 0;

  @override
  Future<String?> readString(String key) async => null;

  @override
  Future<bool> writeString(String key, String value) async {
    writeAttempts++;
    throw StateError('storage full');
  }
}

List<Override> _overrides(WorkspaceCompanionStorage storage) => [
  workspaceCompanionStorageProvider.overrideWithValue(storage),
];

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    buttons: kSecondaryButton,
  );
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 菜单项文案的取数面：只读弹层里的那一条 PopupMenuItem，不扫全树，
/// 免得被侧栏/内容区里恰好同名的 Text 顶掉（假绿）。
List<String> _menuLabels(WidgetTester tester) {
  return find
      .byType(PopupMenuItem<String>)
      .evaluate()
      .map((e) => (e.widget as PopupMenuItem<String>).child)
      .whereType<Text>()
      .map((t) => t.data ?? '')
      .toList();
}

void main() {
  for (final (name, viewport) in const [
    ('wide', TodoVisualViewports.wide),
    ('compact', TodoVisualViewports.compact),
  ]) {
    testWidgets('$name 右键任务模块图标出现「$_showCalendar」，开启后日历在任务清单右侧', (
      tester,
    ) async {
      final storage = _InMemoryCompanionStorage();
      await pumpTodoVisualScenario(
        tester,
        viewport: viewport,
        fixtureSet: TodoVisualFixtureSet.populated,
        overridesBuilder: (_) => _overrides(storage),
        child: const HomeShell(),
      );

      await _rightClick(tester, find.byKey(const Key('todo-rail-item-tasks')));
      expect(_menuLabels(tester), contains(_showCalendar));

      await tester.tap(find.text(_showCalendar));
      await tester.pumpAndSettle();

      final companion = find.byKey(const Key('todo-companion'));
      expect(companion, findsOneWidget);
      expect(
        find.descendant(of: companion, matching: find.byType(CalendarView)),
        findsOneWidget,
      );
      // :21「日历将出现在任务清单的右侧」⇒ 副栏的左边界必须在主内容区右边。
      expect(
        tester.getTopLeft(companion).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('todo-content'))).dx,
        ),
      );
    });

    testWidgets('$name 右键日历模块图标出现「$_showTasks」，开启后任务清单在日历右侧', (tester) async {
      final storage = _InMemoryCompanionStorage();
      await pumpTodoVisualScenario(
        tester,
        viewport: viewport,
        fixtureSet: TodoVisualFixtureSet.populated,
        overridesBuilder: (_) => _overrides(storage),
        child: const HomeShell(),
      );

      await _rightClick(
        tester,
        find.byKey(const Key('todo-rail-item-calendar')),
      );
      expect(_menuLabels(tester), contains(_showTasks));

      await tester.tap(find.text(_showTasks));
      await tester.pumpAndSettle();

      final companion = find.byKey(const Key('todo-companion'));
      expect(companion, findsOneWidget);
      expect(
        find.descendant(of: companion, matching: find.byType(TasksByListPage)),
        findsOneWidget,
      );
      // :31 与 :21 是两条排布：这一条里副栏放的必须是任务清单。
      expect(
        tester.getTopLeft(companion).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('todo-content'))).dx,
        ),
      );
    });

    testWidgets('$name 已并列时同一图标给出「$_closeCompanion」，点了恢复单模块视图', (tester) async {
      final storage = _InMemoryCompanionStorage();
      await pumpTodoVisualScenario(
        tester,
        viewport: viewport,
        fixtureSet: TodoVisualFixtureSet.populated,
        overridesBuilder: (_) => _overrides(storage),
        child: const HomeShell(),
      );

      await _rightClick(tester, find.byKey(const Key('todo-rail-item-tasks')));
      await tester.tap(find.text(_showCalendar));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('todo-companion')), findsOneWidget);

      await _rightClick(tester, find.byKey(const Key('todo-rail-item-tasks')));
      final labels = _menuLabels(tester);
      expect(labels, contains(_closeCompanion));
      expect(labels, isNot(contains(_showCalendar)));

      await tester.tap(find.text(_closeCompanion));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('todo-companion')), findsNothing);
    });
  }

  testWidgets('方向是存进偏好的事实：带偏好重进工作区仍回到同一侧', (tester) async {
    // 单个方向在这里各测一次：预置已存盘的值，只 pump 一次。
    // （双次 pump 会把第一份 fixture 的定时器留在测试结束时，报 "Timer is still pending"。）
    final storage = _InMemoryCompanionStorage(
      '{"companion":"tasksBesideCalendar"}',
    );
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (_) => _overrides(storage),
      child: const HomeShell(),
    );
    await tester.pumpAndSettle();

    final companion = find.byKey(const Key('todo-companion'));
    expect(companion, findsOneWidget);
    expect(
      find.descendant(of: companion, matching: find.byType(TasksByListPage)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(companion).dx,
      greaterThan(tester.getTopLeft(find.byKey(const Key('todo-content'))).dx),
    );
    // 还原路径不该顺手改写存盘值。
    expect(storage.writes, 0);
  });

  testWidgets('反方向存盘后重进，副栏换成日历', (tester) async {
    final storage = _InMemoryCompanionStorage(
      '{"companion":"calendarBesideTasks"}',
    );
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (_) => _overrides(storage),
      child: const HomeShell(),
    );
    await tester.pumpAndSettle();

    final companion = find.byKey(const Key('todo-companion'));
    expect(
      find.descendant(of: companion, matching: find.byType(CalendarView)),
      findsOneWidget,
    );
    expect(storage.writes, 0);
  });

  for (final (name, viewport) in const [
    ('mobile', TodoVisualViewports.mobile),
    ('mobile-min', TodoVisualViewports.mobileMin),
  ]) {
    testWidgets('$name 窄屏没有模块图标轨道，因而给不出并列入口', (tester) async {
      // 源页 :5 限定「桌面端」。实测窄屏连 `todo-rail` 都不渲染（模块切换走底栏），
      // 所以"右键没有菜单"不是一条守卫，而是根本没有这个 affordance —— 断言要照着现实写。
      final storage = _InMemoryCompanionStorage();
      await pumpTodoVisualScenario(
        tester,
        viewport: viewport,
        fixtureSet: TodoVisualFixtureSet.populated,
        overridesBuilder: (_) => _overrides(storage),
        child: const HomeShell(),
      );

      expect(find.byKey(const Key('todo-rail')), findsNothing);
      expect(find.byKey(const Key('todo-rail-item-tasks')), findsNothing);
      expect(find.byKey(const Key('todo-companion')), findsNothing);
      expect(storage.writes, 0);
    });

    testWidgets('$name 偏好已开启时静默降回单栏，不溢出也不清空偏好', (tester) async {
      final storage = _InMemoryCompanionStorage(
        '{"companion":"calendarBesideTasks"}',
      );
      await pumpTodoVisualScenario(
        tester,
        viewport: viewport,
        fixtureSet: TodoVisualFixtureSet.populated,
        overridesBuilder: (_) => _overrides(storage),
        child: const HomeShell(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('todo-companion')), findsNothing);
      expect(tester.takeException(), isNull);
      // 降级不改写偏好：回到宽屏还要能恢复（源页 :39 只说"关闭"才恢复单模块）。
      expect(storage.writes, 0);
      expect(storage.value, contains('calendarBesideTasks'));
    });
  }

  testWidgets('宽屏 1.3 倍字号下并列不溢出，副栏仍在可视区内', (tester) async {
    final storage = _InMemoryCompanionStorage(
      '{"companion":"calendarBesideTasks"}',
    );
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.compact,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (_) => _overrides(storage),
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const HomeShell(),
      ),
    );
    await tester.pumpAndSettle();

    final companion = find.byKey(const Key('todo-companion'));
    expect(companion, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(companion).right, lessThanOrEqualTo(1280));
  });

  testWidgets('320px + 1.3 倍字号：窄屏带着已开启的偏好也不画副栏、不溢出', (tester) async {
    final storage = _InMemoryCompanionStorage(
      '{"companion":"calendarBesideTasks"}',
    );
    await pumpTodoVisualScenario(
      tester,
      viewport: const Size(320, 600),
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (_) => _overrides(storage),
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const HomeShell(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-companion')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切去「习惯」再切回「任务」：并列按记忆恢复，切模块不改写偏好', (tester) async {
    final storage = _InMemoryCompanionStorage();
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (_) => _overrides(storage),
      child: const HomeShell(),
    );

    await _rightClick(tester, find.byKey(const Key('todo-rail-item-tasks')));
    await tester.tap(find.text(_showCalendar));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-companion')), findsOneWidget);
    expect(storage.writes, 1, reason: '到这里只该写"开启"这一次');

    // 源页 `:39` 只给了「关闭同时显示」这一条回单模块的路径 ⇒ 切到不参与并列的模块
    // 只该由渲染闸门（`home_shell.dart` 的 `pairEligible`）不画副栏，偏好留着；
    // 顺手写 off 就是在没有用户动作的情况下摧毁用户设置。
    await tester.tap(find.byKey(const Key('todo-rail-item-habit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-companion')), findsNothing);
    expect(storage.writes, 1, reason: '切模块不该写盘，第 2 次写就是把偏好清掉');
    expect(storage.value, contains('calendarBesideTasks'));

    await tester.tap(find.byKey(const Key('todo-rail-item-tasks')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('todo-companion')),
      findsOneWidget,
      reason: '回来还按记忆里开着，否则"切看一眼习惯"就静默关掉了并列',
    );
  });

  testWidgets('模块图标有独立读屏语义，且菜单文案不含自创同义词', (tester) async {
    final storage = _InMemoryCompanionStorage();
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (_) => _overrides(storage),
      child: const HomeShell(),
    );

    for (final (key, label) in const [
      ('todo-rail-item-tasks', '任务'),
      ('todo-rail-item-calendar', '日历'),
    ]) {
      final semantics = tester.getSemantics(find.byKey(Key(key)));
      expect(semantics.label, contains(label));
      expect(semantics.flagsCollection.isButton, isTrue);
    }

    await _rightClick(tester, find.byKey(const Key('todo-rail-item-tasks')));
    final labels = _menuLabels(tester);
    expect(labels, isNotEmpty);
    for (final synonym in _inventedSynonyms) {
      expect(
        labels.any((l) => l.contains(synonym)),
        isFalse,
        reason:
            '源页只用「$_showCalendar」/「$_showTasks」/「$_closeCompanion」，'
            '出现「$synonym」就是自创同义词',
      );
    }
  });

  testWidgets('写盘失败时保留已画出的并列，不回滚成单模块', (tester) async {
    // 这条是可判伪的：若 apply() 写成"写失败就把 state 退回 off"，它会红。
    final storage = _ThrowingCompanionStorage();
    await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.populated,
      overridesBuilder: (_) => _overrides(storage),
      child: const HomeShell(),
    );
    await _rightClick(tester, find.byKey(const Key('todo-rail-item-tasks')));
    await tester.tap(find.text(_showCalendar));
    await tester.pumpAndSettle();

    expect(storage.writeAttempts, 1);
    expect(find.byKey(const Key('todo-companion')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('todo-companion')),
        matching: find.byType(CalendarView),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('存储读写只认三种取值，坏值回落到 off', () async {
    final store = WorkspaceCompanionStore(storage: _InMemoryCompanionStorage());
    expect(await store.read(), WorkspaceCompanion.off);

    for (final value in WorkspaceCompanion.values) {
      await store.write(value);
      expect(await store.read(), value);
    }

    for (final bad in const [
      '',
      'not-json',
      '{"companion":"nope"}',
      '{"companion":null}',
      '[]',
    ]) {
      final corrupted = _InMemoryCompanionStorage(bad);
      expect(
        await WorkspaceCompanionStore(storage: corrupted).read(),
        WorkspaceCompanion.off,
        reason: '坏值 $bad 必须回落 off，不能抛',
      );
    }
  });
}
