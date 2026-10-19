import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../../state/providers.dart';
import '../../state/repositories/sidebar_visibility_repository.dart';
import '../folder/folder_actions.dart';
import '../home/keyboard_shortcuts_dialog.dart';
import '../list/list_actions.dart';
import '../list/list_color.dart';
import '../list/list_editor_sheet.dart';
import '../tag/tag_actions.dart';
import 'section.dart';
import 'sidebar_hierarchy.dart';
import 'sidebar_list_folder_merge.dart';
import '../task/task_view_mutation_feedback.dart';
import 'sidebar_task_drop.dart';
import 'smart_list_manager_sheet.dart';
import 'smart_list_time_condition.dart';

/// 落点没落成时给一句**人话**（FL #603）。
///
/// `applied` / `skipped` 不提示：`skipped` 是「本来就满足、无需写」的正常结果
/// （落回原清单、截止日已在该档窗口内），给它弹一句"失败"是谎报。
/// `readOnly` 与 `failed` 分开说：只读是**可解释的拒绝**，说成"失败"会让用户以为重试就好。
void _showDropFailure(
  BuildContext context,
  SidebarDropOutcome outcome,
  String fallback,
) {
  if (outcome != SidebarDropOutcome.failed &&
      outcome != SidebarDropOutcome.readOnly) {
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          outcome == SidebarDropOutcome.readOnly
              ? taskViewReadOnlyMessage
              : fallback,
        ),
      ),
    );
}

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

  /// 「有内容时显示」的内容判定与徽章用同一份 TaskStats（specs/103 FR-3）。
  /// null = 本端还没有这一行的内容计数（已完成/垃圾桶，FR-5）。
  int? _smartContentCount(SmartList smart, TaskStats stats) => switch (smart) {
    SmartList.inbox => stats.inbox,
    SmartList.assignToMe => stats.assignToMe,
    SmartList.today => stats.today,
    SmartList.tomorrow => stats.tomorrow,
    SmartList.upcoming => stats.upcoming,
    SmartList.all => stats.all,
    SmartList.completed || SmartList.trash => null,
  };

  bool _smartRowVisible(
    SmartList smart,
    Map<String, SmartListVisibility> states,
    TaskStats stats,
  ) {
    switch (states[smart.name] ?? SmartListVisibility.show) {
      case SmartListVisibility.show:
        return true;
      case SmartListVisibility.hide:
        return false;
      case SmartListVisibility.auto:
        // 计数尚未就绪按「显示」处理：统计流没到不该把行藏掉。
        final count = _smartContentCount(smart, stats);
        return count == null || count > 0;
    }
  }

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
    // 智能清单三态（specs/103）：导航行口径与 showFilters 一致 ——
    // 晚一帧不出现比整列跳格可取；缺键 = 默认「显示」由消费侧兜底。
    // 嘀嗒《01-欢迎/03-常见问题》:802「设置-功能模块-启用「番茄专注」」⇒ 关掉这一档，
    // 侧栏底部 dock 里那枚番茄按钮不再出现；习惯/倒数日不受影响（源页没把它们列为模块）。
    final pomodoroEnabled =
        ref
            .watch(featureModuleProvider(TodoFeatureModule.pomodoro))
            .valueOrNull ??
        true;
    final smartStates =
        ref.watch(sidebarSmartListStatesProvider).valueOrNull ??
        const <String, SmartListVisibility>{};
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
                    if (_smartRowVisible(SmartList.inbox, smartStates, stats))
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
                    // 嘀嗒《02-用清单管理任务》:21「指派给我」。
                    if (_smartRowVisible(
                      SmartList.assignToMe,
                      smartStates,
                      stats,
                    ))
                      _SmartRow(
                        rowKey: const Key('todo-sidebar-row-assignToMe'),
                        icon: SmartList.assignToMe.icon,
                        label: SmartList.assignToMe.label,
                        badge: stats.assignToMe,
                        selected:
                            _isTasksSelected(selectedSection) &&
                            selectedSmart == SmartList.assignToMe,
                        colors: colors,
                        onTap: () {
                          onSelectSection(Section.tasks);
                          onSelectSmart(SmartList.assignToMe);
                          onNavigationCommitted?.call();
                        },
                      ),
                    if (_smartRowVisible(SmartList.today, smartStates, stats))
                      _SmartListDropZone(
                        smart: SmartList.today,
                        child: _SmartRow(
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
                      ),
                    if (_smartRowVisible(
                      SmartList.tomorrow,
                      smartStates,
                      stats,
                    ))
                      _SmartListDropZone(
                        smart: SmartList.tomorrow,
                        child: _SmartRow(
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
                      ),
                    if (_smartRowVisible(
                      SmartList.upcoming,
                      smartStates,
                      stats,
                    ))
                      _SmartListDropZone(
                        smart: SmartList.upcoming,
                        child: _SmartRow(
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
                      ),
                    if (_smartRowVisible(SmartList.all, smartStates, stats))
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
                    if (_smartRowVisible(
                      SmartList.completed,
                      smartStates,
                      stats,
                    ))
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
                    if (_smartRowVisible(SmartList.trash, smartStates, stats))
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
                    ReorderableListView(
                      // 嘀嗒《04-用标签管理任务》:118「长按标签即可进行拖拽，
                      // 可以对清单进行自由排序」。shrinkWrap 嵌进侧栏滚动，
                      // 拖拽手柄用默认长按（无可见把手，外观不变）。
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: true,
                      padding: EdgeInsets.zero,
                      // onReorderItem 的 newIndex 已替我们做过「删位后减一」的调整。
                      onReorderItem: (oldIndex, newIndex) =>
                          _onTagsReordered(ref, tagEntries, oldIndex, newIndex),
                      children: [
                        for (final entry in tagEntries)
                          KeyedSubtree(
                            // ReorderableListView 要求条目根带 key。
                            key: ValueKey(
                              'todo-sidebar-tag-order-${entry.node.id}',
                            ),
                            child: _TagRow(
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
                      ],
                    ),
                    if (showFilters)
                      _NavRow(
                        rowKey: const Key('todo-sidebar-row-filters'),
                        icon: Icons.filter_alt_outlined,
                        label: '过滤器',
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
                        // 嘀嗒《02-用清单管理任务.md》:29「添加清单」右边的「设置」
                        // ⇒ 智能清单管理入口钉在新建清单旁边。
                        child: Row(
                          children: [
                            Expanded(
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
                            IconButton(
                              key: const Key('todo-sidebar-smart-list-manager'),
                              tooltip: '智能清单管理',
                              icon: Icon(
                                Icons.settings_outlined,
                                size: TodoLayoutTokens.sidebarIconSize,
                                color: colors.mutedForeground,
                              ),
                              onPressed: () =>
                                  SmartListManagerSheet.show(context),
                            ),
                          ],
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
                pomodoroEnabled: pomodoroEnabled,
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
                onOpenShortcuts: () => _openShortcuts(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 嘀嗒《03-特色功能/08-桌面快捷键.md》常见问题里那句「在侧边栏打开快捷键界面，可以修改」的落点。
  /// 与设置页、指令菜单打开的是**同一个**界面、带同一份生效键位与落库通道
  /// ⇒ 不会出现"从这个入口进去只能看不能改"。
  void _openShortcuts(BuildContext context, WidgetRef ref) {
    final repo = ref.read(sidebarVisibilityRepositoryProvider);
    unawaited(
      showKeyboardShortcutsDialog(
        context,
        overrides:
            ref.read(shortcutOverridesProvider).valueOrNull ??
            const <String, String>{},
        onSave: repo == null
            ? null
            : (kindName, spec) =>
                  repo.saveShortcut(kindName: kindName, combo: spec),
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
              style: AppTextStyles.panelTitle.copyWith(
                color: colors.foreground,
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
            style: AppTextStyles.groupHeader.copyWith(
              color: colors.mutedForeground,
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

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》`:61`「拖动到智能清单上」
/// `:63`「会为任务自动添加该智能清单关联的时间条件，例如“今天”、“本周”等。」
///
/// 只有谓词里带日期窗口的三档（今天 / 明天 / 最近七天）才是落点：其余五档没有
/// 「关联的时间条件」这句话能落成的语义（判据见 `smartListTimeConditionOf`），
/// 把它们做成落点等于替用户决定另一个动作。落点条件按**当次 build 的 now** 现算，
/// 与清单行「落回原清单不算落点」同一口径：已经在窗口里的任务不是有效落点。
class _SmartListDropZone extends ConsumerWidget {
  const _SmartListDropZone({required this.smart, required this.child});

  final SmartList smart;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final condition = smartListTimeConditionOf(smart, DateTime.now());
    if (condition == null) return child;
    final controller = ref.watch(sidebarTaskDropControllerProvider);
    return SidebarDropZone(
      key: ValueKey('todo-sidebar-drop-smart-${smart.name}'),
      hoverLabel: '安排到「${smart.label}」',
      // 悬停这一层**只做指示、不做闸门**（FL #585）：`onWillAccept` 是同步的，
      // 只能看拖出快照；一旦它按快照判「已满足」而返回 false，`onAccept` 根本不会触发，
      // 落点里那次「按库里当前行重判」就没机会跑 —— 拖动被吞在悬停这一步。
      // 判据统一交给落下时的 `applySmartListTimeCondition`（它现读库）。
      // 与标签落点 `accept: (_) => true` 同口径。
      accept: (_) => true,
      onDrop: (task) async {
        final outcome = await controller.applySmartListTimeCondition(
          task,
          condition,
        );
        if (!context.mounted) return;
        _showDropFailure(context, outcome, '安排到「${smart.label}」失败');
      },
      child: child,
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
            style: AppTextStyles.body.copyWith(color: colors.foreground),
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

/// 嘀嗒《04-用标签管理任务》:118 的拖拽重排。只允许**同组**（isPinned 与
/// parentId 都相同）换位：置顶区领头（isPinned DESC）与层级缩进不许被拖散。
/// 重排后把该组的新顺序交给仓储重赋位次；跨组拖拽是 no-op（列表回弹原位）。
void _onTagsReordered(
  WidgetRef ref,
  List<SidebarHierarchyEntry<TodoTag>> entries,
  int oldIndex,
  int newIndex,
) {
  // onReorderItem 的 newIndex 已按「移除后位次」给出，无需再做 -1 调整。
  if (newIndex == oldIndex) return;
  final anchor = entries[oldIndex].node;
  final start = min(oldIndex, newIndex);
  final end = max(oldIndex, newIndex);
  for (var i = start; i <= end; i++) {
    final t = entries[i].node;
    if (t.isPinned != anchor.isPinned || t.parentId != anchor.parentId) {
      return;
    }
  }
  final ids = [for (final e in entries) e.node.id];
  final movedId = ids.removeAt(oldIndex);
  ids.insert(newIndex, movedId);
  final byId = {for (final e in entries) e.node.id: e.node};
  final groupIds = [
    for (final id in ids)
      if (byId[id]!.isPinned == anchor.isPinned &&
          byId[id]!.parentId == anchor.parentId)
        id,
  ];
  unawaited(ref.read(tagRepositoryProvider)?.reorder(groupIds));
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
    // 长按手势让给了拖拽（嘀嗒 :118）；动作表给读屏留这条 custom action 通道
    //（左滑对读屏不可达），specs/082 的可达性承诺不回退。
    // 右键（嘀嗒 :94）包在 Semantics 外层：读屏节点形状不因它改变；触屏不发出
    // 次键，无需 desktopMode 门（看板卡片右键同一写法）。
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          showTagContextMenu(context, ref, tag, details.globalPosition),
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: '置顶'): () {
            showTagActions(context, ref, tag);
          },
        },
        child: SidebarDropZone(
          key: ValueKey('todo-sidebar-drop-tag-${tag.id}'),
          hoverLabel: '打上标签「${tag.name}」',
          accept: (_) => true,
          onDrop: (task) async {
            final outcome = await controller.addTagToTask(task, tag.id);
            if (!context.mounted) return;
            _showDropFailure(context, outcome, '打上「${tag.name}」失败');
          },
          child: Dismissible(
            // 嘀嗒《04-用标签管理任务》:79「在侧边栏左滑某个标签，会出现「置顶」、「编辑」和「删除」3个选项。」
            // 本端左滑唤出「置顶」；编辑/删除在点标签行即到的一层（见 tag_actions.dart 顶部说明）。
            // :118 的长按拖拽在标签分节的 ReorderableListView 上。
            key: ValueKey('todo-sidebar-tag-swipe-${tag.id}'),
            direction: DismissDirection.endToStart,
            resizeDuration: null,
            movementDuration: const Duration(milliseconds: 120),
            confirmDismiss: (direction) async {
              if (!context.mounted) return false;
              await showTagActions(context, ref, tag);
              return false;
            },
            background: Container(color: colors.surface),
            secondaryBackground: Semantics(
              key: const ValueKey('todo-sidebar-tag-swipe-actions'),
              label: '左滑出现置顶',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.push_pin, size: 18),
                  SizedBox(width: 4),
                  Text('置顶', style: AppTextStyles.body),
                  SizedBox(width: 12),
                ],
              ),
            ),
            child: _SidebarRow(
              rowKey: ValueKey('todo-sidebar-tag-${tag.id}'),
              icon: Icons.label_outline,
              label: tag.name,
              selected: false,
              colors: colors,
              contentIndent: depth * TodoLayoutTokens.sidebarIconGap,
              onTap: onTap,
              // 不设 onLongPress：长按已被 ReorderableListView 的拖拽手柄占住
              //（嘀嗒 :118 长按=拖拽）；动作表走左滑与外层 custom action。
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends ConsumerStatefulWidget {
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
  ConsumerState<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends ConsumerState<_ListRow> {
  bool _hovering = false;

  /// 手柄只在悬停或窄视口出现：手机宽度没有悬停可用，只留悬停那一条路就等于把
  /// 嘀嗒方式一（原文挂在移动端 tab 下）删掉；宽屏既不悬停时保持零新增像素，
  /// 9 张黄金基线因此一张都不用重录。
  bool _wantsDragHandle(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _dragHandleNarrowWidth;

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final controller = ref.watch(sidebarTaskDropControllerProvider);
    return SidebarListMergeTarget(
      list: list,
      ref: ref,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: SidebarDropZone(
          key: ValueKey('todo-sidebar-drop-list-${list.id}'),
          hoverLabel: '移入清单「${list.name}」',
          // 同上：悬停不做闸门，判据交给落下时的 `moveToList`（它现读库）。
          accept: (_) => true,
          onDrop: (task) async {
            final outcome = await controller.moveToList(task, list.id);
            if (!context.mounted) return;
            _showDropFailure(context, outcome, '移到「${list.name}」失败');
          },
          child: Dismissible(
            // 嘀嗒《02-用清单管理任务》：「在侧边栏左滑某个清单，会出现「置顶」、「编辑」和「删除」3个选项。」
            // 左滑唤出动作表；长按这一入口保留（既有交互与桌面/读屏都靠它，删掉会倒退）。
            key: ValueKey('todo-sidebar-list-swipe-${list.id}'),
            direction: DismissDirection.endToStart,
            resizeDuration: null,
            movementDuration: const Duration(milliseconds: 120),
            confirmDismiss: (direction) async {
              if (!context.mounted) return false;
              await showListActions(context, ref, list);
              return false;
            },
            background: Container(color: widget.colors.surface),
            secondaryBackground: Semantics(
              label: '左滑出现置顶、编辑、删除',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.push_pin, size: 18),
                  SizedBox(width: 4),
                  Text('置顶', style: AppTextStyles.body),
                  SizedBox(width: 12),
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 4),
                  Text('编辑', style: AppTextStyles.body),
                  SizedBox(width: 12),
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 4),
                  Text('删除', style: AppTextStyles.body),
                  SizedBox(width: 12),
                ],
              ),
            ),
            child: _SidebarRow(
              rowKey: ValueKey('todo-sidebar-list-${list.id}'),
              icon: Icons.list_alt_outlined,
              // 嘀嗒《02-用清单管理任务》:86：设置了 Emoji 图标的清单，
              // 行首图标换成该 Emoji；没设的清单维持原语义不变。
              emoji: list.icon,
              label: list.name,
              selected: widget.selected,
              colors: widget.colors,
              // 嘀嗒《02-用清单管理任务》:73：清单颜色体现在行首图标上；
              // 未设色保持选中 accent / 未选中 muted 的既有语义。
              iconColor: listColorFromHex(list.color),
              onTap: widget.onTap,
              onLongPress: () => showListActions(context, ref, list),
              trailing: SidebarListDragHandle(
                list: list,
                visible: _hovering || _wantsDragHandle(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 窄于这个宽度就按「没有悬停」处理（手机与分屏窗口），手柄常驻。
const _dragHandleNarrowWidth = 700.0;

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.rowKey,
    required this.icon,
    this.emoji,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.iconColor,
    this.trailing,
    this.contentIndent = 0,
    this.onLongPress,
  });

  final Key rowKey;
  final IconData icon;
  final String? emoji;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;
  final Color? iconColor;
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
            // 选中态按滴答参照：**浅灰底、无左色条**（specs/002 参考图里
            // 选中的「收集箱」就是浅灰圆角行）。
            //
            // 历史：本仓库曾一度加过「蓝底 + 3px 左蓝条」以求醒目，但那与参照
            // 图的观感相反，用户对照参考图后判定「不太一样」。这里回到浅灰，
            // 并把品牌色留给真正需要强调的位置（图标/计数/日期）。
            //
            // 不加子组件（走 decoration 绘制）：这一行的子树组件数被
            // test/features/list/list_share_entry_test.dart 的 ④ 判据钉死 47。
            borderRadius: BorderRadius.circular(
              TodoLayoutTokens.selectedRowRadius,
            ),
          ),
          foregroundDecoration: _focused
              ? BoxDecoration(
                  border: Border.all(color: widget.colors.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(
                    TodoLayoutTokens.selectedRowRadius,
                  ),
                )
              : null,
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
                    // 嘀嗒《02-用清单管理任务》:86：设置了 Emoji 图标的清单，
                    // 行首图标换成该 Emoji；没设的清单维持原语义不变。
                    // 选中态左侧品牌色条走 AnimatedContainer 的 border 绘制
                    // （见上），不在这里加子组件 —— 这一行的子树组件数被
                    // test/features/list/list_share_entry_test.dart 的 ④ 判据钉死。
                    if (widget.emoji != null)
                      // 参照图里清单图标是**彩色 emoji 且比单色图标略大**
                      // （🚀💼🏡💖 一眼可辨）。这里给 emoji 单独的槽位与字号，
                      // 不沿用 sidebarIconSize（那是单色图标的 18px 光学尺寸）。
                      //
                      // fontFamilyFallback 显式带上系统 emoji 字体：golden 场景把
                      // 主题字体设成精简的 TodoGoldenSans（不含 emoji 字形），
                      // 不指定 fallback 就会拍成空白/方块，图看着「绿」其实没字形。
                      SizedBox(
                        width: TodoLayoutTokens.sidebarIconSize,
                        child: Text(
                          widget.emoji!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 17,
                            height: 1,
                            fontFamilyFallback: const [
                              'Apple Color Emoji',
                              'Noto Color Emoji',
                              'Segoe UI Emoji',
                            ],
                          ),
                        ),
                      )
                    else
                      Icon(
                        widget.icon,
                        size: TodoLayoutTokens.sidebarIconSize,
                        color:
                            widget.iconColor ??
                            (widget.selected
                                ? widget.colors.accent
                                : widget.colors.mutedForeground),
                      ),
                    const SizedBox(width: TodoLayoutTokens.sidebarIconGap),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (widget.selected
                                    ? AppTextStyles.bodySelected
                                    : AppTextStyles.body)
                                .copyWith(color: widget.colors.foreground),
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
    this.pomodoroEnabled = true,
    required this.onOpenPomodoro,
    required this.onOpenHabit,
    required this.onOpenCountdown,
    required this.onOpenShortcuts,
  });

  final AppColors colors;

  /// false ⇒ 不渲染「番茄」那枚按钮（功能模块开关关闭）。默认 true 即今天的行为。
  final bool pomodoroEnabled;
  final VoidCallback onOpenPomodoro;
  final VoidCallback onOpenHabit;
  final VoidCallback onOpenCountdown;

  /// 侧栏底部的「快捷键」入口（嘀嗒《08-桌面快捷键.md》常见问题「在侧边栏打开快捷键界面」）。
  final VoidCallback onOpenShortcuts;

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
            if (pomodoroEnabled)
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
                icon: Icons.repeat_rounded,
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
            Expanded(
              child: _EfficiencyButton(
                label: '快捷键',
                tooltip: '键盘快捷键',
                icon: Icons.keyboard_outlined,
                colors: colors,
                onTap: onOpenShortcuts,
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
                SizedBox(
                  height: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: AppTextStyles.badge.copyWith(
                        fontSize: 10,
                        color: widget.colors.mutedForeground,
                      ),
                    ),
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
        style: AppTextStyles.badge.copyWith(color: colors.mutedForeground),
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
