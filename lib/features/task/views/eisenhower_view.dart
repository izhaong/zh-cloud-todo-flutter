import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/efficiency_api.dart';
import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../state/efficiency_providers.dart';
import '../../../state/providers.dart';
import '../../../state/session_state.dart';
import '../../../state/repositories/task_query_repository.dart';
import '../task_detail_page.dart';
import '../widgets/task_workspace_header.dart' show TaskSortX;

/// M11-B3 四象限 (Eisenhower) 视图。
///
/// 矩阵定义：
///   - X 轴（紧急）：dueAt 在 24h 内或已过期视为紧急
///   - Y 轴（重要）：priority >= 2 视为重要
///
/// 4 象限：
///   Q1 重要且紧急（do first）
///   Q2 重要不紧急（schedule）
///   Q3 紧急不重要（delegate）
///   Q4 不紧急不重要（eliminate）
///
/// 分类纯函数 [classifyEisenhower] 独立可测，无 UI 依赖。
class EisenhowerView extends ConsumerStatefulWidget {
  const EisenhowerView({
    super.key,
    required this.tasks,
    DateTime? now,
    this.showCompletedTasks = false,
    this.onTaskSelected,
    this.quadrantTaskSort = const {},
    this.onQuadrantSortChanged,
    this.quadrantOrder = const ['q1', 'q2', 'q3', 'q4'],
    this.onQuadrantOrderChanged,
  }) : _now = now;

  /// 用于分类的"当前时间"（测试可注入；缺省 `DateTime.now()`）。
  final DateTime? _now;

  /// 已应用 list/filter 的任务集合。
  final List<TodoTask> tasks;

  /// 每象限任务排序档（specs/127，矩阵 #36 面 ⑪）：key q1..q4，value
  /// `TaskSort.name`；缺档保持分桶输入顺序（现状锁）。
  final Map<String, String> quadrantTaskSort;

  /// 象限排序档变化回调；null ⇒ 象限头「…」不给「排序」入口。
  final void Function(String quadrant, TaskSort sort)? onQuadrantSortChanged;

  /// 四象限显示顺序（specs/128，矩阵 #36 面 ⑦）：q1..q4 的排列，缺省
  /// Q1/Q2/Q3/Q4（现状锁）。
  final List<String> quadrantOrder;

  /// 象限顺序变化回调；null ⇒ 拖动/上移下移入口不渲染。
  final void Function(List<String> order)? onQuadrantOrderChanged;

  /// 已完成任务要不要进象限格子。缺省 `false` 就是 develop 现状的行为
  /// （嘀嗒《02-功能指南/03-四象限/02-如何编辑四象限规则.md》`:132`「隐藏已完成」默认隐藏）。
  final bool showCompletedTasks;
  final ValueChanged<String>? onTaskSelected;

  @override
  ConsumerState<EisenhowerView> createState() => _EisenhowerViewState();
}

class _EisenhowerViewState extends ConsumerState<EisenhowerView> {
  /// 同一任务的拖动写操作按起拖顺序排队。
  ///
  /// 不排队会出现"先拖的那次请求后落地"，把后一次的结果盖掉
  /// （四件套里的「过期响应不覆盖新响应」）。
  final Map<String, Future<void>> _writeChain = {};

  DateTime get _effectiveNow => widget._now ?? DateTime.now();

  void _queueDrop(QuadrantDragMove move, QuadrantDropPatch patch) {
    final repository = ref.read(taskViewActionRepositoryProvider);
    if (repository == null) return;
    final previous = _writeChain[move.task.id] ?? Future<void>.value();
    _writeChain[move.task.id] = previous.then((_) async {
      try {
        await repository.moveQuadrantTask(
          move.task.id,
          priority: patch.priority,
          dueAt: patch.dueAt,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('四象限：任务换象限保存失败，未改动')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = _effectiveNow;
    final localQuadrants = _buildQuadrants(
      widget.tasks,
      now,
      showCompletedTasks: widget.showCompletedTasks,
    );
    final session = ref.watch(sessionProvider);
    final rules = session == null
        ? const <QuadrantRuleDto>[]
        : ref.watch(quadrantRulesProvider).valueOrNull ?? const [];
    final activeRule = _activeRule(rules);
    final remoteBoard = activeRule == null
        ? null
        : ref.watch(quadrantBoardProvider(activeRule.id)).valueOrNull;
    final quadrants = activeRule == null || remoteBoard == null
        ? localQuadrants
        : _buildRemoteQuadrants(
            widget.tasks,
            now,
            activeRule,
            remoteBoard,
            showCompletedTasks: widget.showCompletedTasks,
          );
    // 每象限任务排序（specs/127，矩阵 #36 面 ⑪）：嘀嗒 :135-:136「选择需要
    // 更改的象限，点击右上角『…』-『排序』，可选择排序方式」。缺档保持
    // 分桶输入顺序（现状锁）；比较器复用列表视图同一把尺。
    List<TodoTask> sortBucket(List<TodoTask> bucket, Quadrant quadrant) {
      final wire = widget.quadrantTaskSort[quadrant.name];
      if (wire == null) return bucket;
      final sort = TaskSort.values
          .where((candidate) => candidate.name == wire)
          .firstOrNull;
      if (sort == null) return bucket;
      final sorted = [...bucket]..sort((a, b) => compareTodoTasks(a, b, sort));
      return sorted;
    }

    for (final quadrant in Quadrant.values) {
      final data = quadrants[quadrant]!;
      quadrants[quadrant] = _QuadrantData(
        quadrant: data.quadrant,
        label: data.label,
        hint: data.hint,
        tasks: sortBucket(data.tasks, quadrant),
      );
    }

    // 回写式只由**生效规则**决定（`:25` 与 `:44` 讲的是规则，不是"看板数据到没到"）：
    // 组合1 的规则即使在看板未加载的降级态下也不该动 dueAt。
    // 自定义规则源页本节没给拖动脉络（specs/059 §三 4），该档一律不给拖。
    final effectiveRuleType = activeRule?.type;
    final canDrag =
        quadrantDropPatch(
          target: Quadrant.q1,
          ruleType: effectiveRuleType,
          now: now,
        ) !=
        null;
    final brightness = Theme.of(context).brightness;

    Widget tile(Quadrant quadrant, _QuadrantPalette palette) {
      final orderedIndex = widget.quadrantOrder.indexOf(quadrant.name);
      return _QuadrantTile(
        data: quadrants[quadrant]!,
        color: palette.background,
        accent: palette.foreground,
        onTaskTap: (t) => _openDetail(context, t),
        draggable: canDrag,
        now: now,
        ruleType: effectiveRuleType,
        onDrop: _queueDrop,
        currentSort: widget.quadrantTaskSort[quadrant.name] == null
            ? null
            : TaskSort.values
                  .where(
                    (candidate) =>
                        candidate.name ==
                        widget.quadrantTaskSort[quadrant.name],
                  )
                  .firstOrNull,
        onSortChanged: widget.onQuadrantSortChanged == null
            ? null
            : (sort) => widget.onQuadrantSortChanged!(quadrant.name, sort),
        onOrderSwap: widget.onQuadrantOrderChanged == null || orderedIndex < 0
            ? null
            : (incoming) {
                final order = [...widget.quadrantOrder];
                final from = order.indexOf(incoming.name);
                order[from] = quadrant.name;
                order[orderedIndex] = incoming.name;
                widget.onQuadrantOrderChanged!(order);
              },
        onOrderMove: widget.onQuadrantOrderChanged == null || orderedIndex < 0
            ? null
            : (delta) {
                final order = [...widget.quadrantOrder];
                final target = orderedIndex + delta;
                if (target < 0 || target >= order.length) return;
                order[orderedIndex] = order[target];
                order[target] = quadrant.name;
                widget.onQuadrantOrderChanged!(order);
              },
        orderedPosition: orderedIndex,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (activeRule != null && remoteBoard != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '服务端规则：${activeRule.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final name in widget.quadrantOrder.take(2))
                  Expanded(
                    child: tile(
                      Quadrant.values.firstWhere((q) => q.name == name),
                      _quadrantPalette(
                        Quadrant.values.firstWhere((q) => q.name == name),
                        brightness,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final name in widget.quadrantOrder.skip(2))
                  Expanded(
                    child: tile(
                      Quadrant.values.firstWhere((q) => q.name == name),
                      _quadrantPalette(
                        Quadrant.values.firstWhere((q) => q.name == name),
                        brightness,
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

  void _openDetail(BuildContext context, TodoTask t) {
    final callback = widget.onTaskSelected;
    if (callback != null) {
      callback(t.id);
      return;
    }
    showTaskDetailSheet(context, t.id);
  }

  /// 把任务分到 4 个象限；返回按 Q1/Q2/Q3/Q4 key 的 map。
  static Map<Quadrant, _QuadrantData> _buildQuadrants(
    List<TodoTask> tasks,
    DateTime now, {
    required bool showCompletedTasks,
  }) {
    final map = <Quadrant, List<TodoTask>>{
      Quadrant.q1: [],
      Quadrant.q2: [],
      Quadrant.q3: [],
      Quadrant.q4: [],
    };
    for (final t in tasks) {
      if (t.completed && !showCompletedTasks) continue;
      map[classifyEisenhower(t, now)]!.add(t);
    }
    return {
      for (final q in Quadrant.values)
        q: _QuadrantData(
          quadrant: q,
          label: q.label,
          hint: q.hint,
          tasks: map[q]!,
        ),
    };
  }

  static QuadrantRuleDto? _activeRule(List<QuadrantRuleDto> rules) {
    if (rules.isEmpty) return null;
    for (final rule in rules) {
      if (rule.isDefault) return rule;
    }
    return rules.first;
  }

  static Map<Quadrant, _QuadrantData> _buildRemoteQuadrants(
    List<TodoTask> tasks,
    DateTime now,
    QuadrantRuleDto rule,
    Map<String, Set<int>> board, {
    required bool showCompletedTasks,
  }) {
    final keys = _ruleKeys(rule);
    final keyToQuadrant = <String, Quadrant>{};
    for (final entry in keys.take(4).indexed) {
      keyToQuadrant[entry.$2] = Quadrant.values[entry.$1];
    }
    if (keys.length > 4) {
      for (final key in keys.skip(4)) {
        keyToQuadrant[key] = Quadrant.q4;
      }
    }
    keyToQuadrant['UNCLASSIFIED'] = Quadrant.q4;
    final serverKeyByTaskId = <int, String>{
      for (final entry in board.entries)
        for (final taskId in entry.value) taskId: entry.key,
    };
    final grouped = <Quadrant, List<TodoTask>>{
      for (final quadrant in Quadrant.values) quadrant: [],
    };
    for (final task in tasks) {
      if (task.completed && !showCompletedTasks) continue;
      final serverKey = task.serverId == null
          ? null
          : serverKeyByTaskId[task.serverId];
      final quadrant =
          keyToQuadrant[serverKey] ?? classifyEisenhower(task, now);
      grouped[quadrant]!.add(task);
    }

    final customDefinitions = {
      for (final definition in rule.definitions)
        definition.key: definition.condition,
    };
    return {
      for (final quadrant in Quadrant.values)
        quadrant: _QuadrantData(
          quadrant: quadrant,
          label: _remoteLabel(rule, quadrant, keys),
          hint: _remoteHint(rule, quadrant, keys, customDefinitions),
          tasks: grouped[quadrant]!,
        ),
    };
  }

  static List<String> _ruleKeys(QuadrantRuleDto rule) {
    switch (rule.type) {
      case QuadrantRuleType.priorityTime:
        return const [
          'Q1_URGENT_IMPORTANT',
          'Q2_NOT_URGENT_IMPORTANT',
          'Q3_URGENT_NOT_IMPORTANT',
          'Q4_NOT_URGENT_NOT_IMPORTANT',
        ];
      case QuadrantRuleType.priorityOnly:
        return const ['P3', 'P2', 'P1', 'P0'];
      case QuadrantRuleType.custom:
        final keys = rule.definitions
            .map((definition) => definition.key)
            .take(4)
            .toList();
        while (keys.length < 3) {
          keys.add('__EMPTY_${keys.length}');
        }
        if (keys.length < 4) keys.add('UNCLASSIFIED');
        return keys;
    }
  }

  static String _remoteLabel(
    QuadrantRuleDto rule,
    Quadrant quadrant,
    List<String> keys,
  ) {
    if (rule.type == QuadrantRuleType.priorityTime) return quadrant.label;
    final index = quadrant.index;
    if (index >= keys.length) return quadrant.label;
    final key = keys[index];
    if (rule.type == QuadrantRuleType.priorityOnly) {
      return '$key · 优先级 ${key.substring(1)}';
    }
    if (key.startsWith('__EMPTY_')) return '自定义象限 ${index + 1}';
    return key == 'UNCLASSIFIED' ? '未分类' : key;
  }

  static String _remoteHint(
    QuadrantRuleDto rule,
    Quadrant quadrant,
    List<String> keys,
    Map<String, String> customDefinitions,
  ) {
    if (rule.type != QuadrantRuleType.custom) return quadrant.hint;
    final index = quadrant.index;
    if (index >= keys.length) return quadrant.hint;
    final key = keys[index];
    if (key.startsWith('__EMPTY_')) return '尚未配置条件';
    return customDefinitions[key] ?? '未匹配自定义条件';
  }
}

/// 四象限分类。
enum Quadrant {
  q1, // 重要 + 紧急
  q2, // 重要 + 不紧急
  q3, // 不重要 + 紧急
  q4, // 不重要 + 不紧急
}

extension QuadrantX on Quadrant {
  String get label {
    switch (this) {
      case Quadrant.q1:
        return 'Q1 · 重要且紧急';
      case Quadrant.q2:
        return 'Q2 · 重要不紧急';
      case Quadrant.q3:
        return 'Q3 · 紧急不重要';
      case Quadrant.q4:
        return 'Q4 · 不紧急不重要';
    }
  }

  String get hint {
    switch (this) {
      case Quadrant.q1:
        return '立即处理';
      case Quadrant.q2:
        return '计划安排';
      case Quadrant.q3:
        return '考虑委托';
      case Quadrant.q4:
        return '可考虑放弃';
    }
  }
}

class _QuadrantPalette {
  const _QuadrantPalette({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

_QuadrantPalette _quadrantPalette(Quadrant quadrant, Brightness brightness) {
  if (brightness == Brightness.dark) {
    return switch (quadrant) {
      Quadrant.q1 => const _QuadrantPalette(
        background: Color(0xFF3A171B),
        foreground: Color(0xFFFFB4AB),
      ),
      Quadrant.q2 => const _QuadrantPalette(
        background: Color(0xFF332600),
        foreground: Color(0xFFFFD166),
      ),
      Quadrant.q3 => const _QuadrantPalette(
        background: Color(0xFF132A3A),
        foreground: Color(0xFFA8D1FF),
      ),
      Quadrant.q4 => const _QuadrantPalette(
        background: Color(0xFF24272B),
        foreground: Color(0xFFD1D5DB),
      ),
    };
  }
  return switch (quadrant) {
    Quadrant.q1 => const _QuadrantPalette(
      background: Color(0xFFFFEBEA),
      foreground: Color(0xFF8A1C18),
    ),
    Quadrant.q2 => const _QuadrantPalette(
      background: Color(0xFFFFF4D6),
      foreground: Color(0xFF6C4E00),
    ),
    Quadrant.q3 => const _QuadrantPalette(
      background: Color(0xFFEAF3FF),
      foreground: Color(0xFF174A7E),
    ),
    Quadrant.q4 => const _QuadrantPalette(
      background: Color(0xFFF0F1F2),
      foreground: Color(0xFF404347),
    ),
  };
}

/// 把单个任务分类到 4 象限之一。
///
/// 重要（important）：priority >= 2
/// 紧急（urgent）：dueAt 在 24h 内或已过期
///
/// 四象限这一面到底显不显示已完成。
///
/// 清单筛选已经钉过完成态（`listFilterCompleted != null`）时**以筛选为准**，
/// 四象限不再叠第二道闸：叠上去就是"筛了已完成、板子却全空"，用户只会认为筛选坏了。
bool quadrantShowsCompleted({
  required bool hideCompleted,
  bool? listFilterCompleted,
}) => listFilterCompleted != null || !hideCompleted;

/// 已完成任务应在上层被过滤；本函数对 completed 任务会归到 Q4（不紧急不重要），
/// 调用方选择是否排除。
Quadrant classifyEisenhower(TodoTask task, DateTime now) {
  if (task.completed) return Quadrant.q4;
  final important = task.priority >= 2;
  final due = task.dueAt;
  bool urgent;
  if (due == null) {
    urgent = false;
  } else {
    // 已过期或在 24h 内视为紧急
    final cutoff = now.add(const Duration(hours: 24));
    urgent = !due.isAfter(cutoff);
  }
  if (important && urgent) return Quadrant.q1;
  if (important && !urgent) return Quadrant.q2;
  if (!important && urgent) return Quadrant.q3;
  return Quadrant.q4;
}

class _QuadrantData {
  const _QuadrantData({
    required this.quadrant,
    required this.label,
    required this.hint,
    required this.tasks,
  });
  final Quadrant quadrant;
  final String label;
  final String hint;
  final List<TodoTask> tasks;
}

class _QuadrantTile extends StatelessWidget {
  const _QuadrantTile({
    required this.data,
    required this.color,
    required this.accent,
    required this.onTaskTap,
    required this.draggable,
    required this.now,
    required this.ruleType,
    required this.onDrop,
    this.currentSort,
    this.onSortChanged,
    this.onOrderSwap,
    this.onOrderMove,
    this.orderedPosition,
  });

  final _QuadrantData data;
  final Color color;
  final Color accent;
  final ValueChanged<TodoTask> onTaskTap;
  final bool draggable;
  final DateTime now;
  final QuadrantRuleType? ruleType;
  final void Function(QuadrantDragMove move, QuadrantDropPatch patch) onDrop;

  /// 当前象限的排序档（null = 未选过，按输入顺序）；非 null 才渲染「排序」入口。
  final TaskSort? currentSort;
  final ValueChanged<TaskSort>? onSortChanged;

  /// 象限换位（specs/128，矩阵 #36 面 ⑦ desktop 半面）：把 [incoming] 象限
  /// 拖到本象限时两格交换显示位置。null ⇒ 不给拖动/接受入口。
  final ValueChanged<Quadrant>? onOrderSwap;

  /// mobile 半面：「…」-「编辑顺序」的上移/下移（delta -1/+1，阅读顺序换位）。
  final void Function(int delta)? onOrderMove;

  /// 本象限在当前排列里的位置（q1..q4 的索引）；上移/下移边界用。
  final int? orderedPosition;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    Widget tile = Material(
      key: ValueKey('quadrant-${data.quadrant.name}'),
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: onOrderSwap == null
                      ? Text(
                          data.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      // 象限头拖动（specs/128 desktop 半面）：载荷是象限本身，
                      // 与卡片上的「拖任务换象限」（LongPressDraggable<
                      // QuadrantDragMove>）不同型不抢手势。
                      : Draggable<Quadrant>(
                          data: data.quadrant,
                          feedback: Material(
                            color: color.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                data.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.4,
                            child: Text(
                              data.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          child: Text(
                            data.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${data.tasks.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onSortChanged != null || onOrderMove != null)
                  PopupMenuButton<Object>(
                    key: ValueKey('quadrant-sort-${data.quadrant.name}'),
                    tooltip: '排序',
                    icon: Icon(Icons.more_horiz, size: 16, color: accent),
                    onSelected: (value) {
                      if (value is int) {
                        onOrderMove?.call(value);
                        return;
                      }
                      if (value is TaskSort) onSortChanged?.call(value);
                    },
                    itemBuilder: (context) => [
                      if (onOrderMove != null && orderedPosition != null) ...[
                        PopupMenuItem(
                          key: ValueKey(
                            'quadrant-order-up-${data.quadrant.name}',
                          ),
                          value: -1,
                          enabled: orderedPosition! > 0,
                          child: const Text('上移'),
                        ),
                        PopupMenuItem(
                          key: ValueKey(
                            'quadrant-order-down-${data.quadrant.name}',
                          ),
                          value: 1,
                          enabled: orderedPosition! < 3,
                          child: const Text('下移'),
                        ),
                        const PopupMenuDivider(),
                      ],
                      for (final candidate in TaskSort.values)
                        PopupMenuItem(
                          key: ValueKey(
                            'quadrant-sort-${data.quadrant.name}-${candidate.name}',
                          ),
                          value: candidate,
                          child: Row(
                            children: [
                              Expanded(child: Text(candidate.label)),
                              if (candidate == currentSort)
                                Icon(
                                  Icons.check,
                                  size: 14,
                                  color: accent,
                                  semanticLabel: '当前排序',
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            Text(
              data.hint,
              style: TextStyle(
                fontSize: 11,
                color: accent.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: data.tasks.isEmpty
                  ? Center(
                      child: Text(
                        '空',
                        style: TextStyle(color: accent.withValues(alpha: 0.6)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: data.tasks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = data.tasks[i];
                        final card = ListTile(
                          dense: true,
                          title: Text(
                            t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.foreground,
                            ),
                          ),
                          onTap: () => onTaskTap(t),
                        );
                        if (!draggable) return card;
                        return Semantics(
                          label: '拖动调整象限',
                          child: LongPressDraggable<QuadrantDragMove>(
                            data: QuadrantDragMove(
                              task: t,
                              from: data.quadrant,
                            ),
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: Material(
                              elevation: 3,
                              color: color,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: card,
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.4,
                              child: card,
                            ),
                            child: card,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    if (!draggable) return orderSwapWrap(tile);
    return orderSwapWrap(
      DragTarget<QuadrantDragMove>(
        onWillAcceptWithDetails: (details) =>
            details.data.from != data.quadrant &&
            quadrantDropPatch(
                  target: data.quadrant,
                  ruleType: ruleType,
                  now: now,
                ) !=
                null,
        onAcceptWithDetails: (details) {
          final patch = quadrantDropPatch(
            target: data.quadrant,
            ruleType: ruleType,
            now: now,
          );
          if (patch == null || details.data.from == data.quadrant) return;
          onDrop(details.data, patch);
        },
        builder: (context, candidate, rejected) => tile,
      ),
    );
  }

  /// 象限换位外层（specs/128）：`DragTarget<Quadrant>` 接受另一象限头拖入
  /// ⇒ 交换两格显示位置。与任务拖换（内层 `QuadrantDragMove`）载荷不同型，
  /// 不抢手势。
  Widget orderSwapWrap(Widget child) {
    final swap = onOrderSwap;
    if (swap == null) return child;
    return DragTarget<Quadrant>(
      onWillAcceptWithDetails: (details) => details.data != data.quadrant,
      onAcceptWithDetails: (details) => swap(details.data),
      builder: (context, _, _) => child,
    );
  }
}

/// 拖起来的卡片要连着"从哪个象限起拖"一起带：
/// 任务对象自己不知道自己落在哪个象限，不带 `from` 就没法判「拖回原象限不该发写请求」。
class QuadrantDragMove {
  const QuadrantDragMove({required this.task, required this.from});

  final TodoTask task;
  final Quadrant from;
}

/// 拖到某个象限要回写的两栏。`dueAt == null` = 这一档不改截止时间（组合1）。
typedef QuadrantDropPatch = ({int priority, DateTime? dueAt});

/// 拖动落档式：嘀嗒《02-如何编辑四象限规则》
/// `:25`（组合1 只改优先级）/`:44`（组合2 优先级与时间一起改），
/// 取值抄 `:39`「“今天”、“高优先级”」与 `:40`「“1个月后”、“低优先级”」这两条例子。
/// `ruleType == null` 是本机分档（`classifyEisenhower` 本身就是优先级 + 时间两轴）；
/// `custom` 返回 null：源页本节没给自定义规则下的拖动脉络。
QuadrantDropPatch? quadrantDropPatch({
  required Quadrant target,
  required QuadrantRuleType? ruleType,
  required DateTime now,
}) {
  if (ruleType == QuadrantRuleType.custom) return null;
  if (ruleType == QuadrantRuleType.priorityOnly) {
    // 组合1 的目标优先级直接取规则自己的键序（_ruleKeys 里就是 P3/P2/P1/P0）。
    return (priority: 3 - target.index, dueAt: null);
  }
  final important = target == Quadrant.q1 || target == Quadrant.q2;
  final urgent = target == Quadrant.q1 || target == Quadrant.q3;
  // 高优先级=3、低优先级=1（词表见 quick_add_bar 的下拉）；
  // 紧急档写"当天 23:59"，恒在 classifyEisenhower 的 24 小时窗口内。
  return (
    priority: important ? 3 : 1,
    dueAt: urgent
        ? DateTime(now.year, now.month, now.day, 23, 59)
        : _oneMonthLater(now),
  );
}

/// 「1 个月后」。Dart 的 `DateTime(y, m+1, 31)` 会按日进位（2026-01-31 ⇒ 2026-03-03），
/// 也就是月末会溢出到下个月初——这是"约一个月后"，不是精确到日的一个月。
/// 保留这道兜底是因为极端日期下必须仍在 24 小时窗口之外，否则不紧急档会被判回紧急。
DateTime _oneMonthLater(DateTime now) {
  final candidate = DateTime(
    now.year,
    now.month + 1,
    now.day,
    now.hour,
    now.minute,
  );
  return candidate.isAfter(now.add(const Duration(days: 2)))
      ? candidate
      : now.add(const Duration(days: 31));
}
