import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../shell/section.dart';
import '../shell/sidebar.dart';
import '../task/task_search_page.dart';

enum TodoWorkspaceProfile { wide, compact, tablet, mobile }

typedef TodoDetailDrawerChanged =
    void Function(TodoWorkspaceProfile profile, bool isOpen);

TodoWorkspaceProfile todoWorkspaceProfileForWidth(double width) {
  if (width >= TodoLayoutTokens.wideMinWidth) {
    return TodoWorkspaceProfile.wide;
  }
  if (width >= TodoLayoutTokens.compactMinWidth) {
    return TodoWorkspaceProfile.compact;
  }
  if (width >= TodoLayoutTokens.tabletMinWidth) {
    return TodoWorkspaceProfile.tablet;
  }
  return TodoWorkspaceProfile.mobile;
}

/// Responsive product workspace that owns navigation and region geometry only.
class TodoWorkspace extends StatelessWidget {
  const TodoWorkspace({
    super.key,
    required this.width,
    required this.section,
    required this.smart,
    required this.listId,
    required this.content,
    required this.detail,
    required this.onSelectSection,
    required this.onSelectSmart,
    required this.onSelectList,
    required this.onOpenTags,
    required this.onOpenFilters,
    required this.onOpenSettings,
    this.scaffoldKey,
    this.onDetailDrawerChanged,
  });

  final double width;
  final Section section;
  final SmartList smart;
  final String? listId;
  final Widget content;
  final Widget detail;
  final ValueChanged<Section> onSelectSection;
  final ValueChanged<SmartList> onSelectSmart;
  final ValueChanged<String?> onSelectList;
  final VoidCallback onOpenTags;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenSettings;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final TodoDetailDrawerChanged? onDetailDrawerChanged;

  @override
  Widget build(BuildContext context) {
    return switch (todoWorkspaceProfileForWidth(width)) {
      TodoWorkspaceProfile.wide => _desktopWide(context),
      TodoWorkspaceProfile.compact => _desktopCompact(context),
      TodoWorkspaceProfile.tablet => _tablet(context),
      TodoWorkspaceProfile.mobile => _mobile(context),
    };
  }

  Widget _desktopWide(BuildContext context) {
    final colors = brandColors(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: colors.background,
      body: Row(
        children: [
          TodoRail(section: section, onSelect: onSelectSection),
          _WorkspaceDivider(color: colors.border),
          Sidebar(
            key: const Key('todo-sidebar'),
            width: TodoLayoutTokens.wideSidebarWidth,
            selectedSection: section,
            selectedSmart: smart,
            selectedListId: listId,
            onSelectSection: onSelectSection,
            onSelectSmart: onSelectSmart,
            onSelectList: onSelectList,
            onOpenTags: onOpenTags,
            onOpenFilters: onOpenFilters,
            onOpenSettings: onOpenSettings,
          ),
          _WorkspaceDivider(color: colors.border),
          Expanded(child: _contentRegion(colors)),
          _WorkspaceDivider(color: colors.border),
          SizedBox(
            key: const Key('todo-detail'),
            width: TodoLayoutTokens.wideDetailWidth,
            child: detail,
          ),
        ],
      ),
    );
  }

  Widget _desktopCompact(BuildContext context) {
    final colors = brandColors(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: colors.background,
      endDrawer: _detailDrawer(),
      onEndDrawerChanged: (isOpen) =>
          onDetailDrawerChanged?.call(TodoWorkspaceProfile.compact, isOpen),
      body: Row(
        children: [
          TodoRail(section: section, onSelect: onSelectSection),
          _WorkspaceDivider(color: colors.border),
          Sidebar(
            key: const Key('todo-sidebar'),
            width: TodoLayoutTokens.compactSidebarWidth,
            selectedSection: section,
            selectedSmart: smart,
            selectedListId: listId,
            onSelectSection: onSelectSection,
            onSelectSmart: onSelectSmart,
            onSelectList: onSelectList,
            onOpenTags: onOpenTags,
            onOpenFilters: onOpenFilters,
            onOpenSettings: onOpenSettings,
          ),
          _WorkspaceDivider(color: colors.border),
          Expanded(child: _contentRegion(colors)),
        ],
      ),
    );
  }

  Widget _tablet(BuildContext context) {
    final colors = brandColors(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: colors.background,
      drawer: _sidebarDrawer(),
      endDrawer: _detailDrawer(),
      onEndDrawerChanged: (isOpen) =>
          onDetailDrawerChanged?.call(TodoWorkspaceProfile.tablet, isOpen),
      appBar: _shellAppBar(context),
      body: Row(
        children: [
          TodoRail(section: section, onSelect: onSelectSection),
          _WorkspaceDivider(color: colors.border),
          Expanded(child: _contentRegion(colors)),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    final colors = brandColors(context);
    final navIndex = Section.values.indexOf(section).clamp(0, 3).toInt();
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: colors.background,
      drawer: _sidebarDrawer(),
      appBar: _shellAppBar(context),
      body: ColoredBox(
        key: const Key('todo-content'),
        color: colors.surface,
        child: content,
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('todo-mobile-nav'),
        selectedIndex: navIndex,
        onDestinationSelected: (index) =>
            onSelectSection(Section.values[index]),
        destinations: [
          for (final entry in Section.values.take(4))
            NavigationDestination(icon: Icon(entry.icon), label: entry.label),
        ],
      ),
    );
  }

  Widget _contentRegion(AppColors colors) {
    return ColoredBox(
      key: const Key('todo-content'),
      color: colors.surface,
      child: content,
    );
  }

  Drawer _sidebarDrawer() {
    return Drawer(
      key: const Key('todo-sidebar-drawer'),
      width: TodoLayoutTokens.compactSidebarWidth,
      child: Builder(
        builder: (drawerContext) => Sidebar(
          width: TodoLayoutTokens.compactSidebarWidth,
          selectedSection: section,
          selectedSmart: smart,
          selectedListId: listId,
          onSelectSection: onSelectSection,
          onSelectSmart: onSelectSmart,
          onSelectList: onSelectList,
          onOpenTags: onOpenTags,
          onOpenFilters: onOpenFilters,
          onOpenSettings: onOpenSettings,
          onNavigationCommitted: () => Scaffold.of(drawerContext).closeDrawer(),
        ),
      ),
    );
  }

  Drawer _detailDrawer() {
    return Drawer(
      key: const Key('todo-detail-drawer'),
      width: TodoLayoutTokens.detailDrawerMaxWidth,
      child: detail,
    );
  }

  PreferredSizeWidget _shellAppBar(BuildContext context) {
    final colors = brandColors(context);
    return AppBar(
      toolbarHeight: TodoLayoutTokens.workspaceHeaderHeight,
      title: Text(section.label),
      centerTitle: false,
      leading: Builder(
        builder: (drawerContext) => IconButton(
          tooltip: '菜单',
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(drawerContext).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          tooltip: '搜索',
          icon: Icon(Icons.search, color: colors.mutedForeground),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TaskSearchPage())),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Slim product-level navigation rail shared by desktop and tablet profiles.
class TodoRail extends StatelessWidget {
  const TodoRail({super.key, required this.section, required this.onSelect});

  final Section section;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      key: const Key('todo-rail'),
      width: TodoLayoutTokens.railWidth,
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: TodoLayoutTokens.workspaceHeaderHeight,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 19,
                      color: colors.accentForeground,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 8),
              for (final item in Section.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _RailButton(
                    tooltip: item.label,
                    icon: item.icon,
                    selected: item == section,
                    onTap: () => onSelect(item),
                  ),
                ),
              const Spacer(),
              _RailButton(
                tooltip: '同步',
                icon: Icons.sync,
                selected: false,
                onTap: () {},
              ),
              const SizedBox(height: 4),
              _RailButton(
                tooltip: '通知',
                icon: Icons.notifications_none,
                selected: false,
                onTap: () {},
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final brightness = Theme.of(context).brightness;
    return Tooltip(
      message: widget.tooltip,
      child: InkResponse(
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _focused = focused),
        radius: 20,
        child: AnimatedContainer(
          duration: TodoLayoutTokens.stateTransitionDurationFor(context),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.selected
                ? TodoLayoutTokens.selectedRowFor(brightness)
                : Colors.transparent,
            border: _focused
                ? Border.all(color: colors.accent, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(
              TodoLayoutTokens.selectedRowRadius,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.selected ? colors.accent : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _WorkspaceDivider extends StatelessWidget {
  const _WorkspaceDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(width: 1, thickness: 1, color: color);
  }
}
