import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/task/views/eisenhower_view.dart' show Quadrant;

/// 单个象限规则：最小优先级（>= 视为"重要"）+ 紧急 due 阈值（<= 视为"紧急"）。
class QuadrantRule {
  const QuadrantRule({required this.minPriority, this.urgentDueWithinHours});

  final int minPriority;
  final int? urgentDueWithinHours;
}

/// 内置默认规则；完整版规则编辑通过 `/app-api/todo/quadrant-rule`。
final quadrantRulesProvider = StateProvider<Map<Quadrant, QuadrantRule>>(
  (ref) => const {
    Quadrant.q1: QuadrantRule(minPriority: 2, urgentDueWithinHours: 24),
    Quadrant.q2: QuadrantRule(minPriority: 2),
    Quadrant.q3: QuadrantRule(minPriority: 0, urgentDueWithinHours: 24),
    Quadrant.q4: QuadrantRule(minPriority: 0),
  },
);
