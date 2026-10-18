import 'package:speech_to_text/speech_to_text.dart';

import 'voice_input_gateway.dart';

/// [VoiceInputGateway] 的 speech_to_text 实现（平台原生 STT —— 裁决①，
/// 不上云 ASR）。
///
/// **只消费 isFinal**（见接口注释）：`speech_to_text` 在 iOS/Android 都能给出
/// 最终识别结果，差别只在中间态有没有逐字 —— v1 不消费中间态，两端行为一致。
class SpeechToTextGateway implements VoiceInputGateway {
  final SpeechToText _stt = SpeechToText();
  VoiceInputListener? _listener;
  bool _initialized = false;

  @override
  Future<VoiceInputStatus> initialize() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (s) => _mapStatus(s),
        onError: (e) => _mapError(e),
      );
      if (!ok) {
        return VoiceInputStatus.deviceNotSupported;
      }
      _initialized = true;
      return VoiceInputStatus.available;
    } on Exception {
      // speech_to_text 在权限被拒时抛 ErrorModel / 异常 —— 网关把它归并成
      // 两个明确终态，不静默。
      return VoiceInputStatus.permissionDenied;
    }
  }

  void _mapStatus(String s) {
    if (s == 'listening') {
      _listener?.onStatus(VoiceInputStatus.listening);
    } else if (s == 'notListening') {
      // 停止由 stop() 驱动，不映射
    }
  }

  /// 错误分类**不取异常原文**（raw-error 门禁）：speech_to_text 的
  /// ErrorModel 带 errorType 字段 —— 按 errorType 分类；类型缺失时归
  /// `error`（generic），不去 parse 字符串（parse 显示串正是门禁禁的形态）。
  void _mapError(dynamic e) {
    // speech_to_text 7.x 的 onError 传 ErrorModel（带 errorType 字段）。
    // 按 errorType 分类；字段缺失时归 generic —— 不取异常原文（raw-error 门禁）。
    final type = (e is Map && e['errorType'] is String)
        ? e['errorType'] as String
        : null;
    if (type == 'permissions-missing' ||
        type == 'permission-denied' ||
        type == 'service-not-allowed') {
      _listener?.onStatus(VoiceInputStatus.permissionDenied);
    } else {
      _listener?.onStatus(VoiceInputStatus.error);
    }
  }

  @override
  Future<void> start(VoiceInputListener listener) async {
    if (!_initialized) {
      final status = await initialize();
      if (status != VoiceInputStatus.available) {
        listener.onStatus(status);
        return;
      }
    }
    _listener = listener;
    await _stt.listen(
      onResult: (r) =>
          listener.onResult(r.recognizedWords, isFinal: r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true, // 平台给中间态就收着，但 v1 只消费 isFinal
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (_initialized) {
      await _stt.stop();
    }
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _stt.cancel();
    }
    _listener = null;
  }
}
