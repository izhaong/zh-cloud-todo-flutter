import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// 习惯页右上角的「在“今天”、“最近7天”中显示」入口
/// （嘀嗒《02-更好地完成习惯.md》:66；specs/130，矩阵 #45 面 ⑤）。
///
/// 弹层一枚开关：开着 ⇒ 习惯出现在「今天」「最近7天」智能清单
/// （[habitSmartListEntriesProvider] 驱动）。
class HabitSmartListVisibilityAction extends ConsumerStatefulWidget {
  const HabitSmartListVisibilityAction({super.key});

  @override
  ConsumerState<HabitSmartListVisibilityAction> createState() =>
      _HabitSmartListVisibilityActionState();
}

class _HabitSmartListVisibilityActionState
    extends ConsumerState<HabitSmartListVisibilityAction> {
  @override
  Widget build(BuildContext context) {
    final visible =
        ref.watch(habitSmartListVisibilityProvider).valueOrNull ?? false;
    return Semantics(
      label: '在“今天”、“最近7天”中显示',
      button: true,
      child: IconButton(
        key: const Key('habit-smart-list-entry'),
        tooltip: '在“今天”、“最近7天”中显示',
        icon: Icon(
          Icons.playlist_add_check_rounded,
          color: visible ? Theme.of(context).colorScheme.primary : null,
        ),
        onPressed: () => _toggle(context, visible),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, bool current) async {
    final repo = ref.read(habitSmartListPreferenceRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await repo.save(!current);
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text((!current ? '已在“今天”、“最近7天”中显示习惯' : '已不在智能清单中显示习惯')),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(const SnackBar(content: Text('设置保存失败，请重试')));
    }
  }
}
