import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:file_picker/file_picker.dart';

import '../../core/api/attachment_upload_api.dart';
import '../../core/api/efficiency_api.dart';
import '../../core/api/error_text.dart';
import '../../state/providers.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';

/// 嘀嗒的三档样式；取值与服务端 `AppTodoCountdownBaseVO.style` 注释一致。
const Map<int, String> _countdownStyles = {1: '默认', 2: '翻页', 3: '圆环'};

/// M11-B4 倒数日列表 + 新建；024 补编辑、删除与样式呈现。
/// 嘀嗒《02-打造专属纪念页.md:97》（mobile：详情页）/`:106`（desktop：卡片）：
/// 「点击中间的天数，就能在**天、年、周**三种单位间快速切换」。
/// 源页只给单位集合，未规定循环顺序 ⇒ 天→年→周→天 是实现选择，记在 spec 取舍。
enum TodoCountdownUnit {
  day('天'),
  year('年'),
  week('周');

  const TodoCountdownUnit(this.suffix);

  final String suffix;

  TodoCountdownUnit get next =>
      TodoCountdownUnit.values[(index + 1) % TodoCountdownUnit.values.length];
}

/// 倒数纪念日的目标日期展示形状：月/日一律补零（`2026-11-03`，不是 `2026-11-3`）。
///
/// 同屏其它日期面（任务、日历）都是补零的，裸插值会在这屏里变成两种写法并存。
/// 列表副标题与编辑器的日期按钮共用它，避免只修一处。
String countdownDateText(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// 正数且关掉 showAge 时，源页那一行只显示目标日期（develop 既有行为，`!259`）。
/// 顶层而非页面私有：tile 与页面都要用同一份文案，别让 tile 反向依赖页面类。
String countdownDateSubtitle(CountdownDto c) => countdownDateText(c.targetDate);

/// 前缀取源页用词：《01-添加倒数纪念日.md:106》「显示距离该日期已过/还有多少天」
/// ⇒ 正数「已过」、倒数「还有」，不自创「已 N 天」。只给整数档：
/// 源页 `:93` 问的是「这是多少年，或是多少周」，带余数就得自己发明格式。
String countdownCountLabel({
  required bool isCountUp,
  required int daysRemaining,
  required TodoCountdownUnit unit,
}) {
  final days = daysRemaining.abs();
  final amount = switch (unit) {
    TodoCountdownUnit.day => days,
    TodoCountdownUnit.year => days ~/ 365,
    TodoCountdownUnit.week => days ~/ 7,
  };
  return '${isCountUp ? '已过 ' : '还有 '}$amount ${unit.suffix}';
}

/// 单位切换是按行的会话内状态 ⇒ 整行搬进有状态组件。
/// 行体沿用 develop 的自建布局：`ListTile` 会把 trailing 并进整行语义节点，
/// 编辑与删除就不再独立可读 ⇒ 不用 ListTile，三个动作各留自己的语义。
class _CountdownTile extends StatefulWidget {
  const _CountdownTile({
    required this.item,
    required this.writePending,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
    required this.onRestore,
    required this.onPin,
  });

  final CountdownDto item;
  final bool writePending;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onPin;

  @override
  State<_CountdownTile> createState() => _CountdownTileState();
}

class _CountdownTileState extends State<_CountdownTile> {
  TodoCountdownUnit _unit = TodoCountdownUnit.day;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    // 正数且关掉「显示已过天数」时源页那一行只有目标日期：中间没有天数，
    // 就没有可点的单位入口（:97 说的是「点击中间的天数」，不另造按钮）。
    final showDays = item.isCountUp ? item.showAge : true;
    final label = showDays
        ? countdownCountLabel(
            isCountUp: item.isCountUp,
            daysRemaining: item.daysRemaining,
            unit: _unit,
          )
        : countdownDateSubtitle(item);
    final background = item.backgroundImage;
    return InkWell(
      key: Key('countdown-row-${item.id}'),
      onTap: widget.writePending ? null : widget.onEdit,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (parseCountdownColor(item.color) != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(
                key: Key('countdown-color-strip-${item.id}'),
                color: parseCountdownColor(item.color),
              ),
            ),
          if (background != null && background.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                background,
                key: Key('countdown-background-${item.id}'),
                fit: BoxFit.cover,
                semanticLabel: '${item.title} 的背景图',
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _CountdownBadge(countdown: item),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 嘀嗒备注的「在详情页中显示」开关：本端暂无独立详情页（矩阵 #49 ④），
                      // 卡片行就是详情表面，开关开着才把备注带出来。
                      if (item.noteShowInDetail &&
                          (item.note?.isNotEmpty ?? false))
                        Text(
                          item.note!,
                          key: Key('countdown-note-${item.id}'),
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (showDays)
                        Semantics(
                          container: true,
                          button: true,
                          label: '切换天数单位 $label',
                          child: InkWell(
                            key: Key('todo-countdown-unit-${item.id}'),
                            onTap: widget.writePending
                                ? null
                                : () => setState(() => _unit = _unit.next),
                            child: ExcludeSemantics(
                              child: Text(
                                label,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: '更多操作 ${item.title}',
                  child: ExcludeSemantics(
                    child: PopupMenuButton<String>(
                      key: Key('countdown-tile-more-${item.id}'),
                      enabled: !widget.writePending,
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) {
                        if (value == 'archive') widget.onArchive();
                        if (value == 'restore') widget.onRestore();
                        if (value == 'pin') widget.onPin();
                      },
                      itemBuilder: (_) => [
                        if (item.archived)
                          PopupMenuItem<String>(
                            key: Key('countdown-menu-restore-${item.id}'),
                            value: 'restore',
                            child: const Text('恢复'),
                          )
                        else
                          PopupMenuItem<String>(
                            key: Key('countdown-menu-archive-${item.id}'),
                            value: 'archive',
                            child: const Text('归档'),
                          ),
                        if (!item.archived && !item.isPinned)
                          PopupMenuItem<String>(
                            key: Key('countdown-menu-pin-${item.id}'),
                            value: 'pin',
                            child: const Text('置顶'),
                          ),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: '编辑 ${item.title}',
                  onTap: widget.writePending ? null : widget.onEdit,
                  child: ExcludeSemantics(
                    child: IconButton(
                      key: Key('countdown-edit-${item.id}'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: widget.writePending ? null : widget.onEdit,
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: '删除 ${item.title}',
                  onTap: widget.writePending ? null : widget.onDelete,
                  child: ExcludeSemantics(
                    child: IconButton(
                      key: Key('countdown-delete-${item.id}'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: widget.writePending ? null : widget.onDelete,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 选背景图与上传背景图两条缝隙：默认走 `file_picker`（本仓只有静态用法）与 infra 文件服务；
/// 测试注入假的实现，「切换图片」这条入口才能在 widget 测里判。
typedef CountdownBackgroundPicker = Future<String?> Function();
typedef CountdownBackgroundUploader =
    Future<String> Function(String localPath, String name);

/// 嘀嗒《03-管理倒数纪念日.md:187》「在倒数纪念日列表中左滑，即可快速进行置顶、归档或删除操作」。
/// 行左滑露出快捷钮；`:204` 写明开启分组后不再支持滑动 ⇒ 只包未分组的非归档视图。
class _SwipeAction {
  const _SwipeAction({
    required this.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final Key key;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
}

class _SwipeRevealRow extends StatefulWidget {
  const _SwipeRevealRow({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<_SwipeAction> actions;
  final Widget child;

  @override
  State<_SwipeRevealRow> createState() => _SwipeRevealRowState();
}

class _SwipeRevealRowState extends State<_SwipeRevealRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  double get _actionsWidth => 72.0 * widget.actions.length;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            _ctrl.stop();
            _ctrl.value = (_ctrl.value - details.delta.dx / _actionsWidth)
                .clamp(0.0, 1.0);
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            final open = _ctrl.value > 0.4 || velocity < -400;
            _ctrl.animateTo(
              open ? 1 : 0,
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 150),
            );
          },
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _actionsWidth,
                child: Row(
                  children: [
                    for (final action in widget.actions)
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: action.label,
                          child: ExcludeSemantics(
                            child: Material(
                              color: action.background,
                              child: InkWell(
                                key: action.key,
                                onTap: action.onPressed,
                                child: Center(
                                  child: Text(
                                    action.label,
                                    style: TextStyle(
                                      color: action.foreground,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) => Transform.translate(
                  offset: Offset(-_actionsWidth * _ctrl.value, 0),
                  child: SizedBox(width: width, child: child),
                ),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class CountdownPage extends ConsumerStatefulWidget {
  const CountdownPage({
    super.key,
    this.pickBackgroundImage,
    this.uploadBackgroundImage,
  });

  final CountdownBackgroundPicker? pickBackgroundImage;
  final CountdownBackgroundUploader? uploadBackgroundImage;

  @override
  ConsumerState<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends ConsumerState<CountdownPage> {
  /// 模态框关闭后列表入口即可再点；并发写会让后返回的旧列表响应覆盖新结果，
  /// 因此一次只放行一个写请求。
  bool _writePending = false;

  /// 嘀嗒《03-管理倒数纪念日》把内容分成主列表与「已归档」两个视图。
  bool _showArchived = false;

  String? _archiveError;
  Future<void> Function()? _archiveRetry;

  /// 失败文案要按实际那一步说「归档失败」还是「恢复失败」，不许两件事共用一句。
  String? _archiveFailedAction;
  bool _showGroups = false;

  /// 嘀嗒 mobile 段「点击顶部分组名或左右滑动页面切换分组」：当前停在 groups
  /// 的第几组（下标），一次只显示一组。
  int _activeGroupIndex = 0;
  String? _pinError;
  Future<void> Function()? _pinRetry;

  Future<void> _runWrite(Future<void> Function() write) async {
    if (_writePending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _writePending = true);
    try {
      await write();
      ref.invalidate(countdownsProvider);
      ref.invalidate(archivedCountdownsProvider);
    } on Object catch (error) {
      // 失败时不刷新列表，原数据仍在原位并可重试。
      // 页面已卸载时不得再弹：context 脱离树后 showSnackBar 会抛，
      // 且该抛点位于 catch 内，没人再兜住它。
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('操作失败：${describeError(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _writePending = false);
    }
  }

  /// 归档／恢复单独走一条路：失败时把提示放在列表上方当场可见，
  /// 并记住这一步以便重试；已加载的列表数据不受影响。
  Future<void> _runArchive(CountdownDto item, bool archived) async {
    if (_writePending) return;
    setState(() => _writePending = true);
    try {
      await ref.read(countdownApiProvider).setArchived(item.id, archived);
      if (mounted) {
        setState(() {
          _archiveError = null;
          _archiveRetry = null;
        });
      }
      ref.invalidate(countdownsProvider);
      ref.invalidate(archivedCountdownsProvider);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _archiveError = describeError(error);
          _archiveFailedAction = archived ? '归档' : '恢复';
          _archiveRetry = () => _runArchive(item, archived);
        });
      }
    } finally {
      if (mounted) setState(() => _writePending = false);
    }
  }

  Future<void> _runPin(CountdownDto item) async {
    setState(() => _pinError = null);
    try {
      await ref.read(countdownApiProvider).setPinned(item.id, true);
      ref.invalidate(countdownsProvider);
      ref.invalidate(archivedCountdownsProvider);
      await ref.read(countdownsProvider.future);
      setState(() => _pinRetry = null);
    } catch (error) {
      setState(() {
        _pinError = describeError(error);
        _pinRetry = () => _runPin(item);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      _showArchived ? archivedCountdownsProvider : countdownsProvider,
    );
    // 同 #375：重取失败时 AsyncError 仍带上一次的 value，`.when` 会把它丢掉 ⇒ 先读 valueOrNull。
    final items = async.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? '已归档' : '倒数日'),
        actions: [
          if (!_showArchived)
            IconButton(
              tooltip: '新建倒数纪念日',
              icon: const Icon(Icons.add),
              onPressed: _writePending ? null : () => _showEditor(),
            ),
          PopupMenuButton<String>(
            key: const Key('countdown-page-more'),
            enabled: !_writePending,
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) => setState(() {
              if (value == 'groups') {
                _showGroups = !_showGroups;
                _activeGroupIndex = 0;
                return;
              }
              _showArchived = value == 'archived';
              _archiveError = null;
              _archiveRetry = null;
              _archiveFailedAction = null;
            }),
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                key: const Key('countdown-menu-groups'),
                value: 'groups',
                child: Row(
                  children: [
                    const Text('显示分组'),
                    if (_showGroups)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check, size: 18),
                      ),
                  ],
                ),
              ),
              if (!_showArchived)
                const PopupMenuItem<String>(
                  key: Key('countdown-menu-archived'),
                  value: 'archived',
                  child: Text('已归档'),
                )
              else
                const PopupMenuItem<String>(
                  key: Key('countdown-menu-main'),
                  value: 'main',
                  child: Text('主列表'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pinError != null)
            AppRefreshFailedHint(
              key: const Key('countdown-pin-error'),
              message: '置顶失败：$_pinError，列表仍是上一次加载的数据',
              onRetry: () => _pinRetry?.call(),
            ),
          if (_archiveError != null)
            AppRefreshFailedHint(
              key: const Key('countdown-archive-error'),
              message: '$_archiveFailedAction失败：$_archiveError，列表仍是上一次加载的数据',
              onRetry: () => _archiveRetry?.call(),
            ),
          if (items == null)
            Expanded(
              child: async.hasError
                  ? Center(child: Text('加载失败: ${describeError(async.error)}'))
                  : const Center(child: CircularProgressIndicator()),
            )
          else if (async.hasError)
            Expanded(
              child: Column(
                children: [
                  AppRefreshFailedHint(
                    message: '列表刷新失败，仍显示上一次的数据',
                    onRetry: () => ref.invalidate(
                      _showArchived
                          ? archivedCountdownsProvider
                          : countdownsProvider,
                    ),
                  ),
                  Expanded(child: _countdownList(items)),
                ],
              ),
            )
          else
            Expanded(child: _countdownList(items)),
        ],
      ),
    );
  }

  /// 首值就没读到不走这里：上面已按 `items == null` 分流。
  Widget _countdownList(List<CountdownDto> items) {
    if (items.isEmpty) {
      return const Center(child: Text('暂无倒数日'));
    }
    if (!_showGroups) {
      // 嘀嗒 :187：未分组的主列表行支持左滑快捷（置顶/归档/删除）；
      // 「已归档」视图不在 :187 的范围内，保持行尾按钮形态。
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) =>
            _showArchived ? _tileFor(items[i]) : _swipeableTile(items[i]),
      );
    }
    // 嘀嗒 :9「开启后，所有日子将根据类型自动分组：倒数日、纪念日、生日、节日」
    // 四类是固定档，空档不出分组名；分类只认服务端给的 type，客户端不自造判据。
    const labels = {1: '倒数日', 2: '纪念日', 3: '生日', 4: '节日'};
    final groups = labels.entries
        .where((entry) => items.any((c) => c.type == entry.key))
        .toList(growable: false);
    if (groups.isEmpty) {
      // 条目的 type 全是未知档：退回平铺，别把已有条目藏没。
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => _tileFor(items[i]),
      );
    }
    // 数据刷新后组数变少时下标可能越界，就地收敛到最后一组。
    if (_activeGroupIndex >= groups.length) {
      _activeGroupIndex = groups.length - 1;
    }
    final active = groups[_activeGroupIndex];
    // 嘀嗒 mobile 段「你可以点击顶部分组名或左右滑动页面切换分组」：
    // 顶部分组名点击直达，列表区横滑翻到相邻组；竖向滚动仍归 ListView。
    return Column(
      children: [
        SingleChildScrollView(
          key: const Key('countdown-group-tabs'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              for (var i = 0; i < groups.length; i++)
                Semantics(
                  key: Key('countdown-group-tab-${groups[i].key}'),
                  button: true,
                  selected: i == _activeGroupIndex,
                  label: groups[i].value,
                  child: ExcludeSemantics(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _activeGroupIndex = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          groups[i].value,
                          style: TextStyle(
                            fontWeight: i == _activeGroupIndex
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: i == _activeGroupIndex
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -120 && _activeGroupIndex < groups.length - 1) {
                setState(() => _activeGroupIndex += 1);
              } else if (velocity > 120 && _activeGroupIndex > 0) {
                setState(() => _activeGroupIndex -= 1);
              }
            },
            child: _groupPage(active, items),
          ),
        ),
      ],
    );
  }

  Widget _groupPage(MapEntry<int, String> entry, List<CountdownDto> items) {
    final group = items.where((c) => c.type == entry.key).toList();
    return ListView(
      key: const Key('countdown-group-list'),
      children: [
        Semantics(
          key: Key('countdown-group-header-${entry.key}'),
          container: true,
          header: true,
          label: entry.value,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                entry.value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        for (final c in group) _tileFor(c),
      ],
    );
  }

  Widget _tileFor(CountdownDto c) {
    return _CountdownTile(
      item: c,
      writePending: _writePending,
      onEdit: () => _showEditor(existing: c),
      onDelete: () => _confirmDelete(c),
      onArchive: () => _runArchive(c, true),
      onRestore: () => _runArchive(c, false),
      onPin: () => _runPin(c),
    );
  }

  /// 嘀嗒 :187「左滑，即可快速进行置顶、归档或删除操作」；:204 写明
  /// 「开启分组后不再支持滑动」⇒ 已分组页面走 _groupPage，不经这里。
  Widget _swipeableTile(CountdownDto c) {
    final scheme = Theme.of(context).colorScheme;
    return _SwipeRevealRow(
      key: Key('countdown-swipe-${c.id}'),
      actions: [
        if (!c.isPinned)
          _SwipeAction(
            key: Key('countdown-swipe-pin-${c.id}'),
            label: '置顶',
            background: scheme.primaryContainer,
            foreground: scheme.onPrimaryContainer,
            onPressed: _writePending ? null : () => _runPin(c),
          ),
        _SwipeAction(
          key: Key('countdown-swipe-archive-${c.id}'),
          label: '归档',
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          onPressed: _writePending ? null : () => _runArchive(c, true),
        ),
        _SwipeAction(
          key: Key('countdown-swipe-delete-${c.id}'),
          label: '删除',
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          onPressed: _writePending ? null : () => _confirmDelete(c),
        ),
      ],
      child: _tileFor(c),
    );
  }

  Future<void> _confirmDelete(CountdownDto countdown) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${countdown.title}」？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('countdown-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runWrite(() => ref.read(countdownApiProvider).delete(countdown.id));
  }

  Future<void> _showEditor({CountdownDto? existing}) async {
    final draft = existing == null
        ? _CountdownDraft(
            title: '',
            targetDate: DateTime.now().add(const Duration(days: 30)),
          )
        : _CountdownDraft(
            title: existing.title,
            targetDate: existing.targetDate,
            style: existing.style,
            showAge: existing.showAge,
            backgroundImage: existing.backgroundImage,
            color: existing.color,
            note: existing.note ?? '',
            noteShowInDetail: existing.noteShowInDetail,
          );
    final saved = await showDialog<_CountdownDraft>(
      context: context,
      builder: (ctx) => _CountdownEditor(
        initial: draft,
        isNew: existing == null,
        pickImage:
            widget.pickBackgroundImage ??
            () async {
              final picked = await FilePicker.pickFiles(type: FileType.image);
              if (picked == null || picked.files.isEmpty) return null;
              return picked.files.first.path;
            },
        uploadImage:
            widget.uploadBackgroundImage ??
            (localPath, name) => DioAttachmentUploadApi(
              ref.read(apiClientProvider),
            ).uploadFile(localPath: localPath, name: name),
      ),
    );
    if (saved == null || !mounted) return;
    final api = ref.read(countdownApiProvider);
    if (existing == null) {
      await _runWrite(
        () => api.create(
          title: saved.title,
          targetDate: saved.targetDate,
          style: saved.style,
          showAge: saved.showAge,
          backgroundImage: saved.backgroundImage,
          color: saved.color,
          note: saved.note,
          noteShowInDetail: saved.noteShowInDetail,
        ),
      );
    } else {
      final id = existing.id;
      await _runWrite(
        () => api.update(
          id: id,
          title: saved.title,
          targetDate: saved.targetDate,
          style: saved.style,
          showAge: saved.showAge,
          backgroundImage: saved.backgroundImage,
          color: saved.color,
          note: saved.note,
          noteShowInDetail: saved.noteShowInDetail,
        ),
      );
    }
  }
}

class _CountdownDraft {
  const _CountdownDraft({
    required this.title,
    required this.targetDate,
    this.style = 1,
    this.showAge = false,
    this.backgroundImage,
    this.color,
    this.note = '',
    this.noteShowInDetail = false,
  });

  final String title;
  final DateTime targetDate;
  final int style;
  final bool showAge;
  final String? backgroundImage;
  final String? color;
  final String note;
  final bool noteShowInDetail;

  _CountdownDraft copyWith({
    String? title,
    DateTime? targetDate,
    int? style,
    bool? showAge,
    String? backgroundImage,
    String? color,
    String? note,
    bool? noteShowInDetail,
  }) {
    return _CountdownDraft(
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      style: style ?? this.style,
      showAge: showAge ?? this.showAge,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      color: color ?? this.color,
      note: note ?? this.note,
      noteShowInDetail: noteShowInDetail ?? this.noteShowInDetail,
    );
  }
}

/// 嘀嗒《02-打造专属纪念页.md》「挑选样式后，还可以为它配置专属颜色」——
/// 预设色板（服务端不校验色值，客户端自守 #RRGGBB）。
const _countdownColorChoices = <String>[
  '#FF6B6B',
  '#F59E0B',
  '#22C55E',
  '#3B82F6',
  '#8B5CF6',
  '#EC4899',
  '#14B8A6',
  '#F97316',
];

/// `#RRGGBB` / `#AARRGGBB`；空串、非法串与 null 都算「没指定」。
Color? parseCountdownColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

class _CountdownEditor extends StatefulWidget {
  const _CountdownEditor({
    required this.initial,
    required this.isNew,
    required this.pickImage,
    required this.uploadImage,
  });

  final _CountdownDraft initial;
  final bool isNew;
  final CountdownBackgroundPicker pickImage;
  final CountdownBackgroundUploader uploadImage;

  @override
  State<_CountdownEditor> createState() => _CountdownEditorState();
}

class _CountdownEditorState extends State<_CountdownEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial.title,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.initial.note,
  );
  late _CountdownDraft _draft = widget.initial;
  String? _imageError;
  bool _uploading = false;

  /// 嘀嗒《02-功能指南/06-倒数纪念日/02-打造专属纪念页.md》「在样式编辑窗口，点击「切换图片」，
  /// 可以上传新的背景图片」⇒ 入口文案照抄「切换图片」。
  /// 取消选择与上传失败都不许吃掉已有背景图（四件套：失败保留已加载数据）。
  Future<void> _switchImage() async {
    setState(() {
      _uploading = true;
      _imageError = null;
    });
    try {
      final localPath = await widget.pickImage();
      if (!mounted) return;
      if (localPath == null) {
        setState(() => _uploading = false);
        return;
      }
      final slash = localPath.lastIndexOf('/');
      final url = await widget.uploadImage(
        localPath,
        slash < 0 ? localPath : localPath.substring(slash + 1),
      );
      if (!mounted) return;
      setState(() {
        _draft = _draft.copyWith(backgroundImage: url);
        _uploading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _imageError = '背景图上传失败：${describeError(error)}';
        _uploading = false;
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.targetDate,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(targetDate: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft.targetDate;
    return AlertDialog(
      title: Text(widget.isNew ? '新建倒数日' : '编辑倒数日'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('countdown-title-field'),
              controller: _title,
              decoration: const InputDecoration(labelText: '标题'),
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(title: value)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('目标日期: '),
                TextButton(
                  onPressed: _pickDate,
                  child: Text(countdownDateText(d)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('样式', style: Theme.of(context).textTheme.labelMedium),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _countdownStyles.entries)
                  ChoiceChip(
                    key: Key('countdown-style-${entry.key}'),
                    label: Text(entry.value),
                    selected: _draft.style == entry.key,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(style: entry.key),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('countdown-show-age'),
              contentPadding: EdgeInsets.zero,
              title: const Text('显示已过天数'),
              value: _draft.showAge,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(showAge: value)),
            ),
            const SizedBox(height: 8),
            Text('颜色', style: Theme.of(context).textTheme.labelMedium),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('countdown-color-default'),
                  label: const Text('默认'),
                  selected: parseCountdownColor(_draft.color) == null,
                  onSelected: (_) =>
                      setState(() => _draft = _draft.copyWith(color: '')),
                ),
                for (final hex in _countdownColorChoices)
                  ChoiceChip(
                    key: Key('countdown-color-$hex'),
                    avatar: CircleAvatar(
                      backgroundColor: parseCountdownColor(hex),
                      radius: 8,
                    ),
                    label: const SizedBox.shrink(),
                    selected: _draft.color?.toUpperCase() == hex,
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(color: hex)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              key: const Key('countdown-switch-image'),
              button: true,
              label: '切换背景图',
              child: TextButton.icon(
                onPressed: _uploading ? null : _switchImage,
                icon: const Icon(Icons.image_outlined),
                label: ExcludeSemantics(
                  child: Text(_uploading ? '上传中…' : '切换图片'),
                ),
              ),
            ),
            if (_imageError != null)
              Text(
                _imageError!,
                key: const Key('countdown-image-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_draft.backgroundImage != null)
              Image.network(
                _draft.backgroundImage!,
                key: const Key('countdown-image-preview'),
                height: 48,
                fit: BoxFit.cover,
                semanticLabel: '当前背景图',
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('countdown-note-field'),
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '为这个日子添加一段文字记录',
              ),
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(note: value)),
            ),
            SwitchListTile(
              key: const Key('countdown-note-show-in-detail'),
              contentPadding: EdgeInsets.zero,
              title: const Text('在详情页中显示'),
              value: _draft.noteShowInDetail,
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(noteShowInDetail: value),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('countdown-editor-save'),
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, _draft.copyWith(title: title));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.countdown});

  final CountdownDto countdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = countdown.daysRemaining.abs().toString();
    // 行高由标题撑开。只给宽度时，翻页牌和圆环会被拉成一条，天数也挤出圆外。
    Widget dayMark({required Color color, required BoxDecoration decoration}) {
      return SizedBox(
        key: ValueKey('countdown-badge-${countdown.id}'),
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: decoration,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(days, style: TextStyle(color: color)),
              ),
            ),
          ),
        ),
      );
    }

    return switch (countdown.style) {
      // 翻页：带中缝的日历牌，显示天数。
      2 => dayMark(
        color: scheme.onSecondaryContainer,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
      ),
      // 圆环：描边圆环内嵌天数。必须是正方形，否则 circle 画成椭圆。
      3 => dayMark(
        color: scheme.primary,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: 3),
        ),
      ),
      _ => CircleAvatar(
        key: ValueKey('countdown-badge-${countdown.id}'),
        backgroundColor: scheme.primary,
        child: Text(
          countdown.isCountUp ? '正' : '倒',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    };
  }
}
