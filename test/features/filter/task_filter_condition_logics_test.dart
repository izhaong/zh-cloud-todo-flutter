import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

/// FL Issue #524（矩阵 #22 面 ⑥）：跨筛选条件的「且 / 或」。
///
/// 判据源（嘀嗒《05-过滤器》:71 第一句，zh-cloud-docs `origin/develop`）：
/// 「你还可以使用“且”逻辑、“或”逻辑来关联前后两个筛选条件。」
///
/// 口径逐行跟服务端同字节（zh-cloud-service `origin/develop@7bd493dd1265`）：
/// - 条件顺序 = `TodoFilterConditionsDO.java:58-59` 的 `CONDITION_ORDER`
///   （`listIds, tagIds, priorities, statuses, dateRange, keyword`）；注释原话：
///   「『前/后』只能由这张表判定，服务端求值与客户端条件行必须同源，否则连接词会挂到另一条条件上」。
/// - 逻辑词挂在**每条条件**上（`isOrLogic`，`TodoFilterServiceImpl.java:322-325`）：值为 `or`
///   （忽略大小写）才算「或」；缺失 / `and` / 未知值都算「且」。
/// - 子句构造是析取范式（`:308-320`）：带 `or` 新开一个子句；带 `and` 把这条**追加进所有已有子句**。
///   语义 = 子句之间 OR、子句内部 AND。⇒「和后面那条 AND 上」会让它同时约束前面已经分出去的每个子句，
///   不是「只跟紧挨着的前一条」两两判断（第 5 条用例钉的就是这个差别）。
void main() {
  final stamp = DateTime(2026, 9, 1);

  TodoTask task(
    String id, {
    int priority = 0,
    bool completed = false,
    String? keyword,
    String listId = 'inbox',
    int? assigneeUserId,
  }) {
    return TodoTask(
      id: id,
      listId: listId,
      // keyword 命中的是标题或描述，这里统一用标题当载体，别让断言在两个字段之间猜。
      title: keyword ?? id,
      completed: completed,
      cancelled: false,
      priority: priority,
      isPinned: false,
      sortOrder: 0,
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      assigneeUserId: assigneeUserId,
      updatedAt: stamp,
      createdAt: stamp,
    );
  }

  // 四条种子：只满足优先级 3 / 只满足已完成 / 只满足标题含「周报」/ 三条都不满足。
  // 这样「全 AND」命中为空、而挂上「或」就有非空命中，缺省档与新模式各量一次。
  final tasks = [
    task('p3', priority: 3),
    task('done', completed: true),
    task('report', keyword: '周报'),
    task('plain'),
  ];
  final now = DateTime(2026, 9, 30, 10);

  List<String> hit(
    TaskFilter filter, {
    List<TodoTask>? seed,
    String? selectedListId,
  }) => applyTaskFilter(
    seed ?? tasks,
    filter,
    selectedListId,
    now,
    taskTagIds: const <String, Set<String>>{},
  ).map((t) => t.id).toList();

  test('没有跨条件逻辑词时逐条全 AND：这一档的字节必须和今天一模一样', () {
    expect(
      hit(const TaskFilter(priority: 3, keyword: '周报')),
      isEmpty,
      reason: '「优先级 3」且「标题含周报」：种子里没有任务同时满足两条',
    );
  });

  test('显式写 `and` 与不写键等价：服务端把缺失当 AND，客户端不许读出第二种形状', () {
    expect(
      hit(
        const TaskFilter(
          priority: 3,
          keyword: '周报',
          conditionLogics: {'keyword': 'and'},
        ),
      ),
      isEmpty,
    );
  });

  test('后一条挂「或」＝新开子句：得到两个子句的并', () {
    // CONDITION_ORDER 里 priorities 在 keyword 之前 ⇒ 挂给 keyword 的 or 说的是
    // 「keyword 相对前面累计结果」的关系，结果 = (priorities) OR (keyword)。
    expect(
      hit(
        const TaskFilter(
          priority: 3,
          keyword: '周报',
          conditionLogics: {'keyword': 'or'},
        ),
      ),
      ['p3', 'report'],
    );
  });

  test('第一条挂「或」没有意义：服务端 i==0 一律新开子句，客户端不自创解释', () {
    expect(
      hit(
        const TaskFilter(
          priority: 3,
          keyword: '周报',
          conditionLogics: {'priorities': 'or'},
        ),
      ),
      isEmpty,
      reason: '顺序上 priorities 排第一，它的连接词不参与判断 ⇒ 仍全 AND',
    );
  });

  test('「and」追加进所有已有子句，不是只跟紧挨着的前一条两两判断', () {
    // 种子换成三条各有归属 + 一条同时满足优先级与关键词的：
    //   clause0 = (priorities AND keyword)，clause1 = (statuses AND keyword)
    //   ⇒ 只有 both 命中。若实现成「只与相邻前一条比较」，会把 p3 / done 也放进来。
    final seed = [
      task('p3', priority: 3),
      task('done', completed: true),
      task('both', priority: 3, keyword: '周报'),
    ];
    expect(
      hit(
        const TaskFilter(
          priority: 3,
          completed: true,
          keyword: '周报',
          conditionLogics: {'statuses': 'or', 'keyword': 'and'},
        ),
        seed: seed,
      ),
      ['both'],
    );
  });

  test('逻辑词忽略大小写；未知值按「且」，不在求值层猜新词表', () {
    expect(
      hit(
        const TaskFilter(
          priority: 3,
          keyword: '周报',
          conditionLogics: {'keyword': 'OR'},
        ),
      ),
      ['p3', 'report'],
      reason: '服务端 isOrLogic 用 equalsIgnoreCase，客户端同口径',
    );
    expect(
      hit(
        const TaskFilter(
          priority: 3,
          keyword: '周报',
          conditionLogics: {'keyword': 'xor'},
        ),
      ),
      isEmpty,
      reason: '「xor」不是 or：既不当或，也不自创第三种口径',
    );
  });

  test('不在 CONDITION_ORDER 里的键是惰性的：负责人不参与跨条件逻辑', () {
    // 负责人在契约里存不下（savedFilterOf 把它列进 skipped），所以它既不是可命名的条件键，
    // 也不该被一份逻辑词翻成「或」。
    expect(
      hit(
        const TaskFilter(
          priority: 3,
          assigneeUserId: 7,
          conditionLogics: {'assigneeUserId': 'or'},
        ),
      ),
      isEmpty,
      reason: '负责人是硬 AND 闸门：它拦住了 p3（没有负责人），挂什么词都不放行',
    );
  });

  test('页面作用域（selectedListId）永远在跨条件逻辑之外', () {
    final elsewhere = [task('elsewhere', priority: 3, listId: 'someday')];
    expect(
      hit(
        const TaskFilter(keyword: '周报', conditionLogics: {'keyword': 'or'}),
        seed: elsewhere,
        selectedListId: 'inbox',
      ),
      isEmpty,
      reason: '「或」只在当前清单内成立，不能把别的清单的任务捞进来',
    );
  });
}
