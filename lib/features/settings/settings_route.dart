import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/update/desktop_update.dart';
import '../../core/update/github_apk_release.dart';
import '../../core/update/update_feed.dart';
import '../../core/update/update_surface.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/time/week_start.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/providers.dart';
import '../../state/repositories/calendar_info_preference_repository.dart';
import '../../state/repositories/task_capture_defaults_repository.dart';
import '../../state/repositories/sidebar_visibility_repository.dart';
import '../../state/session_state.dart';
import '../achievement/achievement_page.dart';
import '../account/account_security_page.dart';
import '../calendar_sub/calendar_subscription_page.dart';
import '../import/task_import_page.dart';
import '../home/keyboard_shortcuts_dialog.dart';
import '../native/native_entry_page.dart';
import '../shell/app_theme_controller.dart';
import 'task_swipe_settings_page.dart';

/// 设置页：分组列表（账号/任务/日期与时间/主题/关于）+ 账户安全与成就入口。
class SettingsRoute extends ConsumerWidget {
  const SettingsRoute({super.key, this.signedInMobile});

  final String? signedInMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    // 读不到偏好时按默认档显示，不让设置页出现空副标题。
    final weekStartLabel = WeekStart.labelOf(
      resolveWeekStartFirstDay(ref.watch(weekStartProvider)),
    );
    // 嘀嗒《08-桌面快捷键.md》:26「在设置里查看快捷键界面，可以修改」：
    // 设置页是这条的落点，所以要把生效键位与落库通道一起递给弹层。
    final shortcutRepo = ref.watch(sidebarVisibilityRepositoryProvider);
    final shortcutOverrides =
        ref.watch(shortcutOverridesProvider).valueOrNull ??
        const <String, String>{};
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(title: '账号'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (signedInMobile != null && signedInMobile!.isNotEmpty)
                  _Tile(
                    icon: Icons.phone_iphone_outlined,
                    title: '当前账号',
                    subtitle: signedInMobile,
                    colors: colors,
                  ),
                _Tile(
                  icon: Icons.verified_user_outlined,
                  title: '账户安全',
                  subtitle: '修改密码、双重验证（2FA）与数据导出',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountSecurityPage(),
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.emoji_events_outlined,
                  title: '成就与勋章',
                  subtitle: '成就值、等级与勋章墙；成就值每天凌晨更新',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AchievementPage()),
                  ),
                ),
                _Tile(
                  icon: Icons.logout,
                  title: '退出登录',
                  colors: colors,
                  destructive: true,
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(title: '任务'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(
                  icon: Icons.playlist_add_check_outlined,
                  title: '新任务默认值',
                  subtitle: '默认清单、优先级与提醒；离线保存后自动同步',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _TaskCaptureDefaultsPage(),
                    ),
                  ),
                ),
                _Tile(
                  key: const Key('todo-settings-swipe-actions'),
                  icon: Icons.swipe_outlined,
                  title: '滑动操作',
                  subtitle: '自定义任务行左右滑动各露出哪些动作',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TaskSwipeSettingsPage(),
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.calendar_month_outlined,
                  title: '日历订阅',
                  subtitle: '订阅外部 ICS，或导出自己的任务日历',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CalendarSubscriptionPage(),
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.upload_file_outlined,
                  title: '任务导入',
                  subtitle: '从 JSON 导入任务、查看批次并按批回滚',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TaskImportPage()),
                  ),
                ),
                _Tile(
                  icon: Icons.widgets_outlined,
                  title: '原生增强',
                  subtitle: '桌面便签、系统分享、锁屏任务与小组件预览',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NativeEntryPage()),
                  ),
                ),
                _Tile(
                  icon: Icons.keyboard_outlined,
                  title: '键盘快捷键',
                  // 副标题不再写「（?）」：键位可以改之后，把某个默认字符印在这里就会说谎。
                  // 也别在这儿塞"为什么暂时改不了"——那行长文案在 320px + 1.3 倍字号下会把这一行
                  // 顶成两行、整页变高，`settings_week_start_test.dart` 那条按 key 打中心的用例
                  // 就会 tap 到别处（第一版就是这么挂的）。只读说明留给弹层自己讲。
                  subtitle: '查看与修改当前生效的组合键',
                  colors: colors,
                  onTap: () => showKeyboardShortcutsDialog(
                    context,
                    overrides: shortcutOverrides,
                    onSave: shortcutRepo == null
                        ? null
                        : (kindName, spec) => shortcutRepo.saveShortcut(
                            kindName: kindName,
                            combo: spec,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(title: '日期与时间'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(
                  key: const Key('todo-settings-week-start'),
                  icon: Icons.view_week_outlined,
                  title: '星期开始于',
                  subtitle: weekStartLabel,
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => _pickWeekStart(context, ref),
                ),
                _TimezonePreferenceTile(),
                _CalendarInfoToggleTile(
                  key: const Key('todo-settings-show-lunar'),
                  title: '显示农历',
                  field: _CalendarInfoField.lunar,
                ),
                _CalendarInfoToggleTile(
                  key: const Key('todo-settings-show-holidays'),
                  title: '显示节假日调休',
                  field: _CalendarInfoField.holidays,
                ),
                _CalendarInfoToggleTile(
                  key: const Key('todo-settings-show-habits'),
                  title: '显示习惯打卡',
                  field: _CalendarInfoField.habits,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(title: '智能清单'),
          // 标签与过滤器同属「智能清单」一组，必须落在同一张卡里：
          // 拆成两张卡时中间会多出卡间距，比同卡内的行距大一截，
          // 与「日期与时间」「功能模块」「主题」的分组观感对不上。
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // 每行连同它自己的失败提示显式 MergeSemantics：
                // 拆成两张卡时这是 Flutter 的默认结果，并成一张卡后
                // 每个 ListTile 会各成一个节点、提示被挤成独立节点，
                // 读屏就不再「取值 + 失败原因」一起念（既有用例锁过这条契约）。
                MergeSemantics(
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.sell_outlined,
                        title: '标签',
                        key: const Key('todo-settings-show-tags'),
                        subtitle: '控制标签条目是否出现在侧栏的清单下面',
                        trailingText: _showTagsLabel(
                          ref.watch(sidebarShowTagsProvider),
                        ),
                        colors: colors,
                        onTap: () => _pickShowTags(context, ref),
                      ),
                      if (_showTagsStale(ref.watch(sidebarShowTagsProvider)))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            '读取偏好失败，显示的是上次读到的值',
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                        ),
                    ],
                  ),
                ),
                MergeSemantics(
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.filter_alt_outlined,
                        title: '过滤器',
                        key: const Key('todo-settings-show-filters'),
                        subtitle: '控制过滤器条目是否出现在侧栏',
                        trailingText: _visibilityLabel(
                          ref.watch(sidebarShowFiltersProvider),
                        ),
                        colors: colors,
                        onTap: () => _pickShowFilters(context, ref),
                      ),
                      if (_visibilityStale(
                        ref.watch(sidebarShowFiltersProvider),
                      ))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            '读取偏好失败，显示的是上次读到的值',
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Section(title: '功能模块'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final module in TodoFeatureModule.values) ...[
                  _Tile(
                    icon: _featureModuleIcon(module),
                    key: Key('todo-settings-module-${module.name}'),
                    title: _featureModuleLabel(module),
                    subtitle: _featureModuleHint(module),
                    trailingText: _featureModuleStateLabel(
                      ref.watch(featureModuleProvider(module)),
                    ),
                    colors: colors,
                    onTap: () => _pickFeatureModule(context, ref, module),
                  ),
                ],
              ],
            ),
          ),
          _Section(title: '主题'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final mode in ThemeMode.values)
                  _Tile(
                    icon: mode == ThemeMode.system
                        ? Icons.brightness_auto
                        : (mode == ThemeMode.dark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined),
                    title: themeModeLabel(mode),
                    colors: colors,
                    trailing: ref.watch(themeModeProvider) == mode
                        ? Icons.check
                        : null,
                    onTap: () => ref.read(themeModeProvider.notifier).set(mode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(title: '关于'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(
                  icon: Icons.info_outline,
                  title: '版本号',
                  subtitle: 'zh-cloud todo（本地离线优先版）',
                  colors: colors,
                ),
                if (kDesktopUpdateCheckEnabled &&
                    _updateSurface() != UpdateSurface.none)
                  _Tile(
                    key: const Key('todo-settings-check-update'),
                    icon: Icons.system_update_alt,
                    title: '检查更新',
                    subtitle: switch (_updateSurface()) {
                      UpdateSurface.releasePage => '在浏览器打开 GitHub Release',
                      UpdateSurface.apk => '下载 GitHub Release 的 APK 并安装',
                      UpdateSurface.sparkle => '通过 GitHub Release 安装',
                      UpdateSurface.none => '',
                    },
                    colors: colors,
                    onTap: () async {
                      try {
                        await checkDesktopUpdateNow();
                      } on UpdateAlreadyCurrent {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('已是最新版本')));
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('暂时无法检查更新，请稍后重试')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 嘀嗒《01-欢迎/03-常见问题.md:134》「点击「设置」-「日期与时间」-「星期开始于」，
  /// 你可以选择“周日”、“周一”、或”周六“任意一天为一周的开始。」三档照抄，
  /// 不自创「跟随系统」或第四档。
  ///
  /// 写入的是"点中的那个字面值"，不是从当前值取反 ⇒ 读到的当前值过期也只会
  /// 让勾选标记画错一帧，不可能把更新的值盖回去（spec.md 四件套 ④）。
  Future<void> _pickWeekStart(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(weekStartPreferenceRepositoryProvider);
    if (repo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地数据库尚未就绪，暂时无法修改星期开始于')));
      return;
    }
    final current = resolveWeekStartFirstDay(ref.read(weekStartProvider));
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final firstDay in WeekStart.allowedFirstDays)
              ListTile(
                key: Key('todo-settings-week-start-option-$firstDay'),
                title: Text(WeekStart.labelOf(firstDay)),
                trailing: firstDay == current
                    ? Icon(
                        Icons.check,
                        color: brandColors(context).mutedForeground,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(firstDay),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await repo.save(picked);
    } catch (_) {
      // 四件套 ③：保存失败只提示，不改当前生效的档位
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，星期开始于仍为当前设置')));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// 嘀嗒《…04-用标签管理任务.md》:16/:27 的取值是「显示」/「隐藏」二选一，
  /// 所以这里照抄成选项弹层，而不是自创一个 Switch。
  ///
  /// 写入的是"点中的那个字面值"，不是从当前值取反 ⇒ 读到的当前值过期也只会
  /// 让勾选标记画错一帧，不可能把更新的值盖回去（spec.md 四件套 ④）。
  Future<void> _pickShowTags(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(sidebarVisibilityRepositoryProvider);
    if (repo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地数据库尚未就绪，暂时无法修改显示标签')));
      return;
    }
    final current =
        ref.read(sidebarShowTagsProvider).valueOrNull ??
        SidebarVisibilityRepository.defaultShowTags;
    final picked = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in const [(true, '显示'), (false, '隐藏')])
              ListTile(
                key: Key('todo-settings-show-tags-option-$value'),
                title: Text(label),
                trailing: value == current
                    ? Icon(
                        Icons.check,
                        color: brandColors(context).mutedForeground,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await repo.save(showTags: picked);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，显示标签仍为当前设置')));
    }
  }

  /// 嘀嗒《…05-过滤器…》:29/:33「确认侧边栏中是否已经开启显示过滤器」⇒ 同一份「显示/隐藏」形状。
  /// 与 [_pickShowTags] 一样写"点中的那个字面值"，不从当前值取反（四件套 ④）。
  /// 「设置 > 功能模块」那三档：命名照抄嘀嗒点名的三句原文（specs/107）。
  /// 看板不在表里——《02-看板视图：分类管理任务》:14 写明它不是功能模块。
  static String _featureModuleLabel(TodoFeatureModule module) =>
      switch (module) {
        TodoFeatureModule.quadrant => '四象限',
        TodoFeatureModule.pomodoro => '番茄专注',
        TodoFeatureModule.search => '搜索',
      };

  static IconData _featureModuleIcon(TodoFeatureModule module) =>
      switch (module) {
        TodoFeatureModule.quadrant => Icons.grid_view_outlined,
        TodoFeatureModule.pomodoro => Icons.timer_outlined,
        TodoFeatureModule.search => Icons.search,
      };

  static String _featureModuleHint(TodoFeatureModule module) =>
      switch (module) {
        TodoFeatureModule.quadrant => '按重要与紧急程度分类管理任务',
        TodoFeatureModule.pomodoro => '专注计时与专注记录',
        TodoFeatureModule.search => '通过侧栏与右上角入口进入搜索页面',
      };

  static String _featureModuleStateLabel(AsyncValue<bool> value) {
    if (!value.hasValue) return value.isLoading ? '…' : '开启';
    return value.value! ? '开启' : '关闭';
  }

  Future<void> _pickFeatureModule(
    BuildContext context,
    WidgetRef ref,
    TodoFeatureModule module,
  ) async {
    final repo = ref.read(sidebarVisibilityRepositoryProvider);
    if (repo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('本地数据库尚未就绪，暂时无法修改${_featureModuleLabel(module)}'),
        ),
      );
      return;
    }
    final current =
        ref.read(featureModuleProvider(module)).valueOrNull ??
        SidebarVisibilityRepository.defaultFeatureEnabled;
    final picked = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in const [(true, '开启'), (false, '关闭')])
              ListTile(
                key: Key('todo-settings-module-${module.name}-option-$value'),
                title: Text(label),
                trailing: value == current
                    ? Icon(
                        Icons.check,
                        color: brandColors(context).mutedForeground,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await repo.saveFeature(module: module, enabled: picked);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败，${_featureModuleLabel(module)}仍为当前设置')),
      );
    }
  }

  Future<void> _pickShowFilters(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(sidebarVisibilityRepositoryProvider);
    if (repo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地数据库尚未就绪，暂时无法修改过滤器')));
      return;
    }
    final current =
        ref.read(sidebarShowFiltersProvider).valueOrNull ??
        SidebarVisibilityRepository.defaultShowFilters;
    final picked = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in const [(true, '显示'), (false, '隐藏')])
              ListTile(
                key: Key('todo-settings-show-filters-option-$value'),
                title: Text(label),
                trailing: value == current
                    ? Icon(
                        Icons.check,
                        color: brandColors(context).mutedForeground,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await repo.saveFilters(showFilters: picked);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，过滤器仍为当前设置')));
    }
  }
}

class _TaskCaptureDefaultsPage extends ConsumerStatefulWidget {
  const _TaskCaptureDefaultsPage();

  @override
  ConsumerState<_TaskCaptureDefaultsPage> createState() =>
      _TaskCaptureDefaultsPageState();
}

class _TaskCaptureDefaultsPageState
    extends ConsumerState<_TaskCaptureDefaultsPage> {
  TaskCaptureDefaults? _defaults;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final defaults = await ref
          .read(taskCaptureDefaultsRepositoryProvider)
          ?.get();
      if (mounted) {
        setState(() => _defaults = defaults ?? const TaskCaptureDefaults());
      }
    });
  }

  Future<void> _save() async {
    final defaults = _defaults;
    final repo = ref.read(taskCaptureDefaultsRepositoryProvider);
    if (defaults == null || repo == null) return;
    setState(() => _saving = true);
    await repo.save(defaults);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('新任务默认值已保存，等待同步')));
  }

  @override
  Widget build(BuildContext context) {
    final defaults = _defaults;
    final lists = ref.watch(listsStreamProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('新任务默认值')),
      body: defaults == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 桌面端别把三个下拉和主按钮拉满整屏：表单限宽居中。
                // 下拉展开层的宽度跟字段走，字段收窄后菜单也不再是一整屏宽的板子。
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String?>(
                          key: ValueKey(defaults.defaultListId),
                          initialValue: defaults.defaultListId,
                          decoration: const InputDecoration(
                            labelText: '默认清单',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('收集箱'),
                            ),
                            ...lists.map(
                              (list) => DropdownMenuItem<String?>(
                                value: list.id,
                                child: Text(list.name),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _defaults = TaskCaptureDefaults(
                              defaultListId: value,
                              defaultPriority: defaults.defaultPriority,
                              defaultReminderMinutes:
                                  defaults.defaultReminderMinutes,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey(defaults.defaultPriority),
                          initialValue: defaults.defaultPriority,
                          decoration: const InputDecoration(
                            labelText: '默认优先级',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('无')),
                            DropdownMenuItem(value: 1, child: Text('低')),
                            DropdownMenuItem(value: 2, child: Text('中')),
                            DropdownMenuItem(value: 3, child: Text('高')),
                          ],
                          onChanged: (value) => setState(
                            () => _defaults = TaskCaptureDefaults(
                              defaultListId: defaults.defaultListId,
                              defaultPriority: value ?? 0,
                              defaultReminderMinutes:
                                  defaults.defaultReminderMinutes,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 嘀嗒《04-超强大的提醒功能.md》:33「在…『任务默认值』-『默认提醒』中
                        // 选择常用的提醒」。null（「不提醒」）与 0（「准时」）是两档。
                        DropdownButtonFormField<int?>(
                          key: const Key('task-default-reminder'),
                          initialValue: defaults.defaultReminderMinutes,
                          decoration: const InputDecoration(
                            labelText: '默认提醒',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('不提醒'),
                            ),
                            DropdownMenuItem<int?>(value: 0, child: Text('准时')),
                            DropdownMenuItem<int?>(
                              value: 5,
                              child: Text('提前 5 分钟'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 15,
                              child: Text('提前 15 分钟'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 30,
                              child: Text('提前 30 分钟'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 60,
                              child: Text('提前 1 小时'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 120,
                              child: Text('提前 2 小时'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _defaults = TaskCaptureDefaults(
                              defaultListId: defaults.defaultListId,
                              defaultPriority: defaults.defaultPriority,
                              defaultReminderMinutes: value,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中…' : '保存默认值'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 「设置 → 日期与时间 → 时区」总开关（specs/055 / FL Issue #368）。
///
/// 值直接读仓储流的现值、不做乐观更新：写失败时本地状态没变，
/// 开关因此**自动留在切换前**，这就是四件套里"失败保留已加载数据"的落法。
class _TimezonePreferenceTile extends ConsumerWidget {
  const _TimezonePreferenceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    final enabled = ref.watch(timezoneEnabledProvider).valueOrNull ?? true;
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        key: const ValueKey('settings-timezone-enabled'),
        // 不覆写 contentPadding：同一张卡里的「显示农历」等开关与其它卡片的
        // trailing 文案都走 ListTile 默认内边距，这里一写死就会让这枚开关错开一条竖线。
        title: Text('时区', style: TextStyle(color: colors.foreground)),
        subtitle: Text(
          '开启后可为任务选择「固定时区」',
          style: TextStyle(color: colors.mutedForeground),
        ),
        value: enabled,
        onChanged: (value) => _save(context, ref, value),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(timezonePreferenceRepositoryProvider);
    if (repo == null) {
      messenger.showSnackBar(const SnackBar(content: Text('时区设置暂不可用')));
      return;
    }
    try {
      await repo.setEnabled(value);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('时区设置未保存')));
    }
  }
}

/// 「显示农历 / 显示节假日调休 / 显示习惯打卡」三个开关各管一位。
///
/// 用枚举而不是拿标题字符串比对：三者共用同一行偏好，靠
/// `widget.title == '…'` 分支时漏写一路，就会把隔壁那位一起改掉（实际踩过）。
enum _CalendarInfoField { lunar, holidays, habits }

/// 「显示农历 / 显示节假日调休」开关（嘀嗒《06-日历显示设置》:5-21；
/// specs/125，矩阵 #31 面 ①）。两个布尔位同仓一行偏好（CALENDAR_INFO/global）。
class _CalendarInfoToggleTile extends ConsumerStatefulWidget {
  const _CalendarInfoToggleTile({
    super.key,
    required this.title,
    required this.field,
  });

  final String title;
  final _CalendarInfoField field;

  @override
  ConsumerState<_CalendarInfoToggleTile> createState() =>
      _CalendarInfoToggleTileState();
}

class _CalendarInfoToggleTileState
    extends ConsumerState<_CalendarInfoToggleTile> {
  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final flags = ref.watch(calendarInfoFlagsProvider).valueOrNull;
    final value = switch (widget.field) {
      _CalendarInfoField.lunar => flags?.showLunar ?? false,
      _CalendarInfoField.holidays => flags?.showHolidays ?? false,
      _CalendarInfoField.habits => flags?.showHabits ?? false,
    };
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        secondary: Icon(
          widget.field == _CalendarInfoField.lunar
              ? Icons.nights_stay_outlined
              : Icons.event_outlined,
          color: colors.mutedForeground,
        ),
        title: Text(widget.title),
        value: value,
        onChanged: (next) async {
          final repo = ref.read(calendarInfoPreferenceRepositoryProvider);
          if (repo == null) return;
          final current =
              flags ??
              const CalendarInfoFlags(
                showLunar: false,
                showHolidays: false,
                showHabits: false,
              );
          final messenger = ScaffoldMessenger.maybeOf(context);
          try {
            await repo.save(
              CalendarInfoFlags(
                showLunar: widget.field == _CalendarInfoField.lunar
                    ? next
                    : current.showLunar,
                showHolidays: widget.field == _CalendarInfoField.holidays
                    ? next
                    : current.showHolidays,
                showHabits: widget.field == _CalendarInfoField.habits
                    ? next
                    : current.showHabits,
              ),
            );
          } catch (_) {
            messenger?.showSnackBar(
              const SnackBar(content: Text('设置保存失败，请重试')),
            );
          }
        },
      ),
    );
  }
}

/// 侧栏可见性偏好的三态读法，「显示标签」与「过滤器」共用一份口径：
/// 有值就用值 —— 包括"出过一次值之后流才失败"（四件套 ③ 失败保留已加载数据）；
/// 没值且失败才显示「读取失败」；没值且未失败是加载中，显示「…」。
/// 写成 `.when(error: …)` 会把第一态折进第三态（FL Issue #363）。
String _visibilityLabel(AsyncValue<bool> state) {
  final value = state.valueOrNull;
  if (value != null) return value ? '显示' : '隐藏';
  return state.hasError ? '读取失败' : '…';
}

/// 只在"留住旧值 + 流已失败"时出现：留住旧值不等于把失败藏起来。
bool _visibilityStale(AsyncValue<bool> state) =>
    state.valueOrNull != null && state.hasError;

String _showTagsLabel(AsyncValue<bool> state) => _visibilityLabel(state);

bool _showTagsStale(AsyncValue<bool> state) => _visibilityStale(state);

UpdateSurface _updateSurface() {
  final operatingSystem = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.fuchsia => 'fuchsia',
  };
  return updateSurfaceFor(isWeb: kIsWeb, operatingSystem: operatingSystem);
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.mutedForeground,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.title,
    required this.colors,
    this.subtitle,
    this.trailing,
    this.trailingText,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData? trailing;

  /// 偏好当前值用文字而不是勾：读屏念到的是「标签 显示」，与嘀嗒设置页的取值同源。
  final String? trailingText;
  final AppColors colors;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? colors.destructive : colors.foreground;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, color: fg),
        title: Text(title, style: TextStyle(color: fg)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(color: colors.mutedForeground)),
        trailing: trailingText != null
            ? Text(
                trailingText!,
                style: TextStyle(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              )
            : trailing == null
            ? null
            : Icon(trailing, color: colors.mutedForeground),
        onTap: onTap,
      ),
    );
  }
}
