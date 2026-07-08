import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/providers.dart';
import 'section.dart';

/// 品牌化左侧导航 Sidebar（TickTick 风格）。
///
/// - 顶部自定义背景区（品牌蓝渐变 + 问候 / 头像）
/// - 智能清单：收件箱 / 今天 / 即将到期 / 全部（带徽章计数）
/// - 一级入口：日历 / 收集箱 / 标签 / 筛选器
/// - 可展开清单树（按 folder 分组 + 徽章）+ 新建
/// - 选中态高亮（accent 左侧指示条 + 浅色背景）
///
/// 纯展示 + 回调：状态由上层 [HomeShell] 持有，便于桌面 Sidebar 与
/// 移动抽屉复用同一组件。
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
  });

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
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    final stats = ref.watch(taskStatsProvider).valueOrNull ?? TaskStats.empty;
    final lists = ref.watch(listsStreamProvider).valueOrNull ?? const [];
    final folders = ref.watch(foldersStreamProvider).valueOrNull ?? const [];

    return Container(
      width: 248,
      color: colors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(colors: colors),
          const SizedBox(height: 4),
          // ── 智能清单 ──
          _SidebarGroupTitle('智能清单', colors: colors),
          _SmartRow(
            smart: SmartList.inbox,
            icon: SmartList.inbox.icon,
            label: SmartList.inbox.label,
            badge: stats.inbox,
            selected: _isTasksSelected(selectedSection) &&
                selectedSmart == SmartList.inbox,
            colors: colors,
            onTap: () {
              onSelectSection(Section.tasks);
              onSelectSmart(SmartList.inbox);
              onSelectList('inbox');
            },
          ),
          _SmartRow(
            smart: SmartList.today,
            icon: SmartList.today.icon,
            label: SmartList.today.label,
            badge: stats.today,
            selected: _isTasksSelected(selectedSection) &&
                selectedSmart == SmartList.today,
            colors: colors,
            onTap: () {
              onSelectSection(Section.tasks);
              onSelectSmart(SmartList.today);
            },
          ),
          _SmartRow(
            smart: SmartList.upcoming,
            icon: SmartList.upcoming.icon,
            label: SmartList.upcoming.label,
            badge: stats.upcoming,
            selected: _isTasksSelected(selectedSection) &&
                selectedSmart == SmartList.upcoming,
            colors: colors,
            onTap: () {
              onSelectSection(Section.tasks);
              onSelectSmart(SmartList.upcoming);
            },
          ),
          _SmartRow(
            smart: SmartList.all,
            icon: SmartList.all.icon,
            label: SmartList.all.label,
            badge: stats.all,
            selected: _isTasksSelected(selectedSection) &&
                selectedSmart == SmartList.all,
            colors: colors,
            onTap: () {
              onSelectSection(Section.tasks);
              onSelectSmart(SmartList.all);
              onSelectList(null);
            },
          ),
          const SizedBox(height: 8),
          // ── 一级入口 ──
          _SidebarGroupTitle('浏览', colors: colors),
          _NavRow(
            icon: Section.calendar.icon,
            label: Section.calendar.label,
            selected: selectedSection == Section.calendar,
            colors: colors,
            onTap: () => onSelectSection(Section.calendar),
          ),
          _NavRow(
            icon: Icons.label_outline,
            label: '标签',
            selected: false,
            colors: colors,
            onTap: onOpenTags,
          ),
          _NavRow(
            icon: Icons.filter_list,
            label: '筛选器',
            selected: false,
            colors: colors,
            onTap: onOpenFilters,
          ),
          const SizedBox(height: 8),
          // ── 清单树 ──
          _SidebarGroupTitle('清单', colors: colors),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton.icon(
              onPressed: () => _CreateListSheet.show(context),
              icon: Icon(Icons.add, size: 18, color: colors.accent),
              label: Text(
                '新建清单',
                style: TextStyle(color: colors.accent),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          ...folders.map((f) => _FolderGroup(
                folder: f,
                lists: lists.where((l) => l.folderId == f.serverId).toList(),
                selectedListId: selectedListId,
                colors: colors,
                onSelect: (id) {
                  onSelectSection(Section.tasks);
                  onSelectList(id);
                },
              )),
          ...lists
              .where((l) => l.folderId == null)
              .map((l) => _ListRow(
                    list: l,
                    selected: _isTasksSelected(selectedSection) &&
                        selectedListId == l.id,
                    colors: colors,
                    onTap: () {
                      onSelectSection(Section.tasks);
                      onSelectList(l.id);
                    },
                  )),
          const SizedBox(height: 12),
          const Divider(height: 1),
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
    );
  }
}

/// 顶部品牌背景区：品牌蓝渐变 + 问候语 + 头像。
class _Header extends StatelessWidget {
  const _Header({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accent.withValues(alpha: 0.75)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.accentForeground.withValues(alpha: 0.85),
              child: Icon(Icons.person, size: 20, color: colors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '保持专注',
                style: TextStyle(
                  color: colors.accentForeground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarGroupTitle extends StatelessWidget {
  const _SidebarGroupTitle(this.title, {required this.colors});
  final String title;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.mutedForeground,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 智能清单行（带徽章计数）。
class _SmartRow extends StatelessWidget {
  const _SmartRow({
    required this.smart,
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final SmartList smart;
  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: icon,
      label: label,
      selected: selected,
      colors: colors,
      onTap: onTap,
      trailing: badge > 0
          ? _Badge('$badge', accent: colors.accentForeground, bg: colors.muted)
          : null,
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
    return _Row(
      icon: icon,
      label: label,
      selected: selected,
      colors: colors,
      onTap: onTap,
    );
  }
}

class _FolderGroup extends ConsumerWidget {
  const _FolderGroup({
    required this.folder,
    required this.lists,
    required this.selectedListId,
    required this.colors,
    required this.onSelect,
  });

  final dynamic folder;
  final List<dynamic> lists;
  final String? selectedListId;
  final AppColors colors;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      dense: true,
      leading: Icon(Icons.folder_open, size: 18, color: colors.mutedForeground),
      title: Text(
        folder.name,
        style: TextStyle(fontSize: 13, color: colors.foreground),
      ),
      iconColor: colors.mutedForeground,
      collapsedIconColor: colors.mutedForeground,
      children: lists
          .map((l) => _ListRow(
                list: l,
                selected: selectedListId == l.id,
                colors: colors,
                onTap: () => onSelect(l.id),
                dense: true,
              ))
          .toList(),
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

  final dynamic list;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: Icons.list_alt,
      label: list.name,
      selected: selected,
      colors: colors,
      onTap: onTap,
      dense: dense,
    );
  }
}

/// 通用行（带选中态左侧 accent 指示条 + 背景高亮）。
class _Row extends StatelessWidget {
  const _Row({
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? colors.accent.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 6 : 9,
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: dense ? 14 : 16,
                decoration: BoxDecoration(
                  color: selected ? colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
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
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.accent, required this.bg});
  final String text;
  final Color accent;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: accent == Colors.white ? const Color(0xFF2C2C2C) : accent,
          fontWeight: FontWeight.w500,
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
            Expanded(
              child: Text('新建清单', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
