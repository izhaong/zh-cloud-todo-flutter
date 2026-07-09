import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../state/providers.dart';
import 'section.dart';

/// TickTick 风格侧栏。
///
/// 结构：
/// - 顶部用户区
/// - 智能清单
/// - 浏览
/// - 清单树
/// - 设置
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
    this.width = 286,
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

  bool _isTasksSelected(Section s) => s == Section.tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    final stats = ref.watch(taskStatsProvider).valueOrNull ?? TaskStats.empty;
    final lists = ref.watch(listsStreamProvider).valueOrNull ?? const [];
    final folders = ref.watch(foldersStreamProvider).valueOrNull ?? const [];

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _SidebarHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  const SizedBox(height: 4),
                  _GroupTitle('智能清单', colors: colors),
                  _SmartRow(
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
                    },
                  ),
                  _SmartRow(
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
                    },
                  ),
                  _SmartRow(
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
                    },
                  ),
                  _SmartRow(
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
                    },
                  ),
                  _SmartRow(
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
                    },
                  ),
                  _SmartRow(
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
                    },
                  ),
                  const SizedBox(height: 8),
                  _GroupTitle('浏览', colors: colors),
                  _NavRow(
                    icon: Section.calendar.icon,
                    label: Section.calendar.label,
                    selected: selectedSection == Section.calendar,
                    colors: colors,
                    onTap: () => onSelectSection(Section.calendar),
                  ),
                  _NavRow(
                    icon: Icons.sell_outlined,
                    label: '标签',
                    selected: false,
                    colors: colors,
                    onTap: onOpenTags,
                  ),
                  _NavRow(
                    icon: Icons.filter_alt_outlined,
                    label: '筛选器',
                    selected: false,
                    colors: colors,
                    onTap: onOpenFilters,
                  ),
                  const SizedBox(height: 10),
                  _GroupTitle('清单', colors: colors),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextButton.icon(
                      onPressed: () => _CreateListSheet.show(context),
                      icon: Icon(Icons.add, size: 18, color: colors.accent),
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
                          horizontal: 8,
                          vertical: 8,
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
                          },
                        ),
                      ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: 8),
                  _NavRow(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    selected: selectedSection == Section.mine,
                    colors: colors,
                    onTap: onOpenSettings,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: colors.accent.withValues(alpha: 0.16),
            child: Icon(Icons.person, size: 18, color: colors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '保持专注',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'TickTick 风格工作台',
                  style: TextStyle(color: colors.mutedForeground, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.mutedForeground,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SmartRow extends StatelessWidget {
  const _SmartRow({
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SidebarRow(
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SidebarRow(
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
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
        leading: Icon(
          Icons.folder_open_outlined,
          size: 18,
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
              dense: true,
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
    this.dense = false,
  });

  final TodoList list;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _SidebarRow(
      icon: Icons.list_alt_outlined,
      label: list.name,
      selected: selected,
      colors: colors,
      onTap: onTap,
      dense: dense,
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.trailing,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? colors.accent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: selected
                  ? Border(left: BorderSide(color: colors.accent, width: 3))
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: dense ? 6 : 8,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.accent : colors.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? colors.accent : colors.foreground,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
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
