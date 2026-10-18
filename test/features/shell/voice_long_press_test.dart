import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/voice/voice_input_gateway.dart';
import 'package:zh_cloud_todo_flutter/features/shell/quick_add_bar.dart';

/// FL #342 v1：长按「+」语音输入（嘀嗒《01-添加任务》`:104-107`）。
///
/// **测试用 Fake 网关**（真实 STT 在 test 环境必败 —— 判据测状态机与文案，不测识别）。
/// **v1 两端只消费 isFinal**（opencode 修正裁决）：中间态不上屏、文案不写「实时」⇒
/// 「不假装实时」天然成立，无平台判断。
class _FakeGateway implements VoiceInputGateway {
  _FakeGateway(this.initialStatus);

  final VoiceInputStatus initialStatus;
  VoiceInputListener? listener;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<VoiceInputStatus> initialize() async => initialStatus;

  @override
  Future<void> start(VoiceInputListener l) async {
    listener = l;
    startCalls++;
    l.onStatus(VoiceInputStatus.listening);
    // 模拟一段最终识别结果
    l.onResult('买牛奶', isFinal: true);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}

Widget _host(MobileQuickAddButton button) =>
    MaterialApp(home: Scaffold(floatingActionButton: button));

void main() {
  testWidgets('长按 + 进入语音态，overlay 显示「说出你要做的事…」', (tester) async {
    final fake = _FakeGateway(VoiceInputStatus.available);
    await tester.pumpWidget(
      _host(MobileQuickAddButton(onSubmit: (_) {}, voiceGateway: fake)),
    );

    await tester.startGesture(
      tester.getCenter(find.byKey(const Key('todo-mobile-add'))),
    );
    // Listener+Timer 不进竞技场：按住 600ms 触发语音（手势仍按住 —— overlay 应在）
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const Key('todo-voice-listening')),
      findsOneWidget,
      reason: '长按 500ms 应进入语音聆听态（:104「长按「+」按钮启动语音输入」）',
    );
  });

  testWidgets('权限被拒：overlay 显示文案、不静默失败（裁决②）', (tester) async {
    final fake = _FakeGateway(VoiceInputStatus.permissionDenied);
    await tester.pumpWidget(
      _host(MobileQuickAddButton(onSubmit: (_) {}, voiceGateway: fake)),
    );

    await tester.startGesture(
      tester.getCenter(find.byKey(const Key('todo-mobile-add'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();

    expect(
      find.byKey(const Key('todo-voice-permission-denied')),
      findsOneWidget,
      reason: '裁决②原文：权限拒绝必须显示「需要麦克风权限才能语音添加」—— 禁止静默失败',
    );
    expect(find.text('需要麦克风权限才能语音添加'), findsOneWidget);
  });

  testWidgets('设备不支持：终态化文案，不假装可用', (tester) async {
    final fake = _FakeGateway(VoiceInputStatus.deviceNotSupported);
    await tester.pumpWidget(
      _host(MobileQuickAddButton(onSubmit: (_) {}, voiceGateway: fake)),
    );

    await tester.startGesture(
      tester.getCenter(find.byKey(const Key('todo-mobile-add'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();

    expect(find.byKey(const Key('todo-voice-unsupported')), findsOneWidget);
  });

  testWidgets('松手结束：stop 被调，isFinal 文本经 onSubmit 创建任务（:104「松手即可完成任务创建」）', (
    tester,
  ) async {
    final submitted = <QuickAddRequest>[];
    final fake = _FakeGateway(VoiceInputStatus.available);
    await tester.pumpWidget(
      _host(MobileQuickAddButton(onSubmit: submitted.add, voiceGateway: fake)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('todo-mobile-add'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(fake.stopCalls, 1, reason: '松手必须调 stop（:104 松手即完成）');
    expect(submitted, hasLength(1));
    expect(submitted.single.input, '买牛奶');
  });

  testWidgets('网关未注入（装配缺失）：显示不支持而非静默', (tester) async {
    await tester.pumpWidget(_host(MobileQuickAddButton(onSubmit: (_) {})));

    await tester.startGesture(
      tester.getCenter(find.byKey(const Key('todo-mobile-add'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();

    expect(
      find.byKey(const Key('todo-voice-unsupported')),
      findsOneWidget,
      reason: 'voiceGateway null（装配缺失）⇒ 终态化，不假装支持',
    );
  });

  testWidgets('点 + 仍打开快速添加表（既有通道不弄红）', (tester) async {
    await tester.pumpWidget(
      _host(
        MobileQuickAddButton(
          onSubmit: (_) {},
          voiceGateway: _FakeGateway(VoiceInputStatus.available),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('todo-mobile-add')));
    await tester.pumpAndSettle();

    expect(
      find.byType(BottomSheet),
      findsOneWidget,
      reason: '点击（不产生位移）仍归 FloatingActionButton —— 拖/点/长按三条通道并存',
    );
  });
}
