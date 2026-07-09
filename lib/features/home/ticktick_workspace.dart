import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../shell/quick_add_bar.dart';
import '../shell/section.dart';
import '../shell/sidebar.dart';

class TickTickWorkspace extends StatelessWidget {
  const TickTickWorkspace({
    super.key,
    required this.width,
    required this.section,
    required this.smart,
    required this.listId,
    required this.content,
    required this.onSelectSection,
    required this.onSelectSmart,
    required this.onSelectList,
    required this.onOpenTags,
    required this.onOpenFilters,
    required this.onOpenSettings,
    required this.onQuickAdd,
  });

  final double width;
  final Section section;
  final SmartList smart;
  final String? listId;
  final Widget content;
  final ValueChanged<Section> onSelectSection;
  final ValueChanged<SmartList> onSelectSmart;
  final ValueChanged<String?> onSelectList;
  final VoidCallback onOpenTags;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onQuickAdd;

  bool get _showQuickAddBar => width >= 600 && section == Section.tasks;

  @override
  Widget build(BuildContext context) {
    if (width >= 1280) {
      return _desktopWide(context);
    }
    if (width >= 1024) {
      return _desktopCompact(context);
    }
    if (width >= 600) {
      return _tablet(context);
    }
    return _mobile(context);
  }

  Widget _desktopWide(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          TickTickRail(section: section, onSelect: onSelectSection),
          VerticalDivider(width: 1, color: colors.border),
          Sidebar(
            key: const Key('ticktick-sidebar'),
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
          VerticalDivider(width: 1, color: colors.border),
          Expanded(
            child: Column(
              children: [
                if (_showQuickAddBar) QuickAddBar(onSubmit: onQuickAdd),
                Expanded(
                  child: Container(
                    key: const Key('ticktick-content'),
                    color: colors.background,
                    child: content,
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: colors.border),
          SizedBox(
            width: 352,
            child: _DetailPanel(
              key: const Key('ticktick-detail-panel'),
              section: section,
              smart: smart,
              listId: listId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopCompact(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return Scaffold(
      backgroundColor: colors.background,
      endDrawer: Drawer(
        key: const Key('ticktick-detail-drawer'),
        backgroundColor: colors.background,
        child: _DetailPanel(section: section, smart: smart, listId: listId),
      ),
      body: Row(
        children: [
          TickTickRail(section: section, onSelect: onSelectSection),
          VerticalDivider(width: 1, color: colors.border),
          Sidebar(
            key: const Key('ticktick-sidebar'),
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
          VerticalDivider(width: 1, color: colors.border),
          Expanded(
            child: Column(
              children: [
                if (_showQuickAddBar) QuickAddBar(onSubmit: onQuickAdd),
                Expanded(
                  child: Container(
                    key: const Key('ticktick-content'),
                    color: colors.background,
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tablet(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return Scaffold(
      backgroundColor: colors.background,
      drawer: Drawer(
        key: const Key('ticktick-sidebar-drawer'),
        backgroundColor: colors.surface,
        child: Sidebar(
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
      ),
      endDrawer: Drawer(
        key: const Key('ticktick-detail-drawer'),
        backgroundColor: colors.background,
        child: _DetailPanel(section: section, smart: smart, listId: listId),
      ),
      appBar: _shellAppBar(context, showMenu: true),
      body: Row(
        children: [
          TickTickRail(section: section, onSelect: onSelectSection),
          VerticalDivider(width: 1, color: colors.border),
          Expanded(
            child: Column(
              children: [
                if (_showQuickAddBar) QuickAddBar(onSubmit: onQuickAdd),
                Expanded(
                  child: Container(
                    key: const Key('ticktick-content'),
                    color: colors.background,
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    final navIndex = Section.values.indexOf(section).clamp(0, 3).toInt();
    return Scaffold(
      backgroundColor: colors.background,
      drawer: Drawer(
        key: const Key('ticktick-sidebar-drawer'),
        backgroundColor: colors.surface,
        child: Sidebar(
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
      ),
      appBar: _shellAppBar(context, showMenu: true),
      body: Container(
        key: const Key('ticktick-content'),
        color: colors.background,
        child: content,
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('ticktick-mobile-nav'),
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

  PreferredSizeWidget _shellAppBar(
    BuildContext context, {
    required bool showMenu,
  }) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return AppBar(
      title: Text(section.label),
      centerTitle: false,
      leading: showMenu
          ? Builder(
              builder: (ctx) => IconButton(
                tooltip: '菜单',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      actions: [
        IconButton(
          tooltip: '搜索',
          icon: Icon(Icons.search, color: colors.mutedForeground),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: colors.accent.withValues(alpha: 0.14),
            child: Icon(Icons.person, size: 18, color: colors.accent),
          ),
        ),
      ],
    );
  }
}

class TickTickRail extends StatelessWidget {
  const TickTickRail({
    super.key,
    required this.section,
    required this.onSelect,
  });

  final Section section;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    final items = Section.values;
    return Container(
      key: const Key('ticktick-rail'),
      width: 58,
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colors.accent.withValues(alpha: 0.14),
                child: Icon(Icons.person, size: 18, color: colors.accent),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _RailButton(
                  icon: item.icon,
                  selected: item == section,
                  onTap: () => onSelect(item),
                ),
              ),
            const Spacer(),
            _RailButton(icon: Icons.refresh, selected: false, onTap: () {}),
            const SizedBox(height: 4),
            _RailButton(
              icon: Icons.notifications_none,
              selected: false,
              onTap: () {},
            ),
            const SizedBox(height: 4),
            _RailButton(
              icon: Icons.help_outline,
              selected: false,
              onTap: () {},
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return Tooltip(
      message: '切换侧栏分区',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? colors.accent : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    super.key,
    required this.section,
    required this.smart,
    required this.listId,
  });

  final Section section;
  final SmartList smart;
  final String? listId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    final title = switch (section) {
      Section.tasks => smart.label,
      Section.calendar => '日历',
      Section.habit => '习惯',
      Section.mine => '我的',
    };
    final subtitle = switch (section) {
      Section.tasks => listId == null ? '从侧栏选择清单' : '清单：$listId',
      Section.calendar => '月视图 / 周视图 / 日程',
      Section.habit => '打卡与 streak',
      Section.mine => '账户 / 安全 / 设置',
    };
    return Container(
      color: colors.background,
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.destructive, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '设置日期',
                  style: TextStyle(
                    color: colors.mutedForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.flag_outlined,
                  color: colors.mutedForeground,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: colors.foreground,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: colors.mutedForeground, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Divider(color: colors.border),
            const SizedBox(height: 12),
            _DetailAction(
              icon: Icons.calendar_today_outlined,
              label: '日期',
              colors: colors,
            ),
            _DetailAction(
              icon: Icons.flag_outlined,
              label: '优先级',
              colors: colors,
            ),
            _DetailAction(
              icon: Icons.sell_outlined,
              label: '标签',
              colors: colors,
            ),
            _DetailAction(
              icon: Icons.checklist_outlined,
              label: '检查事项',
              colors: colors,
            ),
            const SizedBox(height: 12),
            Divider(color: colors.border),
            const SizedBox(height: 12),
            Text(
              '详情面板',
              style: TextStyle(
                color: colors.mutedForeground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  '选择任务后，这里会固定展示 TickTick 风格的详情编辑区。',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colors.mutedForeground),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: colors.foreground, fontSize: 13)),
        ],
      ),
    );
  }
}
