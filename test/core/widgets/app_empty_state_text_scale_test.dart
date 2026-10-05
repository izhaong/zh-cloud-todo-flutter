import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/widgets/app_widgets.dart';

/// Issue #498：空状态在系统大字号下会把 Column 撑出可视高度（iOS 实测溢出 55px）。
///
/// 判据取「渲染层不再抛 RenderFlex overflow」而不是截图像素，
/// 这样文本缩放档位变化不会被误读成界面回归。
void main() {
  testWidgets('empty state fits a short pane at 2.0 text scale without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 320 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          // 生产里空状态出现在固定高度的面板内（提醒收件箱/工作区右栏），
          // 所以判据必须在「高度有界」的容器里量；无界高度下父容器本来就不裁。
          home: SizedBox(
            height: 320,
            child: AppEmptyState(
              title: '暂无提醒',
              subtitle: '给任务设置提醒后，到点会在这里出现。',
              action: const Text('查看全部任务'),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'h=2.0 时空状态超出可视高度会抛 RenderFlex overflow（真机实测 55px）',
    );
    expect(find.text('暂无提醒'), findsOneWidget);
    expect(find.text('给任务设置提醒后，到点会在这里出现。'), findsOneWidget);
  });
}
