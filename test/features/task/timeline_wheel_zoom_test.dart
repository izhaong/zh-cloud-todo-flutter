import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/views/timeline_view.dart';

/// 嘀嗒《03-特色功能/09-桌面快捷操作.md:107》：
/// 「按住 **Ctrl**（或 Mac 上的 **Command**）再滚动鼠标滚轮，即可缩放日视图或周视图中的时间轴」。
///
/// 本仓此前没有任何滚轮用例（动手前 `git grep PointerScrollEvent origin/develop -- test` 0 命中），
/// 所以第 4 条用例自带**正向对照**：先证明"无修饰键的滚轮确实会横向滚动画布"，
/// 否则「缩放时滚动位置不动」那句断言是恒真的假断言。
void main() {
  Future<List<double>> pumpTimeline(
    WidgetTester tester, {
    required double zoom,
    TimelineScale scale = TimelineScale.week,
    bool writable = true,
  }) async {
    final calls = <double>[];
    await tester.pumpWidget(
      ProviderScope(
        // 与 test/m11_b3_eisenhower_test.dart:91-93 同形：MaterialApp 提供 Overlay，
        // 否则时间轴上的 IconButton(tooltip:) 会抛 "No Overlay widget found"。
        child: MaterialApp(
          home: Scaffold(
            body: _WheelZoomHost(
              initialZoom: zoom,
              scale: scale,
              onZoom: writable ? calls.add : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  final canvas = find.byType(SingleChildScrollView);

  /// 时间轴画布上的滚轮：hover 落指位 → 按修饰键 → 发 PointerScrollEvent。
  Future<void> wheel(
    WidgetTester tester,
    double scrollDeltaY, {
    LogicalKeyboardKey? modifier,
  }) async {
    final center = tester.getCenter(canvas.first);
    if (modifier != null) await tester.sendKeyDownEvent(modifier);
    await tester.sendEventToBinding(
      PointerHoverEvent(position: center, kind: PointerDeviceKind.mouse),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        kind: PointerDeviceKind.mouse,
        scrollDelta: Offset(0, scrollDeltaY),
      ),
    );
    await tester.pump();
    if (modifier != null) await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  ScrollPosition canvasPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(of: canvas.first, matching: find.byType(Scrollable))
            .first,
      )
      .position;

  double canvasOffset(WidgetTester tester) => canvasPosition(tester).pixels;

  testWidgets('Ctrl + 滚轮向上放大时间轴（嘀嗒 :107）', (tester) async {
    final calls = await pumpTimeline(tester, zoom: 1.0);
    await wheel(tester, -120, modifier: LogicalKeyboardKey.controlLeft);
    expect(calls, [1.25], reason: 'Ctrl+滚轮向上应放大一档，步长与工具栏按钮一致（_step=0.25）');
  });

  testWidgets('Command + 滚轮向下缩小（macOS 侧）', (tester) async {
    final calls = await pumpTimeline(tester, zoom: 1.0);
    await wheel(tester, 120, modifier: LogicalKeyboardKey.metaLeft);
    expect(calls, [0.75], reason: 'Command+滚轮向下应缩小一档');
  });

  testWidgets('没有修饰键时滚轮不缩放（让位给滚动）', (tester) async {
    final calls = await pumpTimeline(tester, zoom: 1.0);
    await wheel(tester, 120);
    expect(calls, isEmpty, reason: '裸滚轮必须仍然只滚动，不能顺手改缩放');
  });

  testWidgets('Shift+滚轮只滚画布不缩放；Ctrl+滚轮只缩放不滚画布', (tester) async {
    // 用 day 档：24 小时槽位铺出来的画布一定宽于测试视口，画布才有可滚动范围。
    final calls = await pumpTimeline(
      tester,
      zoom: 1.0,
      scale: TimelineScale.day,
    );
    // 前提本身要断言，否则"滚不动"会被误读成"没被快捷键抢走"。
    expect(
      canvasPosition(tester).maxScrollExtent,
      greaterThan(0),
      reason: '画布必须有可滚动范围，否则后面的对照没有牙齿',
    );
    // 正向对照：横向画布的滚轮取 scrollDelta.dx，轴翻转只在 pointerAxisModifiers
    // （默认 Shift）下发生（scrollable.dart:933-950）⇒ 用 Shift 证明"这个面确实会被滚轮推动"。
    await wheel(tester, 240, modifier: LogicalKeyboardKey.shiftLeft);
    final afterShift = canvasOffset(tester);
    expect(
      afterShift,
      greaterThan(0),
      reason: 'Shift+滚轮应把横向画布推动；推不动就说明这条对照没牙齿，下面的断言会是假的',
    );
    expect(calls, isEmpty, reason: 'Shift 不是嘀嗒 :107 的修饰键，不该触发缩放');
    // 现在换成 Ctrl：缩放要发生，画布位置必须停在 afterShift 不动。
    await wheel(tester, -120, modifier: LogicalKeyboardKey.controlLeft);
    expect(calls, [1.25], reason: 'Ctrl+滚轮向上放大一档');
    expect(
      canvasOffset(tester),
      afterShift,
      reason: 'Ctrl+滚轮只缩放；画布位置一动就说明两个效果叠在一起了',
    );
  });

  testWidgets('已到上限时 Command+滚轮向上不再回调（与按钮禁用边界一致）', (tester) async {
    final calls = await pumpTimeline(tester, zoom: 1.5);
    await wheel(tester, -120, modifier: LogicalKeyboardKey.metaLeft);
    expect(calls, isEmpty, reason: '1.5 是上限，向上放大不该再报一次 1.5');
  });

  testWidgets('已到下限时 Ctrl+滚轮向下不再回调（:614 那颗按钮此时也是禁用的）', (tester) async {
    final calls = await pumpTimeline(tester, zoom: 0.75);
    await wheel(tester, 120, modifier: LogicalKeyboardKey.controlLeft);
    expect(calls, isEmpty, reason: '0.75 是下限，向下缩小不该再报一次 0.75');
  });

  testWidgets('onZoomChanged 为 null 时滚轮不抛异常', (tester) async {
    await pumpTimeline(tester, zoom: 1.0, writable: false);
    await wheel(tester, 120, modifier: LogicalKeyboardKey.controlLeft);
    expect(tester.takeException(), isNull);
  });
}

/// 受控宿主：把 `onZoomChanged` 报来的新值真喂回 `TimelineView.zoom`。
///
/// 生产组件的缩放是外部受控的，若测试直接把 zoom 写成常量，则画布宽度永不随缩放变化，
/// 「Ctrl+滚轮只缩放、不推动画布」那句 `pixels` 断言就结构性无法失败。
class _WheelZoomHost extends StatefulWidget {
  const _WheelZoomHost({
    required this.initialZoom,
    required this.scale,
    this.onZoom,
  });

  final double initialZoom;
  final TimelineScale scale;
  final void Function(double zoom)? onZoom;

  @override
  State<_WheelZoomHost> createState() => _WheelZoomHostState();
}

class _WheelZoomHostState extends State<_WheelZoomHost> {
  late double _zoom = widget.initialZoom;

  @override
  Widget build(BuildContext context) {
    return TimelineView(
      tasks: const [],
      now: DateTime(2026, 9, 24, 10),
      zoom: _zoom,
      scale: widget.scale,
      onZoomChanged: widget.onZoom == null
          ? null
          : (value) async {
              widget.onZoom!(value);
              setState(() => _zoom = value);
            },
    );
  }
}
