import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/brand_colors.dart';
import '../../state/providers.dart';
import '../../state/repositories/sidebar_visibility_repository.dart';
import 'section.dart';

/// 「智能清单管理」弹层（specs/103）。
///
/// 嘀嗒《02-用清单管理任务.md》:29「点击侧边栏「添加清单」右边的「设置」，
/// 即可打开「智能清单管理」页面」；:45 三态；:20「收集箱是不可以被隐藏或删除」。
class SmartListManagerSheet extends ConsumerWidget {
  const SmartListManagerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: SmartListManagerSheet()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(sidebarVisibilityRepositoryProvider);
    final states =
        ref.watch(sidebarSmartListStatesProvider).valueOrNull ??
        const <String, SmartListVisibility>{};

    return Padding(
      key: const Key('todo-smart-list-manager-sheet'),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('智能清单管理', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final smart in SmartList.values)
                  _SmartListManagerRow(
                    smart: smart,
                    state: states[smart.name] ?? SmartListVisibility.show,
                    enabled: repository != null,
                    onChanged: (value) =>
                        repository?.saveSmartListState(smart.name, value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartListManagerRow extends ConsumerWidget {
  const _SmartListManagerRow({
    required this.smart,
    required this.state,
    required this.enabled,
    required this.onChanged,
  });

  final SmartList smart;
  final SmartListVisibility state;
  final bool enabled;
  final ValueChanged<SmartListVisibility> onChanged;

  /// 「有内容时显示」只给有内容判定的清单：垃圾桶本端还没有内容载体
  /// （specs/103 FR-5），不给一个永远判定为"没内容"的档位。
  static const _autoCapable = {
    SmartList.today,
    SmartList.tomorrow,
    SmartList.upcoming,
    SmartList.all,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);

    // 嘀嗒 :20：收集箱不可隐藏或删除。仓储层还有一道守卫，这里是界面呈现。
    if (smart == SmartList.inbox) {
      return ListTile(
        key: Key('todo-smart-list-manager-${smart.name}'),
        leading: Icon(smart.icon, color: colors.mutedForeground),
        title: Text(smart.label, style: TextStyle(color: colors.foreground)),
        trailing: Text('显示', style: TextStyle(color: colors.mutedForeground)),
        subtitle: const Text('收集箱不可隐藏或删除'),
      );
    }

    final segments = <ButtonSegment<SmartListVisibility>>[
      const ButtonSegment(value: SmartListVisibility.show, label: Text('显示')),
      const ButtonSegment(value: SmartListVisibility.hide, label: Text('隐藏')),
      if (_autoCapable.contains(smart))
        const ButtonSegment(
          value: SmartListVisibility.auto,
          label: Text('有内容时显示'),
        ),
    ];

    return ListTile(
      key: Key('todo-smart-list-manager-${smart.name}'),
      leading: Icon(smart.icon, color: colors.mutedForeground),
      title: Text(smart.label, style: TextStyle(color: colors.foreground)),
      subtitle: SegmentedButton<SmartListVisibility>(
        segments: segments,
        selected: {state},
        showSelectedIcon: false,
        // 未就绪时只读：写不进去的开关不该假装能点。
        onSelectionChanged: enabled
            ? (selection) => onChanged(selection.first)
            : null,
      ),
    );
  }
}
