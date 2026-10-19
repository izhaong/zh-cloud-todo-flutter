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

  // ── FL #342 第二步：录音模式（`:116-119`「长按并左右拖动切换…松手继续…
  // 点击停止结束，保存文字内容」；`:123` 30 分钟上限自动保存）──

  testWidgets('长按后左右拖 ⇒ 录音模式：松手不结束，点停止才保存文字', (tester) async {
    final submitted = <QuickAddRequest>[];
    final fake = _FakeGateway(VoiceInputStatus.available);
    await tester.pumpWidget(
      _host(MobileQuickAddButton(onSubmit: submitted.add, voiceGateway: fake)),
    );

    // 按住（500ms 长按起表）后向右拖 60px（阈值 48）⇒ 切录音模式
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('todo-mobile-add'))),
    );
    // 按住越过 500ms（长按起表）—— 8x50 只有 400ms。
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(60, 0));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.byKey(const Key('todo-voice-recording')),
      findsOneWidget,
      reason: ':116「长按并向左/向右拖动，切换到录音模式」',
    );

    // 松手不结束（:117「松手继续输入，不用一直按住」）
    await gesture.up();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.byKey(const Key('todo-voice-recording')),
      findsOneWidget,
      reason: ':117 录音模式松手**不结束** —— 一直按住才是听写模式',
    );
    expect(submitted, isEmpty, reason: '还没点停止，不该建任务');

    // 点停止（:118「点击停止按钮即可结束录音，保存文字内容」）
    final stop = find.byKey(const Key('todo-voice-stop'));
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fake.stopCalls, 1, reason: '停止必须调 stop');
    expect(submitted, hasLength(1));
    expect(submitted.single.input, '买牛奶', reason: '保存的是文字内容');
    expect(
      find.byKey(const Key('todo-voice-recording')),
      findsNothing,
      reason: '结束后录音态消失',
    );
  });
}
