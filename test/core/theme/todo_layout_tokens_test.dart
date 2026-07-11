import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/core/theme/todo_layout_tokens.dart';

void main() {
  test('workspace geometry and density match the UI contract', () {
    expect(TodoLayoutTokens.railWidth, 56);
    expect(TodoLayoutTokens.wideSidebarWidth, 272);
    expect(TodoLayoutTokens.compactSidebarWidth, 256);
    expect(TodoLayoutTokens.wideDetailWidth, 432);
    expect(TodoLayoutTokens.workspaceHeaderHeight, 56);
    expect(TodoLayoutTokens.quickAddHeight, 44);
    expect(TodoLayoutTokens.sidebarRowHeight, 40);
    expect(TodoLayoutTokens.taskRowSingleLineHeight, 44);
    expect(TodoLayoutTokens.taskRowMetadataHeight, 58);
    expect(TodoLayoutTokens.mainHorizontalInset, 24);
    expect(TodoLayoutTokens.groupHeaderMinHeight, 36);
    expect(TodoLayoutTokens.selectedRowRadius, 8);
    expect(TodoLayoutTokens.checkboxVisualSize, 18);
    expect(TodoLayoutTokens.checkboxTapTargetSize, 36);
  });

  test('state motion remains within the approved subtle range', () {
    expect(
      TodoLayoutTokens.stateTransitionDuration,
      const Duration(milliseconds: 140),
    );
    expect(
      TodoLayoutTokens.stateTransitionDuration.inMilliseconds,
      inInclusiveRange(120, 160),
    );
  });

  test('light semantic palette is neutral and product-owned', () {
    expect(TodoLayoutTokens.lightCanvas, const Color(0xFFF7F7F7));
    expect(TodoLayoutTokens.lightSurface, const Color(0xFFFFFFFF));
    expect(TodoLayoutTokens.lightPrimaryText, const Color(0xFF242424));
    expect(TodoLayoutTokens.lightMutedText, const Color(0xFF8A8A8A));
    expect(TodoLayoutTokens.lightDivider, const Color(0xFFECECEC));
    expect(TodoLayoutTokens.lightHoverRow, const Color(0xFFF7F7F7));
    expect(TodoLayoutTokens.lightSelectedRow, const Color(0xFFF2F2F2));

    expect(AppColors.light.background, TodoLayoutTokens.lightCanvas);
    expect(AppColors.light.surface, TodoLayoutTokens.lightSurface);
    expect(AppColors.light.foreground, TodoLayoutTokens.lightPrimaryText);
    expect(AppColors.light.mutedForeground, TodoLayoutTokens.lightMutedText);
    expect(AppColors.light.border, TodoLayoutTokens.lightDivider);
  });
}
