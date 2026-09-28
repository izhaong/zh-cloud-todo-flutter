import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/time/week_start.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/providers.dart';
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
                  subtitle: '默认清单与优先级；离线保存后自动同步',
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _TaskCaptureDefaultsPage(),
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
                  subtitle: '查看当前可用的组合键（?）',
                  colors: colors,
                  onTap: () => showKeyboardShortcutsDialog(context),
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
                _TimezonePreferenceTile(),
                _Tile(
                  key: const Key('todo-settings-week-start'),
                  icon: Icons.view_week_outlined,
                  title: '星期开始于',
                  subtitle: weekStartLabel,
                  trailing: Icons.chevron_right,
                  colors: colors,
                  onTap: () => _pickWeekStart(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(title: '智能清单'),
          AppCard(
            padding: EdgeInsets.zero,
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
            child: _Tile(
              icon: Icons.info_outline,
              title: '版本号',
              subtitle: 'zh-cloud todo（本地离线优先版）',
              colors: colors,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

/// 侧栏「显示标签」取值的三态读法，与 `lib/features/shell/sidebar.dart` 同一口径：
/// 有值就用值 —— 包括"出过一次值之后流才失败"（四件套 ③ 失败保留已加载数据）；
/// 没值且失败才显示「读取失败」；没值且未失败是加载中，显示「…」。
/// 写成 `.when(error: …)` 会把第一态折进第三态（FL Issue #363）。
String _showTagsLabel(AsyncValue<bool> state) {
  final value = state.valueOrNull;
  if (value != null) return value ? '显示' : '隐藏';
  return state.hasError ? '读取失败' : '…';
}

/// 只在"留住旧值 + 流已失败"时出现：留住旧值不等于把失败藏起来。
bool _showTagsStale(AsyncValue<bool> state) =>
    state.valueOrNull != null && state.hasError;

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
