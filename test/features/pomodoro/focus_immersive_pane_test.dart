import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/pomodoro/focus_immersive_pane.dart';
import 'package:zh_cloud_todo_flutter/features/pomodoro/focus_immersion_settings.dart';

void main() {
  testWidgets('immersive pane exposes timer style and reachable controls', (
    tester,
  ) async {
    final actions = _Actions();
    final semantics = tester.ensureSemantics();
    await _pump(tester, actions: actions);

    expect(find.byKey(const Key('focus-immersive-pane')), findsOneWidget);
    expect(find.bySemanticsLabel('沉浸计时：12 分 34 秒，简约数字样式'), findsOneWidget);
    expect(find.text('退出沉浸'), findsNothing);

    await tester.tap(find.byKey(const Key('focus-immersive-timer')));
    await tester.pump();
    expect(find.text('退出沉浸'), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.tap(find.text('完成'));
    await tester.tap(find.text('取消'));
    await tester.tap(find.text('退出沉浸'));
    expect(actions.pauseOrResume, 1);
    expect(actions.complete, 1);
    expect(actions.cancel, 1);
    expect(actions.exit, 1);
    semantics.dispose();
  });

  testWidgets('immersive pane keeps all three styles accessible at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final style in FocusTimerStyle.values) {
      await _pump(
        tester,
        style: style,
        textScaler: const TextScaler.linear(1.3),
      );
      expect(
        find.byKey(Key('focus-immersive-style-${style.name}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('paused immersive pane uses the resume action', (tester) async {
    final actions = _Actions();
    await _pump(tester, actions: actions, paused: true, controlsVisible: true);

    expect(find.text('恢复'), findsOneWidget);
    await tester.tap(find.text('恢复'));
    expect(actions.pauseOrResume, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  _Actions? actions,
  FocusTimerStyle style = FocusTimerStyle.digital,
  bool paused = false,
  bool controlsVisible = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final callbacks = actions ?? _Actions();
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: _PaneHarness(
            style: style,
            seconds: 754,
            paused: paused,
            initialControlsVisible: controlsVisible,
            onPauseOrResume: () => callbacks.pauseOrResume++,
            onComplete: () => callbacks.complete++,
            onCancel: () => callbacks.cancel++,
            onExit: () => callbacks.exit++,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _Actions {
  int pauseOrResume = 0;
  int complete = 0;
  int cancel = 0;
  int exit = 0;
}

class _PaneHarness extends StatefulWidget {
  const _PaneHarness({
    required this.style,
    required this.seconds,
    required this.paused,
    required this.initialControlsVisible,
    required this.onPauseOrResume,
    required this.onComplete,
    required this.onCancel,
    required this.onExit,
  });

  final FocusTimerStyle style;
  final int seconds;
  final bool paused;
  final bool initialControlsVisible;
  final VoidCallback onPauseOrResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onExit;

  @override
  State<_PaneHarness> createState() => _PaneHarnessState();
}

class _PaneHarnessState extends State<_PaneHarness> {
  late bool _controlsVisible = widget.initialControlsVisible;

  @override
  Widget build(BuildContext context) {
    return FocusImmersivePane(
      style: widget.style,
      seconds: widget.seconds,
      paused: widget.paused,
      controlsVisible: _controlsVisible,
      onToggleControls: () {
        setState(() => _controlsVisible = !_controlsVisible);
      },
      onPauseOrResume: widget.onPauseOrResume,
      onComplete: widget.onComplete,
      onCancel: widget.onCancel,
      onExit: widget.onExit,
    );
  }
}
