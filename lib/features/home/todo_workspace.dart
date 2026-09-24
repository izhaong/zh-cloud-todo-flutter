import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../../state/repositories/task_query_repository.dart';
import '../../core/shortcuts/todo_shortcut_registry.dart';
import '../shell/section.dart';
import '../shell/sidebar.dart';
import '../task/task_search_page.dart';
import 'keyboard_shortcuts_dialog.dart';

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
    required this.onSync,
    required this.onOpenReminders,
    required this.onSelectSmart,
    required this.onSelectList,
    required this.onOpenTags,
    required this.onOpenFilters,
    required this.onOpenSettings,
    required this.onOpenPomodoro,
    required this.onOpenHabit,
    required this.onOpenCountdown,
    this.onSelectTag,
    this.onOpenNotes,
    this.onSearchResultSelected,
    this.scaffoldKey,
    this.onDetailDrawerChanged,
    this.syncStatus = '同步尚未执行',
  });

  final double width;
  final Section section;
  final SmartList smart;
  final String? listId;
  final Widget content;
  final Widget detail;
  final ValueChanged<Section> onSelectSection;
  final VoidCallback onSync;
  final VoidCallback onOpenReminders;
  final ValueChanged<SmartList> onSelectSmart;
  final ValueChanged<String?> onSelectList;
  final VoidCallback onOpenTags;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPomodoro;
  final VoidCallback onOpenHabit;
  final VoidCallback onOpenCountdown;
  final ValueChanged<String>? onSelectTag;
  final VoidCallback? onOpenNotes;
  final ValueChanged<TaskSearchResult>? onSearchResultSelected;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final TodoDetailDrawerChanged? onDetailDrawerChanged;
  final String syncStatus;

  @override
  Widget build(BuildContext context) {
    final workspace = switch (todoWorkspaceProfileForWidth(width)) {
      TodoWorkspaceProfile.wide => _desktopWide(context),
      TodoWorkspaceProfile.compact => _desktopCompact(context),
      TodoWorkspaceProfile.tablet => _tablet(context),
      TodoWorkspaceProfile.mobile => _mobile(context),
    };
    return Shortcuts.manager(
      manager: TodoShortcutManager(
        todoShortcutActivators(
          forKind: (kind) => switch (kind) {
            TodoShortcutKind.openSearch => _OpenGlobalSearchIntent(),
            TodoShortcutKind.showShortcuts => _ShowKeyboardShortcutsIntent(),
          },
        ),
      ),
      child: Actions(
        actions: {
          _OpenGlobalSearchIntent: CallbackAction<_OpenGlobalSearchIntent>(
            onInvoke: (_) {
              unawaited(_openSearch(context));
              return null;
            },
          ),
          _ShowKeyboardShortcutsIntent:
              CallbackAction<_ShowKeyboardShortcutsIntent>(
                onInvoke: (_) {
                  unawaited(showKeyboardShortcutsDialog(context));
                  return null;
                },
              ),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              workspace,
              IgnorePointer(
                child: TodoSyncStatusAnnouncement(status: syncStatus),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopWide(BuildContext context) {
    final colors = brandColors(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: colors.background,
      body: Row(
        children: [
          TodoRail(
            section: section,
            onSelect: onSelectSection,
            onSync: onSync,
            onOpenReminders: onOpenReminders,
          ),
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
            onSelectTag: onSelectTag,
            onOpenPomodoro: onOpenPomodoro,
            onOpenHabit: onOpenHabit,
            onOpenCountdown: onOpenCountdown,
            onOpenNotes: onOpenNotes,
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
          TodoRail(
            section: section,
            onSelect: onSelectSection,
            onSync: onSync,
            onOpenReminders: onOpenReminders,
          ),
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
            onSelectTag: onSelectTag,
            onOpenPomodoro: onOpenPomodoro,
            onOpenHabit: onOpenHabit,
            onOpenCountdown: onOpenCountdown,
            onOpenNotes: onOpenNotes,
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
          TodoRail(
            section: section,
            onSelect: onSelectSection,
            onSync: onSync,
            onOpenReminders: onOpenReminders,
          ),
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
          onSelectTag: onSelectTag,
          onOpenPomodoro: onOpenPomodoro,
          onOpenHabit: onOpenHabit,
          onOpenCountdown: onOpenCountdown,
          onOpenNotes: onOpenNotes,
          onOpenReminders: onOpenReminders,
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
          onPressed: () => unawaited(_openSearch(context)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    final result = await Navigator.of(context).push<TaskSearchResult>(
      MaterialPageRoute(builder: (_) => const TaskSearchPage()),
    );
    if (result != null) onSearchResultSelected?.call(result);
  }
}

/// Slim product-level navigation rail shared by desktop and tablet profiles.
class TodoRail extends StatelessWidget {
  const TodoRail({
    super.key,
    required this.section,
    required this.onSelect,
    required this.onSync,
    required this.onOpenReminders,
  });

  final Section section;
  final ValueChanged<Section> onSelect;
  final VoidCallback onSync;
  final VoidCallback onOpenReminders;

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
                onTap: onSync,
                identifier: 'todo_sync_action',
              ),
              const SizedBox(height: 4),
              _RailButton(
                key: const Key('todo-reminder-inbox-action'),
                tooltip: '通知',
                icon: Icons.notifications_none,
                selected: false,
                onTap: onOpenReminders,
                identifier: 'todo_reminder_inbox_action',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowKeyboardShortcutsIntent extends Intent {}

class _OpenGlobalSearchIntent extends Intent {
  const _OpenGlobalSearchIntent();
}

class _RailButton extends StatefulWidget {
  const _RailButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.identifier,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? identifier;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final brightness = Theme.of(context).brightness;
    return Semantics(
      identifier: widget.identifier,
      button: true,
      label: widget.tooltip,
      child: Tooltip(
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
      ),
    );
  }
}

/// 不改变视觉布局的同步状态播报锚点，供辅助技术和固定设备验收读取。
class TodoSyncStatusAnnouncement extends StatelessWidget {
  const TodoSyncStatusAnnouncement({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'todo_sync_status',
    label: status,
    liveRegion: true,
    container: true,
    child: const SizedBox.shrink(),
  );
}

class _WorkspaceDivider extends StatelessWidget {
  const _WorkspaceDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(width: 1, thickness: 1, color: color);
  }
}
