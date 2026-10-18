import 'dart:async';

/// 语音输入网关（FL #342；嘀嗒《01-添加任务》`:104-107`「长按模式」）。
///
/// **形状**（opencode 交叉验证）：一个接口 + 真实实现（speech_to_text）+ 测试 Fake。
/// 状态机 wire 名用**稳定 id**（照 specs/164 的教训：id 不用界面文案）。
///
/// **v1 两端只消费 `isFinal == true` 的结果**（opencode 修正裁决的一处）：
/// 中间态不上屏、文案不写「实时」⇒「不假装实时」在两端天然成立，
/// 不需要任何平台判断；`:114` 的平台不对称（iOS 逐字 / Android 暂无）
/// 在 v1 **不上屏**，留到第二步做录音模式时再按端处理。
abstract class VoiceInputGateway {
  /// 初始化。false = 不可用（设备不支持 / 权限拒绝 —— 两个终态都要能区分）。
  Future<VoiceInputStatus> initialize();

  /// 开始聆听。结果只消费 `isFinal == true` 的段。
  Future<void> start(VoiceInputListener listener);

  /// 松手即停（`:104`「松手即可完成任务创建」）。
  Future<void> stop();

  /// 释放资源。
  Future<void> dispose();
}

/// 聆听回调。`isFinal == true` 才是可用的任务标题。
abstract class VoiceInputListener {
  void onResult(String text, {required bool isFinal});
  void onStatus(VoiceInputStatus status);
}

/// 状态机（wire id，稳定）：
/// - `available`：可以开始；
/// - `listening`：正在聆听（文案「正在聆听…」—— 不承诺逐字）；
/// - `permissionDenied`：权限被拒（`:114`「按住『+』可能会触发系统权限请求」——
///   裁决：**禁止静默失败**，UI 必须显示「需要麦克风权限才能语音添加」）；
/// - `deviceNotSupported`：设备不支持（Web/模拟器等）；
/// - `error`：其它错误。
enum VoiceInputStatus {
  available,
  listening,
  permissionDenied,
  deviceNotSupported,
  error,
}
