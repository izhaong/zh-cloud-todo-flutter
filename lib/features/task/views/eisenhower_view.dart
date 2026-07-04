import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../task_detail_page.dart';

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
class EisenhowerView extends ConsumerWidget {
  const EisenhowerView({
    super.key,
    required this.tasks,
    DateTime? now,
  }) : _now = now;

  /// 用于分类的"当前时间"（测试可注入；缺省 `DateTime.now()`）。
  final DateTime? _now;

  /// 已应用 list/filter 的任务集合。
  final List<TodoTask> tasks;

  DateTime get _effectiveNow => _now ?? DateTime.now();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = _effectiveNow;
    final quadrants = _buildQuadrants(tasks, now);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _QuadrantTile(
                    data: quadrants[Quadrant.q1]!,
                    color: Colors.red.shade100,
                    accent: Colors.red,
                    onTaskTap: (t) => _openDetail(context, t),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadrantTile(
                    data: quadrants[Quadrant.q2]!,
                    color: Colors.amber.shade100,
                    accent: Colors.amber.shade800,
                    onTaskTap: (t) => _openDetail(context, t),
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
                Expanded(
                  child: _QuadrantTile(
                    data: quadrants[Quadrant.q3]!,
                    color: Colors.blue.shade100,
                    accent: Colors.blue,
                    onTaskTap: (t) => _openDetail(context, t),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadrantTile(
                    data: quadrants[Quadrant.q4]!,
                    color: Colors.grey.shade300,
                    accent: Colors.grey,
                    onTaskTap: (t) => _openDetail(context, t),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _openDetail(BuildContext context, TodoTask t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.id)),
    );
  }

  /// 把任务分到 4 个象限；返回按 Q1/Q2/Q3/Q4 key 的 map。
  static Map<Quadrant, _QuadrantData> _buildQuadrants(
    List<TodoTask> tasks,
    DateTime now,
  ) {
    final map = <Quadrant, List<TodoTask>>{
      Quadrant.q1: [],
      Quadrant.q2: [],
      Quadrant.q3: [],
      Quadrant.q4: [],
    };
    for (final t in tasks) {
      if (t.completed) continue;
      map[classifyEisenhower(t, now)]!.add(t);
    }
    return {
      for (final q in Quadrant.values)
        q: _QuadrantData(quadrant: q, tasks: map[q]!),
    };
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

/// 把单个任务分类到 4 象限之一。
///
/// 重要（important）：priority >= 2
/// 紧急（urgent）：dueAt 在 24h 内或已过期
///
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
  const _QuadrantData({required this.quadrant, required this.tasks});
  final Quadrant quadrant;
  final List<TodoTask> tasks;
}

class _QuadrantTile extends StatelessWidget {
  const _QuadrantTile({
    required this.data,
    required this.color,
    required this.accent,
    required this.onTaskTap,
  });

  final _QuadrantData data;
  final Color color;
  final Color accent;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.quadrant.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${data.tasks.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            Text(
              data.quadrant.hint,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: data.tasks.isEmpty
                  ? Center(
                      child: Text(
                        '空',
                        style: TextStyle(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: data.tasks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = data.tasks[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onTaskTap(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
