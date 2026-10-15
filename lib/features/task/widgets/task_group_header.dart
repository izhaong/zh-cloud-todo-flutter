import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/todo_layout_tokens.dart';

/// Stable date/business group label used by the flat task list.
class TaskGroupHeader extends StatelessWidget {
  const TaskGroupHeader({super.key, required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      height: TodoLayoutTokens.groupHeaderMinHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TodoLayoutTokens.mainHorizontalInset,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: AppTextStyles.groupHeader.copyWith(
                color: colors.foreground,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: AppTextStyles.metadata.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
