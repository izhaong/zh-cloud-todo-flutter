import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/quadrant_rules.dart';
import '../task/views/eisenhower_view.dart' show Quadrant;

/// 四象限规则编辑（客户端规则集）。
///
/// 服务端规则编辑走 `/app-api/todo/quadrant-rule`；这里先把规则页接到
/// `quadrantRulesProvider`，等管理端补齐 CRUD 后切换为后端远端规则。
class QuadrantRulesPage extends ConsumerWidget {
  const QuadrantRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(quadrantRulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('四象限规则')),
      body: ListView(
        children: [
          for (final q in Quadrant.values)
            ListTile(
              title: Text(quadrantLabel(q)),
              subtitle: Text(quadrantDescription(rules[q])),
              leading: Icon(quadrantIcon(q), color: quadrantColor(q)),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '规则说明：priority 阈值用于把任务按"重要/紧急"二维网格分类；'
              '截止时间在 24h 内视为紧急。本地内置规则，可在管理端联动调整。',
            ),
          ),
        ],
      ),
    );
  }

  String quadrantLabel(Quadrant q) => switch (q) {
        Quadrant.q1 => 'Q1 重要且紧急',
        Quadrant.q2 => 'Q2 重要不紧急',
        Quadrant.q3 => 'Q3 紧急不重要',
        Quadrant.q4 => 'Q4 不紧急不重要',
      };

  IconData quadrantIcon(Quadrant q) => switch (q) {
        Quadrant.q1 => Icons.local_fire_department,
        Quadrant.q2 => Icons.schedule,
        Quadrant.q3 => Icons.forward_to_inbox,
        Quadrant.q4 => Icons.dashboard_customize_outlined,
      };

  Color quadrantColor(Quadrant q) => switch (q) {
        Quadrant.q1 => Colors.red,
        Quadrant.q2 => Colors.amber,
        Quadrant.q3 => Colors.lightBlue,
        Quadrant.q4 => Colors.grey,
      };

  String quadrantDescription(QuadrantRule? r) {
    if (r == null) return '';
    final urgency = r.urgentDueWithinHours != null
        ? '${r.urgentDueWithinHours} 小时内截止视为紧急'
        : '无截止也归此类';
    return 'priority ≥ ${r.minPriority} · $urgency';
  }
}
