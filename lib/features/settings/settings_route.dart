import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/providers.dart';
import '../../state/repositories/task_capture_defaults_repository.dart';
import '../../state/session_state.dart';
import '../achievement/achievement_page.dart';
import '../account/account_security_page.dart';
import '../calendar_sub/calendar_subscription_page.dart';
import '../import/task_import_page.dart';
import '../home/keyboard_shortcuts_dialog.dart';
import '../native/native_entry_page.dart';
import '../shell/app_theme_controller.dart';

/// 设置页：分组列表（账户/任务/主题/关于）+ 账户安全与成就入口。
class SettingsRoute extends ConsumerWidget {
  const SettingsRoute({super.key, this.signedInMobile});

  final String? signedInMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
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
            child: Column(children: const [_TimezonePreferenceTile()]),
          ),
          const SizedBox(height: 16),
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

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
        title: Text(
          '时区',
          // 实测（探针跑在 specs/055/tasks.md 记的那次）：`SwitchListTile` 的合并语义节点上
          // `isChecked` / `isToggled` 恒为 `none` ⇒ 光靠 `Switch` 自己，读屏念不出开还是关。
          // 状态挂在 label 上（merge 只合并 label，不合并 flags），屏幕阅读器才真念得出来。
          semanticsLabel: enabled ? '时区，已开启' : '时区，已关闭',
          style: TextStyle(color: colors.foreground),
        ),
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
    required this.icon,
    required this.title,
    required this.colors,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData? trailing;
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
        trailing: trailing == null
            ? null
            : Icon(trailing, color: colors.mutedForeground),
        onTap: onTap,
      ),
    );
  }
}
