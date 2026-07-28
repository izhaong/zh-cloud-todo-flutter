import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../../state/providers.dart';
import 'section.dart';

/// Compact Todo navigation for smart lists, browsing, user lists, and settings.
class Sidebar extends ConsumerWidget {
  const Sidebar({
    super.key,
    required this.selectedSection,
    required this.selectedSmart,
    required this.selectedListId,
    required this.onSelectSection,
    required this.onSelectSmart,
    required this.onSelectList,
    required this.onOpenTags,
    required this.onOpenFilters,
    required this.onOpenSettings,
    this.width = TodoLayoutTokens.wideSidebarWidth,
    this.onNavigationCommitted,
  });

  final double width;
  final Section selectedSection;
  final SmartList selectedSmart;
  final String? selectedListId;
  final ValueChanged<Section> onSelectSection;
  final ValueChanged<SmartList> onSelectSmart;
  final ValueChanged<String?> onSelectList;
  final VoidCallback onOpenTags;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenSettings;
  final VoidCallback? onNavigationCommitted;

  bool _isTasksSelected(Section s) => s == Section.tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    final stats = ref.watch(taskStatsProvider).valueOrNull ?? TaskStats.empty;
    final lists = ref.watch(listsStreamProvider).valueOrNull ?? const [];
    final folders = ref.watch(foldersStreamProvider).valueOrNull ?? const [];

    return SizedBox(
      width: width,
      child: Material(
        color: colors.surface,
        child: SafeArea(
          child: Column(
            children: [
              const _SidebarHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(
                    bottom: TodoLayoutTokens.sidebarFooterGap,
                  ),
                  children: [
                    const SizedBox(height: TodoLayoutTokens.sidebarSectionGap),
                    _GroupTitle('智能清单', colors: colors),
                    _SmartRow(
                      rowKey: const Key('todo-sidebar-row-inbox'),
                      icon: SmartList.inbox.icon,
                      label: SmartList.inbox.label,
                      badge: stats.inbox,
                      selected:
                          _isTasksSelected(selectedSection) &&
                          selectedSmart == SmartList.inbox,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.tasks);
                        onSelectSmart(SmartList.inbox);
                        onSelectList('inbox');
                        onNavigationCommitted?.call();
                      },
                    ),
                    _SmartRow(
                      rowKey: const Key('todo-sidebar-row-today'),
                      icon: SmartList.today.icon,
                      label: SmartList.today.label,
                      badge: stats.today,
                      selected:
                          _isTasksSelected(selectedSection) &&
                          selectedSmart == SmartList.today,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.tasks);
                        onSelectSmart(SmartList.today);
                        onNavigationCommitted?.call();
                      },
                    ),
                    _SmartRow(
                      rowKey: const Key('todo-sidebar-row-upcoming'),
                      icon: SmartList.upcoming.icon,
                      label: SmartList.upcoming.label,
                      badge: stats.upcoming,
                      selected:
                          _isTasksSelected(selectedSection) &&
                          selectedSmart == SmartList.upcoming,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.tasks);
                        onSelectSmart(SmartList.upcoming);
                        onNavigationCommitted?.call();
                      },
                    ),
                    _SmartRow(
                      rowKey: const Key('todo-sidebar-row-all'),
                      icon: SmartList.all.icon,
                      label: SmartList.all.label,
                      badge: stats.all,
                      selected:
                          _isTasksSelected(selectedSection) &&
                          selectedSmart == SmartList.all,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.tasks);
                        onSelectSmart(SmartList.all);
                        onSelectList(null);
                        onNavigationCommitted?.call();
                      },
                    ),
                    _SmartRow(
                      rowKey: const Key('todo-sidebar-row-completed'),
                      icon: SmartList.completed.icon,
                      label: SmartList.completed.label,
                      badge: 0,
                      selected:
                          _isTasksSelected(selectedSection) &&
                          selectedSmart == SmartList.completed,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.tasks);
                        onSelectSmart(SmartList.completed);
                        onNavigationCommitted?.call();
                      },
                    ),
                    _SmartRow(
                      rowKey: const Key('todo-sidebar-row-trash'),
                      icon: SmartList.trash.icon,
                      label: SmartList.trash.label,
                      badge: 0,
                      selected:
                          _isTasksSelected(selectedSection) &&
                          selectedSmart == SmartList.trash,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.tasks);
                        onSelectSmart(SmartList.trash);
                        onNavigationCommitted?.call();
                      },
                    ),
                    const SizedBox(height: TodoLayoutTokens.sidebarSectionGap),
                    _GroupTitle('浏览', colors: colors),
                    _NavRow(
                      rowKey: const Key('todo-sidebar-row-calendar'),
                      icon: Section.calendar.icon,
                      label: Section.calendar.label,
                      selected: selectedSection == Section.calendar,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.calendar);
                        onNavigationCommitted?.call();
                      },
                    ),
                    _NavRow(
                      rowKey: const Key('todo-sidebar-row-tags'),
                      icon: Icons.sell_outlined,
                      label: '标签',
                      selected: false,
                      colors: colors,
                      onTap: onOpenTags,
                    ),
                    _NavRow(
                      rowKey: const Key('todo-sidebar-row-filters'),
                      icon: Icons.filter_alt_outlined,
                      label: '筛选器',
                      selected: false,
                      colors: colors,
                      onTap: onOpenFilters,
                    ),
                    const SizedBox(height: TodoLayoutTokens.sidebarSectionGap),
                    _GroupTitle('清单', colors: colors),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TodoLayoutTokens.sidebarOuterInset,
                      ),
                      child: SizedBox(
                        height: TodoLayoutTokens.sidebarRowHeight,
                        child: TextButton.icon(
                          onPressed: () => _CreateListSheet.show(context),
                          icon: Icon(
                            Icons.add,
                            size: TodoLayoutTokens.sidebarIconSize,
                            color: colors.accent,
                          ),
                          label: Text(
                            '新建清单',
                            style: TextStyle(
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal:
                                  TodoLayoutTokens.sidebarRowContentInset,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                TodoLayoutTokens.selectedRowRadius,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...folders.map(
                      (folder) => _FolderGroup(
                        folder: folder,
                        lists: lists
                            .where((l) => l.folderId == folder.serverId)
                            .toList(),
                        selectedListId: selectedListId,
                        colors: colors,
                        onSelect: (id) {
                          onSelectSection(Section.tasks);
                          onSelectList(id);
                          onNavigationCommitted?.call();
                        },
                      ),
                    ),
                    ...lists
                        .where((list) => list.folderId == null)
                        .map(
                          (list) => _ListRow(
                            list: list,
                            selected:
                                _isTasksSelected(selectedSection) &&
                                selectedListId == list.id,
                            colors: colors,
                            onTap: () {
                              onSelectSection(Section.tasks);
                              onSelectList(list.id);
                              onNavigationCommitted?.call();
                            },
                          ),
                        ),
                    const SizedBox(height: TodoLayoutTokens.sidebarSectionGap),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: TodoLayoutTokens.sidebarSectionGap),
                    _NavRow(
                      rowKey: const Key('todo-sidebar-row-settings'),
                      icon: Icons.settings_outlined,
                      label: '设置',
                      selected: selectedSection == Section.mine,
                      colors: colors,
                      onTap: onOpenSettings,
                    ),
                    const SizedBox(height: TodoLayoutTokens.sidebarFooterGap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      height: TodoLayoutTokens.workspaceHeaderHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TodoLayoutTokens.sidebarHeaderInset,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '任务清单',
              style: TextStyle(
                color: colors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title, {required this.colors});

  final String title;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TodoLayoutTokens.sidebarGroupTitleHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TodoLayoutTokens.sidebarHeaderInset,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartRow extends StatelessWidget {
  const _SmartRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SidebarRow(
      rowKey: rowKey,
      icon: icon,
      label: label,
      selected: selected,
      colors: colors,
      trailing: badge > 0 ? _Badge(text: '$badge', colors: colors) : null,
      onTap: onTap,
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SidebarRow(
      rowKey: rowKey,
      icon: icon,
      label: label,
      selected: selected,
      colors: colors,
      onTap: onTap,
    );
  }
}

class _FolderGroup extends StatelessWidget {
  const _FolderGroup({
    required this.folder,
    required this.lists,
    required this.selectedListId,
    required this.colors,
    required this.onSelect,
  });

  final TodoFolder folder;
  final List<TodoList> lists;
  final String? selectedListId;
  final AppColors colors;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: ValueKey('todo-sidebar-folder-${folder.id}'),
        dense: true,
        visualDensity: VisualDensity.compact,
        minTileHeight: TodoLayoutTokens.sidebarRowHeight,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: TodoLayoutTokens.sidebarRowContentInset,
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: TodoLayoutTokens.sidebarOuterInset,
        ),
        leading: Icon(
          Icons.folder_open_outlined,
          size: TodoLayoutTokens.sidebarIconSize,
          color: colors.mutedForeground,
        ),
        title: Text(
          folder.name,
          style: TextStyle(fontSize: 13, color: colors.foreground),
        ),
        iconColor: colors.mutedForeground,
        collapsedIconColor: colors.mutedForeground,
        children: [
          for (final list in lists)
            _ListRow(
              list: list,
              selected: selectedListId == list.id,
              colors: colors,
              onTap: () => onSelect(list.id),
            ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.list,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final TodoList list;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SidebarRow(
      rowKey: ValueKey('todo-sidebar-list-${list.id}'),
      icon: Icons.list_alt_outlined,
      label: list.name,
      selected: selected,
      colors: colors,
      onTap: onTap,
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.trailing,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      key: widget.rowKey,
      height: TodoLayoutTokens.sidebarRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TodoLayoutTokens.sidebarOuterInset,
        ),
        child: AnimatedContainer(
          duration: TodoLayoutTokens.stateTransitionDurationFor(context),
          decoration: BoxDecoration(
            border: _focused
                ? Border.all(color: widget.colors.accent, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(
              TodoLayoutTokens.selectedRowRadius,
            ),
          ),
          child: Material(
            color: widget.selected
                ? TodoLayoutTokens.selectedRowFor(brightness)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              TodoLayoutTokens.selectedRowRadius,
            ),
            child: InkWell(
              hoverColor: TodoLayoutTokens.hoverRowFor(brightness),
              focusColor: Colors.transparent,
              onFocusChange: (focused) => setState(() => _focused = focused),
              borderRadius: BorderRadius.circular(
                TodoLayoutTokens.selectedRowRadius,
              ),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TodoLayoutTokens.sidebarRowContentInset,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: TodoLayoutTokens.sidebarIconSize,
                      color: widget.selected
                          ? widget.colors.accent
                          : widget.colors.mutedForeground,
                    ),
                    const SizedBox(width: TodoLayoutTokens.sidebarIconGap),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: widget.colors.foreground,
                        ),
                      ),
                    ),
                    ?widget.trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.colors});

  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: colors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 新建清单底部弹窗（内联极简版，避免引入额外页面依赖）。
class _CreateListSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text('新建清单', style: TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}
