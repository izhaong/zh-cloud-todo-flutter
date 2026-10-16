import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/todo_layout_tokens.dart';

/// Stable date/business group label used by the flat task list.
///
/// 参照滴答：分组标题前带一枚折叠箭头（▾），表示这一组可收起/展开。
/// 未接折叠回调时只画静态箭头，保持与参照图一致的视觉语言。
class TaskGroupHeader extends StatelessWidget {
  const TaskGroupHeader({
    super.key,
    required this.title,
    required this.count,
    this.collapsed = false,
    this.onToggle,
  });

  final String title;
  final int count;

  /// 当前是否已收起；收起时箭头转向（▸）。
  final bool collapsed;

  /// 点击分组标题切换收起/展开；为 null 时标题不可点。
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final row = Row(
      children: [
        // 折叠箭头：参照图里它就是分组标题的一部分，且比标题文字更淡。
        SizedBox(
          width: 18,
          child: Icon(
            collapsed
                ? Icons.keyboard_arrow_right_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: colors.mutedForeground,
          ),
        ),
        Text(
          title,
          style: AppTextStyles.groupHeader.copyWith(color: colors.foreground),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: AppTextStyles.metadata.copyWith(color: colors.mutedForeground),
        ),
      ],
    );

    return SizedBox(
      height: TodoLayoutTokens.groupHeaderMinHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TodoLayoutTokens.mainHorizontalInset,
        ),
        // 有回调时整行可点（含箭头的 18px 槽位），命中区域覆盖标题与计数。
        child: onToggle == null
            ? row
            : InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: row,
              ),
      ),
    );
  }
}
