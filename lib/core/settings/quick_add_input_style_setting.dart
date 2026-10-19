import 'package:shared_preferences/shared_preferences.dart';

/// FL #344 面④：输入框样式（嘀嗒《01-添加任务》`:54`
/// 「点击『输入框设置』切换输入框样式」）。
///
/// 三种样式（产品裁决；id 用稳定 wire 名 —— 照 `QuickAddActionBarSetting`
/// 的教训不用界面文案）：
/// - `inline`：桌面清单内联输入框（回车即建）—— **默认**（= 现状，不改既有体验）；
/// - `collapsed`：收起单行快速添加（工具行不显示，只剩一行输入 —— 最低噪声）；
/// - `expanded`：展开带底部功能栏的完整添加。
///
/// 原文入口是**输入框右侧下拉 → 输入框设置**（不是设置页）；v1 先落设置页
/// 「任务」分区（紧邻「智能识别日期」），下拉入口随桌面壳成熟度另刀。
class QuickAddInputStyleSetting {
  static const _key = 'todo_quick_add_input_style_v1';

  static const defaultStyle = 'inline';
  static const knownStyles = {'inline', 'collapsed', 'expanded'};

  /// 读样式；坏值（未知 id）回默认，绝不抛错。
  Future<String> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null || !knownStyles.contains(stored)) {
      return defaultStyle;
    }
    return stored;
  }

  /// 写样式（写侧校验：只认已知 id，坏值拒收）。
  Future<void> write(String style) async {
    if (!knownStyles.contains(style)) {
      throw ArgumentError.value(style, 'style', '未知输入框样式');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, style);
  }

  /// 清除（回默认样式）。
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
