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
import 'command_palette.dart';
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
    this.searchEnabled = true,
    this.companion,
    this.onSectionContextMenu,
    this.paletteCommands = const <TodoPaletteCommand>[],
    this.shortcutOverrides = const <String, String>{},
    this.onSaveShortcut,
  });

  /// 指令菜单里「前往各模块」那批条目：只有持有导航回调的 `HomeShell` 拼得出来，
  /// 面板本身不碰 provider 与路由（这样它能被单独测）。
  final List<TodoPaletteCommand> paletteCommands;

  /// 用户改过的键位覆盖表（嘀嗒《08-桌面快捷键.md》:26「可以修改」）。
  /// 空表 = 全部用注册表默认 ⇒ `Shortcuts` 映射与快捷键界面都按这张表算，两边不会说两套话。
  final Map<String, String> shortcutOverrides;

  /// 改键的落库通道；null ⇒ 快捷键界面只读（本地数据库尚未就绪）。
  final Future<void> Function(String kindName, String? spec)? onSaveShortcut;
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

  /// 嘀嗒《01-任务/09-如何管理海量任务/07-搜索任务》:12「在「设置」→「功能模块」中启用「搜索」」
  /// ⇒ false 时搜索入口与快捷键都不再通向搜索页。默认 true 即今天的行为。
  final bool searchEnabled;

  /// 与主区并列的第二模块；`null` 表示单模块视图。
  ///
  /// 只有 `_desktopWide` / `_desktopCompact` 会画它 —— 源页 `:5` 限定「桌面端」，
  /// `tablet` 的侧栏是抽屉、`mobile` 是底部导航，放不下两块内容，
  /// 于是拿到非空 companion 时也静默按单模块渲染（偏好仍保留）。
  final Widget? companion;

  /// 右键模块图标的回调，坐标用于弹菜单。`null` ⇒ 该形态不提供并列入口。
  final void Function(Section section, Offset position)? onSectionContextMenu;

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
            TodoShortcutKind.openCommandPalette => _OpenCommandPaletteIntent(),
            TodoShortcutKind.showShortcuts => _ShowKeyboardShortcutsIntent(),
          },
          overrides: shortcutOverrides,
        ),
      ),
      child: Actions(
        actions: {
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              unawaited(
                showCommandPalette(
                  context,
                  commands: <TodoPaletteCommand>[
                    ...paletteCommands,
                    // 嘀嗒把 ⌘K 定给指令菜单，搜索就改作面板里的一条命令（AppBar 那枚按钮不变），
                    // 而不是再占一个键位；功能模块关掉搜索时连这条都不列。
                    if (searchEnabled)
                      TodoPaletteCommand(
                        label: '全局搜索',
                        hint: '按名称或关键词搜索任务',
                        run: () => unawaited(_openSearch(context)),
                      ),
                    TodoPaletteCommand(
                      label: '显示键盘快捷键',
                      hint: '列出现今生效的键位',
                      run: () => unawaited(_showKeyboardShortcuts(context)),
                    ),
                  ],
                ),
              );
              return null;
            },
          ),
          _ShowKeyboardShortcutsIntent:
              CallbackAction<_ShowKeyboardShortcutsIntent>(
                onInvoke: (_) {
                  unawaited(_showKeyboardShortcuts(context));
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
            onSectionContextMenu: onSectionContextMenu,
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
          Expanded(child: _contentWithCompanion(colors)),
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
            onSectionContextMenu: onSectionContextMenu,
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
          Expanded(child: _contentWithCompanion(colors)),
        ],
      ),
    );
  }

  /// 主区 + 可选的并列副栏。
  ///
  /// `companion == null` 时字节上等价于改造前的 `_contentRegion(...)` 单独一格，
  /// 这是"默认态不变"的可判伪承诺：golden 9 张基线不重录必须仍然绿。
  Widget _contentWithCompanion(AppColors colors) {
    final second = companion;
    if (second == null) return _contentRegion(colors);
    return Row(
      children: [
        Expanded(child: _contentRegion(colors)),
        _WorkspaceDivider(color: colors.border),
        Expanded(
          child: ColoredBox(
            color: colors.surface,
            child: KeyedSubtree(
              key: const Key('todo-companion'),
              child: second,
            ),
          ),
        ),
      ],
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
        // 嘀嗒《01-任务/09-如何管理海量任务/07-搜索任务》:12「在「设置」→「功能模块」中启用
        // 「搜索」后，即可通过底部 tab 栏进入搜索页面」⇒ 关掉这一档，搜索入口要一起消失。
        if (searchEnabled)
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

  /// 快捷键界面：`?`、指令菜单里那条命令、设置页那三项入口都走这里，
  /// 所以"生效键位"与"落库通道"只能在这一处传，别在三处各写一遍（会写散）。
  Future<void> _showKeyboardShortcuts(BuildContext context) {
    return showKeyboardShortcutsDialog(
      context,
      overrides: shortcutOverrides,
      onSave: onSaveShortcut,
    );
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
    this.onSectionContextMenu,
  });

  final Section section;
  final ValueChanged<Section> onSelect;
  final VoidCallback onSync;
  final VoidCallback onOpenReminders;

  /// 右键模块图标。为 `null` 时（tablet / mobile）模块图标不响应右键。
  final void Function(Section section, Offset position)? onSectionContextMenu;

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
                    key: Key('todo-rail-item-${item.name}'),
                    tooltip: item.label,
                    icon: item.icon,
                    selected: item == section,
                    onTap: () => onSelect(item),
                    // 源页 #32 的锚点是「任务模块图标」与「日历模块图标」；
                    // 习惯 / 我的不参与并列，所以不给右键。
                    onSecondaryTapDown:
                        (item == Section.tasks || item == Section.calendar) &&
                            onSectionContextMenu != null
                        ? (position) => onSectionContextMenu!(item, position)
                        : null,
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

class _OpenCommandPaletteIntent extends Intent {}

class _RailButton extends StatefulWidget {
  const _RailButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.identifier,
    this.onSecondaryTapDown,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? identifier;
  final ValueChanged<Offset>? onSecondaryTapDown;

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
          onSecondaryTapDown: widget.onSecondaryTapDown == null
              ? null
              : (details) => widget.onSecondaryTapDown!(details.globalPosition),
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
