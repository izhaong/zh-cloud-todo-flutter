import 'package:flutter/material.dart';

/// Shared geometry, density, state colors, and motion for the Todo workspace.
///
/// Keeping these values in one place prevents shell, sidebar, and task widgets
/// from drifting apart as the same product adapts across desktop and mobile.
abstract final class TodoLayoutTokens {
  // Responsive profiles.
  static const double wideMinWidth = 1366;
  static const double compactMinWidth = 1100;
  static const double tabletMinWidth = 600;
  static const double minWideContentWidth = 520;

  // Workspace regions.
  static const double railWidth = 56;
  static const double wideSidebarWidth = 272;
  static const double compactSidebarWidth = 256;
  static const double wideDetailWidth = 432;
  static const double detailDrawerMaxWidth = 432;
  static const double workspaceHeaderHeight = 56;
  static const double mainHorizontalInset = 24;

  // Dense controls and list rows.
  static const double quickAddHeight = 44;
  static const double sidebarRowHeight = 40;
  static const double sidebarGroupTitleHeight = 32;
  static const double sidebarOuterInset = 8;
  static const double sidebarHeaderInset = 16;
  static const double sidebarRowContentInset = 12;
  static const double sidebarIconGap = 10;
  static const double sidebarSectionGap = 8;
  static const double sidebarFooterGap = 16;
  static const double sidebarIconSize = 18;
  static const double taskRowSingleLineHeight = 44;
  static const double taskRowMetadataHeight = 58;
  static const double groupHeaderMinHeight = 36;
  static const double selectedRowRadius = 8;
  static const double checkboxVisualSize = 18;
  static const double checkboxTapTargetSize = 36;
  static const double checkboxStrokeWidth = 1.5;

  // State feedback.
  static const Duration stateTransitionDuration = Duration(milliseconds: 140);

  static Duration stateTransitionDurationFor(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations ?? false
        ? Duration.zero
        : stateTransitionDuration;
  }

  // Approved light semantic palette.
  static const Color lightCanvas = Color(0xFFF7F7F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimaryText = Color(0xFF242424);
  static const Color lightMutedText = Color(0xFF8A8A8A);
  static const Color lightDivider = Color(0xFFECECEC);
  static const Color lightHoverRow = Color(0xFFF7F7F7);
  static const Color lightSelectedRow = Color(0xFFF2F2F2);

  // Dark equivalents preserve the same hierarchy without copying a third-party
  // dark theme. They remain intentionally quiet and are resolved by brightness.
  static const Color darkCanvas = Color(0xFF1A1A1A);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkDivider = Color(0xFF3A3A3A);
  static const Color darkHoverRow = Color(0xFF303030);
  static const Color darkSelectedRow = Color(0xFF383838);

  static Color canvasFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkCanvas : lightCanvas;

  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color dividerFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkDivider : lightDivider;

  static Color hoverRowFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkHoverRow : lightHoverRow;

  static Color selectedRowFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSelectedRow : lightSelectedRow;
}
