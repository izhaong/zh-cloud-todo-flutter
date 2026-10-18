import 'package:shared_preferences/shared_preferences.dart';

/// 快速添加底部功能栏（FL #344 面①，服务判据源《01-添加任务.md》`:24`
/// 「添加任务时底部功能栏的顺序支持自定义」）。
///
/// **v1 形状**（opencode 交叉验证定的降面积路线）：
/// - 默认序 `日期 → 优先级 → 标签 → 清单`（产品裁决；原文只列属性不给顺序，默认序为产品补口）；
/// - 渲染**从配置读**（读不到 = 默认序）—— 即使 v1 不给编辑入口，也先走这条路径
///   （硬编码在 widget 里会把"推迟"变成"返工"）；
/// - **id 用稳定 wire 名**（date/priority/tag/list），不用界面文案
///   —— `TaskSwipeAction.wire` 的注释就是这个教训；
/// - 读侧对未知 id / 重复 id / 超量**丢弃兜底**，绝不抛错；
/// - 存**本机**（与 SmartDateRecognitionSetting 同套：输入时的本机行为）。
class QuickAddActionBarSetting {
  static const _key = 'todo_quick_add_action_bar_order_v1';

  /// 默认序（产品裁决；「模板」不进主按钮 —— 归模板能力）。
  static const List<String> defaultOrder = ['date', 'priority', 'tag', 'list'];

  /// 已知 id 全集（写侧校验用：不重复、不缺项、只认已知 id）。
  static const Set<String> knownIds = {'date', 'priority', 'tag', 'list'};

  /// 读顺序；坏数据（未知/重复/缺项/超量）逐条丢弃后回默认序。
  Future<List<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    if (stored == null) return List.of(defaultOrder);
    final cleaned = stored.where(knownIds.contains).toSet().toList();
    if (cleaned.length != defaultOrder.length) {
      return List.of(defaultOrder); // 缺项/重复清完不够 ⇒ 回默认
    }
    return cleaned;
  }

  /// 写顺序（写侧校验：与 knownIds 完全一致才写，坏数据拒收）。
  Future<void> write(List<String> order) async {
    final set = order.toSet();
    // 恰好等于 knownIds：既不缺（少一个按钮）也不多（未知 id 混入会渲染出空位）。
    if (set.length != order.length ||
        !set.containsAll(knownIds) ||
        set.length != knownIds.length) {
      throw ArgumentError.value(order, 'order', '顺序必须包含且仅包含全部已知功能');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, order);
  }

  /// 清除（回默认序）。
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
