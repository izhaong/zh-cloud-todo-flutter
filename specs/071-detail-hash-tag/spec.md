# 规格：任务详情里输入「#」创建标签（FL Issue #408，第 167 轮）

分支 `wip/408-detail-hash-tag`（基线 `zh-cloud-todo-flutter origin/develop`，取数基准现读）。
台账见同目录 `tasks.md`。

## 一、判据源与措辞

嘀嗒帮助中心《01-任务/09-如何管理海量任务/04-用标签管理任务.md》desktop tab（镜像第 61 行）：

> 方式二：创建任务时输入「#」**或在任务详情中输入「#」**快速创建标签。

镜像里 mobile tab（第 48 行）只讲「创建任务时」，那一半已由 FL PR !350（合并提交 `af62a8bfa2`）落地。
本单要补的是**详情半面**：术语照抄「快速创建标签」，交互沿用本端已有的「标题输入 + 保存」，不自创弹层或新按钮。

## 二、缺口判据（改前）与正向对照

| 面 | 判据 | 改前读数 |
| --- | --- | --- |
| 详情面接「#」 | `git grep -c -e parseHashTagInput -e hash_tag_input origin/develop -- lib/features/task/task_detail_pane.dart` | 0 命中 |
| 同一条命令的可达性对照（防判据恒假） | 路径换成 `lib/features/shell/quick_add_bar.dart` | 2 命中 |
| 详情面已有标签写路径（复用它，不新造第二次写语义） | `git grep -n setTaskTags origin/develop -- lib/features/task/task_detail_pane.dart` | `_TagChips` 那条命中 |

## 三、方案（最小改动）

1. `lib/features/task/task_detail_pane.dart` 的保存动作 `_save()` 里，先用 `parseHashTagInput(_title.text)` 得到
   `draft.title`（剥掉 `#名称` 后的正文）与 `draft.tagNames`；落库标题用 `draft.title`，
   于是井号原文不进 `todo_task.title`。词法与「已有同名就复用、没有才建」都**不在本文件重写**，
   复用 `lib/features/tag/hash_tag_input.dart` 里那两个函数（它们各自已有纯词法用例与真表用例）。
2. 标签是任务保存成功之后的**第二次写**：`resolveTagIdsByName` 拿到 id 后与
   `tagIdsOf(taskId)` 的现值取并集再 `setTaskTags`，所以「详情里打井号」不会把用户先前在标签选择器里勾掉的标签带回来，
   也不会把已有标签整批覆盖掉。
3. 失败面（对齐 #289 与 #292 的口径：失败必须可见、且不能带走已加载的数据）：
   第二次写抛错时保留**已保存的任务**，并在 `ScaffoldMessenger` 上给出
   「标签保存失败，任务已保存」。实测播放顺序是先「已保存」再这一条，
   `ScaffoldMessenger` 按队列逐条播放 ⇒ 用例必须把假时钟推过前一条的自动隐藏时长才看得见第二条，
   这一点写在用例注释里而不是靠多 settle 一次蒙过去。
4. 未新增界面/控件 ⇒ 四件套里的「320px + 1.3 倍字号」「独立读屏语义」两面在本单落在**既有**标题输入框上，
   由 `test/features/task/embedded_detail_header_narrow_test.dart` 与
   `test/features/task/task_detail_pane_test.dart` 承接（它们量的就是这块表面）；
   本单不重复声明那两面「新增」，只补「失败保留已加载数据」这一条用例。
   过期响应不覆盖新响应：本单没有引入新的异步回写路径，`_save()` 的既有 taskId 守卫原样保留。

## 四、验收面（用例逐条点名）

`test/features/task/detail_hash_tag_test.dart` 四条：

1. 详情标题里的「#周会」变成标签，标题不落井号原文 —— 量的是落库 `title` 等于「写周报」且该任务的标签名集合为「周会」。
2. 已有同名标签就复用它，不新建第二条 —— 量的是标签表总条数仍为 1。
3. 标题不含井号 ⇒ 不动标签表 —— 回归护栏：改前也是绿的，它守的是「没有井号时不碰标签写入」。
4. 标签写入失败 ⇒ 任务仍保存成功，失败提示在详情可见 —— 用一个 `create` 必抛的标签仓储覆盖 provider，
   先证「已保存」那条在播，再把时钟推过它的隐藏时长，然后断言失败文案上屏。

## 五、已知边界（本轮不改，写清楚）

- 详情里的井号只在**点保存**时生效；输入过程中不给「将新建标签：周会」这类预提示。
  嘀嗒源页只承诺「输入『#』快速创建标签」，未承诺输入态预览，故本单不加。
- 标签名带空格的写法（如 `#周 会`）按词法到空白为止，仍要走标签选择器里的新建，与快速添加一致。
- 矩阵 #21 那一行要等本 PR 合并后才翻状态；未合并前只写「已实现待合并 + PR 号」。
