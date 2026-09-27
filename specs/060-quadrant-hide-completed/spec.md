# 060 四象限「隐藏已完成」入口与开关 — 规格

- 仓库：`zh-cloud-todo-flutter`，分支 `feat/384-quadrant-hide-completed`，基线 `origin/develop@9032005`
- 关联：Gitea Issue #384 / 矩阵 #36 第 ⑩ 面
- 判据源：`zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/03-四象限/02-如何编辑四象限规则.md`
  读取：`git -C /Users/zhonghao/code/zh/zh-cloud/zh-cloud-docs -c core.quotePath=false show 'origin/develop:todo/99_参考资料/dida365-help-center/02-功能指南/03-四象限/02-如何编辑四象限规则.md' | sed -n '125,140p'`

## 一、源页怎么说这一面

| 行号 | 原文（逐字） | 取什么 |
| --- | --- | --- |
| `:131` | ` ::: spoiler 如何隐藏已完成任务？` | 小节标题 |
| `:132` | 在四象限页面，点击右上角「...」- 隐藏已完成。 | 入口在**四象限页面右上角「...」**，菜单项字面是**「隐藏已完成」** |

术语照抄：菜单项写「隐藏已完成」，不写"显示已完成""过滤已完成"。

## 二、develop 现状（基线 `9032005`，逐条现跑）

1. **已完成被无条件丢掉，共 3 处**（只改视图不够）：
   - `lib/features/task/views/eisenhower_view.dart` 本机分档 `if (t.completed) continue;`、
     远程分档 `if (task.completed) continue;`
   - `lib/features/task/tasks_by_list_page.dart` 的
     `TaskViewMode.eisenhower => visibleTasks.where((task) => !task.completed)`
   - 复算：`git grep -n "completed" origin/develop -- lib/features/task/views/eisenhower_view.dart lib/features/task/tasks_by_list_page.dart | grep -E "continue|!task.completed"`
2. **页面级「...」已经存在**，缺的是里面那一项：
   `lib/features/task/widgets/task_workspace_header.dart` 的 `PopupMenuButton<_TaskWorkspaceHeaderCommand>`
   （key `todo-sort-menu`）里已有「编辑象限规则」，但**无**「隐藏已完成」。
3. `classifyEisenhower` 把已完成任务归 Q4，且该函数上方的注释写着「已完成任务应在上层被过滤」
   ⇒ 一旦开关允许显示，Q4 里会混进已完成项，这是**分类器的既有约定**，不改它，只在进象限前决定是否放行。
4. 清单筛选侧有完成态维度（`lib/features/filter/filter_bar.dart` 的 `Text('已完成')`），
   它作用于传给视图的 `items` ⇒ 与视图内这层过滤是**两道闸**。

## 三、决定（含与交叉验证的分歧处理）

交叉验证（`cursor-agent`，日志 `/tmp/r112/crosscheck-384.out`，5487 字节，末行 `CROSSCHECK:`）
三条结论被采纳；它自报"shell 被拒、FL 读数取自工作树"，所以下面每条锚点我都按 `origin/develop` 复算过。

1. **入口形态**：给既有 `todo-sort-menu` 加一项「隐藏已完成」，默认**隐藏**。
   理由：源页 `:132` 写的是四象限页面的入口；日历那条"不再叠一层日历自身的开关"只钉死
   清单页里的 `CalendarView`，不构成全仓禁令。
2. **两道闸的冲突必须在 spec 里结清**（这是交叉验证指出的真风险，也是日历当年躲开的坑）：
   清单筛「已完成」+ 四象限仍隐藏 ⇒ 象限全空，用户看到的是"筛选坏了"。
   取**方案 A**：四象限的完成态显隐**只由这一个开关管**；当清单筛选里已经选了完成态维度时，
   菜单项**置灰并给说明**（读屏要念得出为什么不可点），不做"两个开关叠出来一个空板"。
   代价说清楚：这会在"清单已按完成态筛过"时禁用本面入口，属忠实形态与不打架之间的取舍，
   不是把功能砍掉——那条路径下用户仍能通过清单筛选看到已完成。
3. **默认隐藏**（`:132` 语义 + `calendar_view.dart` 里既有注释「嘀嗒默认隐藏已完成任务」）。
   ⇒ 本轮的**真实增量是"能显示已完成"**。若实现只挂菜单项、给不出显示态，就是换皮零增量，不该收工。
4. **持久化**：沿用 `todo_view_preferences`（`preferenceValue.addAll(preferencePatch)` 是合并写，
   新增键不需要后端契约），与 `saveCalendarDisplay` 同形；写失败要保留当前已加载数据并给可见反馈。

## 四、明确不做

- 不改 `classifyEisenhower` 的"已完成归 Q4"（现状约定，见 §二 3）。
- 不做"已完成任务的批量恢复/删除"（不属本面）。
- 不给清单筛选加新维度（那是矩阵 #22 那面）。

## 五、验收标准

- W1 默认态：已完成不出现在任何象限（与现状一致 ⇒ 这条防的是回归，不是新功能）。
- W2 打开显示：Q4 里出现已完成任务（分类器约定），且**同一批数据下未完成任务的象限归属不变**。
- W3 开关状态持久化：重进页面后仍是上次选择；读写走偏好，不新增后端契约。
- W4 清单已按完成态筛选时：菜单项置灰 + 可读说明，且**不出现空板**。
- W5 偏好读失败：保留已加载任务并给可见提示（不静默回到默认）。
- W6 四件套：320px + 1.3 倍字号在该菜单/该视图自己的 context 上不溢出；
  菜单项与置灰态有独立读屏语义；过期响应（切换清单后旧偏好回包）不覆盖新状态。
