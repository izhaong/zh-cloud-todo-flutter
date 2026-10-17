import 'package:shared_preferences/shared_preferences.dart';

/// 「智能识别日期」总开关（FL #344）。
///
/// 判据源：嘀嗒《01-添加任务.md》`:85`「打开应用 - 「设置」-「更多设置」-「智能识别」-
/// 「**智能识别日期**」，即可关闭智能识别功能。」
///
/// 原文说的是"**关闭**"⇒ 默认 **开**（这是既有行为，用户主动关掉它才变）。
/// 存**本机**：识别是输入时的本机行为，换设备该重新问一次。
class SmartDateRecognitionSetting {
  static const _key = 'todo_smart_date_recognition_v1';
  static const defaultEnabled = true;

  Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? defaultEnabled;
  }

  Future<void> write(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
