import 'package:shared_preferences/shared_preferences.dart';

/// 「剪贴板添加任务」开关（FL #343）。
///
/// 判据源：嘀嗒《01-添加任务.md》`:262`「在「设置」-「高级选项」- 开启「剪贴板添加任务」」
/// —— 它是**用户显式开启**的功能，所以默认 **关**。
///
/// 存**本机**（`SharedPreferences`）而不是同步：读剪贴板是**这台设备**的行为，
/// 换了设备该重新问一次（同步过去会让新设备在用户没同意的情况下读剪贴板）。
class ClipboardAddTaskSetting {
  static const _key = 'todo_clipboard_add_task_v1';
  static const defaultEnabled = false;

  Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? defaultEnabled;
  }

  Future<void> write(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
