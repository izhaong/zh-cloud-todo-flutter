import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../../state/providers.dart';
import '../../state/repositories/sidebar_visibility_repository.dart';
import '../folder/folder_actions.dart';
import '../list/list_actions.dart';
import '../list/list_editor_sheet.dart';
import 'section.dart';
import 'sidebar_hierarchy.dart';
import 'sidebar_task_drop.dart';

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
    this.onSelectTag,
    this.onOpenPomodoro,
    this.onOpenHabit,
    this.onOpenCountdown,
    this.onOpenNotes,
    this.onOpenReminders,
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
  final ValueChanged<String>? onSelectTag;
  final VoidCallback? onOpenPomodoro;
  final VoidCallback? onOpenHabit;
  final VoidCallback? onOpenCountdown;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onOpenReminders;
  final VoidCallback? onNavigationCommitted;

  bool _isTasksSelected(Section s) => s == Section.tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    final stats = ref.watch(taskStatsProvider).valueOrNull ?? TaskStats.empty;
    final lists = ref.watch(listsStreamProvider).valueOrNull ?? const [];
    final folders = ref.watch(foldersStreamProvider).valueOrNull ?? const [];
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? const [];
    final folderEntries = flattenSidebarHierarchy(
      folders,
      idOf: (folder) => folder.id,
      parentIdOf: (folder) => folder.parentId,
    );
    // 嘀嗒《…04-用标签管理任务.md》:10/:23「开启后，标签将显示在清单下面」⇒ 关掉就不显示条目。
    // 「标签」那一行入口不跟着收（spec.md 取舍 1）：本 App 没有嘀嗒的"清单管理页"，
    // 收掉它等于没有回头路。
    //
    // 三态要分开，两两都不能合并（Issue #353）：
    // - 有值就用值 —— 包括"出过一次值之后流才报错"，那是四件套 ③ 的"失败保留已加载数据"。
    //   （写成 `.when(error: …)` 会把这条丢掉：带旧值的 AsyncError 走的也是 error 分支，
    //   存了「隐藏」的账号会在流失败那一刻把标签条目闪回来。用例钉着。）
    // - 加载中且从没读到过值 ⇒ 不画（与同文件 lists/tags 的"没值就画空"一致）。
    //   写成 `valueOrNull ?? 默认` 就是把这一态误当成"读到了、值是显示" ⇒ 冷启动闪一下。
    // - 真读不到（首值就失败）⇒ 才回兜底默认；默认「显示」本身由仓库 `_decode(null)` 兑现。
    final showTagsAsync = ref.watch(sidebarShowTagsProvider);
    final showTags =
        showTagsAsync.valueOrNull ??
        (showTagsAsync.hasError
            ? SidebarVisibilityRepository.defaultShowTags
            : false);
    // 「过滤器」这一档与上面那条**故意不同**（Issue #336）：没读到值就按默认「显示」画，
    // 只有明确读到「隐藏」才收。差别在于这里收的是**导航行本身**：
    // 标签那档收的是标题下面的一串条目，晚一帧再出现只是空列表；
    // 导航行晚一帧出现会把整条侧栏往下顶一格（`test/shell_responsive_test.dart`
    // 用裸 ProviderScope 断言这一行在，实测就是这一格跳变）。
    // 存了「隐藏」的账号会看到该行闪一下再消失 —— 与跳变相比取这一边，写在台账里。
    final showFilters =
        ref.watch(sidebarShowFiltersProvider).valueOrNull ??
        SidebarVisibilityRepository.defaultShowFilters;
    final tagEntries = !showTags
        ? const <SidebarHierarchyEntry<TodoTag>>[]
        : flattenSidebarHierarchy(
            tags,
            idOf: (tag) => tag.id,
            parentIdOf: (tag) => tag.parentId,
          );

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
                      rowKey: const Key('todo-sidebar-row-tomorrow'),
                      icon: SmartList.tomorrow.icon,
                      label: SmartList.tomorrow.label,
                      badge: stats.tomorrow,
                      selected:
                          _isTasksSelected(selectedSection) &&
                          selectedSmart == SmartList.tomorrow,
                      colors: colors,
                      onTap: () {
                        onSelectSection(Section.tasks);
                        onSelectSmart(SmartList.tomorrow);
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
                      onTap: () {
                        onNavigationCommitted?.call();
                        onOpenTags();
                      },
                    ),
                    ...tagEntries.map(
                      (entry) => _TagRow(
                        tag: entry.node,
                        depth: entry.depth,
                        colors: colors,
                        onTap: () {
                          onNavigationCommitted?.call();
                          final selectTag = onSelectTag;
                          if (selectTag != null) {
                            selectTag(entry.node.id);
                          } else {
                            onOpenTags();
                          }
                        },
                      ),
                    ),
                    if (showFilters)
                      _NavRow(
                        rowKey: const Key('todo-sidebar-row-filters'),
                        icon: Icons.filter_alt_outlined,
                        label: '筛选器',
                        selected: false,
                        colors: colors,
                        onTap: () {
                          onNavigationCommitted?.call();
                          onOpenFilters();
                        },
                      ),
                    if (onOpenNotes != null)
                      _NavRow(
                        rowKey: const Key('todo-sidebar-row-notes'),
                        icon: Icons.description_outlined,
                        label: '笔记',
                        selected: false,
                        colors: colors,
                        onTap: () {
                          onNavigationCommitted?.call();
                          onOpenNotes!();
                        },
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
                    ...folderEntries.map(
                      (entry) => _FolderGroup(
                        folder: entry.node,
                        depth: entry.depth,
                        lists: lists
                            .where((l) => l.folderLocalId == entry.node.id)
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
                        .where((list) => list.folderLocalId == null)
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
                    if (onOpenReminders != null)
                      _NavRow(
                        rowKey: const Key('todo-reminder-inbox-action'),
                        icon: Icons.notifications_none,
                        label: '提醒收件箱',
                        selected: false,
                        colors: colors,
                        onTap: () {
                          onNavigationCommitted?.call();
                          onOpenReminders!();
                        },
                      ),
                    _NavRow(
                      rowKey: const Key('todo-sidebar-row-settings'),
                      icon: Icons.settings_outlined,
                      label: '设置',
                      selected: selectedSection == Section.mine,
                      colors: colors,
                      onTap: () {
                        onNavigationCommitted?.call();
                        onOpenSettings();
                      },
                    ),
                    const SizedBox(height: TodoLayoutTokens.sidebarFooterGap),
                  ],
                ),
              ),
              _EfficiencyDock(
                colors: colors,
                onOpenPomodoro: () {
                  onNavigationCommitted?.call();
                  onOpenPomodoro?.call();
                },
                onOpenHabit: () {
                  onNavigationCommitted?.call();
                  onOpenHabit?.call();
                },
                onOpenCountdown: () {
                  onNavigationCommitted?.call();
                  onOpenCountdown?.call();
                },
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
    required this.depth,
    required this.lists,
    required this.selectedListId,
    required this.colors,
    required this.onSelect,
  });

  final TodoFolder folder;
  final int depth;
  final List<TodoList> lists;
  final String? selectedListId;
  final AppColors colors;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // 嘀嗒 :30「在移动端可通过左滑、长按的方式，解散文件夹」。
    // deferToChild：其下清单行自己有长按动作（specs/026），命中区归子节点 ⇒
    // 只有落在文件夹行自身（图标/标题/箭头/留白）上才走解散。
    return GestureDetector(
      onLongPress: () => confirmAndDisbandFolder(context, folder),
      behavior: HitTestBehavior.deferToChild,
      child: Theme(
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
          tilePadding:
              const EdgeInsets.symmetric(
                horizontal: TodoLayoutTokens.sidebarRowContentInset,
              ).copyWith(
                left:
                    TodoLayoutTokens.sidebarRowContentInset +
                    depth * TodoLayoutTokens.sidebarIconGap,
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
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow({
    required this.tag,
    required this.depth,
    required this.colors,
    required this.onTap,
  });

  final TodoTag tag;
  final int depth;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(sidebarTaskDropControllerProvider);
    return SidebarDropZone(
      key: ValueKey('todo-sidebar-drop-tag-${tag.id}'),
      hoverLabel: '打上标签「${tag.name}」',
      accept: (_) => true,
      onDrop: (task) async {
        final outcome = await controller.addTagToTask(task, tag.id);
        if (outcome != SidebarDropOutcome.failed || !context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('打上「${tag.name}」失败')));
      },
      child: _SidebarRow(
        rowKey: ValueKey('todo-sidebar-tag-${tag.id}'),
        icon: Icons.label_outline,
        label: tag.name,
        selected: false,
        colors: colors,
        contentIndent: depth * TodoLayoutTokens.sidebarIconGap,
        onTap: onTap,
      ),
    );
  }
}

class _ListRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(sidebarTaskDropControllerProvider);
    return SidebarDropZone(
      key: ValueKey('todo-sidebar-drop-list-${list.id}'),
      hoverLabel: '移入清单「${list.name}」',
      accept: (task) => controller.acceptsList(task, list.id),
      onDrop: (task) async {
        final outcome = await controller.moveToList(task, list.id);
        if (outcome != SidebarDropOutcome.failed || !context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('移到「${list.name}」失败')));
      },
      child: _SidebarRow(
        rowKey: ValueKey('todo-sidebar-list-${list.id}'),
        icon: Icons.list_alt_outlined,
        label: list.name,
        selected: selected,
        colors: colors,
        onTap: onTap,
        onLongPress: () => showListActions(context, ref, list),
      ),
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
    this.contentIndent = 0,
    this.onLongPress,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;
  final Widget? trailing;
  final double contentIndent;
  final VoidCallback? onLongPress;

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
              onLongPress: widget.onLongPress,
              child: Padding(
                padding: EdgeInsets.only(
                  left:
                      TodoLayoutTokens.sidebarRowContentInset +
                      widget.contentIndent,
                  right: TodoLayoutTokens.sidebarRowContentInset,
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

class _EfficiencyDock extends StatelessWidget {
  const _EfficiencyDock({
    required this.colors,
    required this.onOpenPomodoro,
    required this.onOpenHabit,
    required this.onOpenCountdown,
  });

  final AppColors colors;
  final VoidCallback onOpenPomodoro;
  final VoidCallback onOpenHabit;
  final VoidCallback onOpenCountdown;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: _EfficiencyButton(
                label: '番茄',
                tooltip: '番茄专注',
                icon: Icons.timer_outlined,
                colors: colors,
                onTap: onOpenPomodoro,
              ),
            ),
            Expanded(
              child: _EfficiencyButton(
                label: '习惯',
                tooltip: '习惯打卡',
                icon: Icons.autorenew,
                colors: colors,
                onTap: onOpenHabit,
              ),
            ),
            Expanded(
              child: _EfficiencyButton(
                label: '倒数日',
                tooltip: '倒数纪念日',
                icon: Icons.event_available_outlined,
                colors: colors,
                onTap: onOpenCountdown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EfficiencyButton extends StatefulWidget {
  const _EfficiencyButton({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  State<_EfficiencyButton> createState() => _EfficiencyButtonState();
}

class _EfficiencyButtonState extends State<_EfficiencyButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            TodoLayoutTokens.selectedRowRadius,
          ),
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              border: _focused
                  ? Border.all(color: widget.colors.accent, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(
                TodoLayoutTokens.selectedRowRadius,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.colors.mutedForeground,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.colors.mutedForeground,
                  ),
                ),
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

/// 新建清单底部弹窗。
class _CreateListSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ListEditorSheet(),
    );
  }
}
