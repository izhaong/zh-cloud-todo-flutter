# Spec: 「指派给我」智能清单 + 智能清单术语对齐

- Issue: zh-cloud-todo-flutter #338（矩阵 #19 面 ⑤，另收本行的「术语不一致记一档」）
- 判据源：嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md》
  - `:16`「我们准备了五个最高效的智能清单：「今天」、「明天」、「最近七天」、「收集箱」、「指派给我」。」
  - `:21`「「指派给我」是收集来自不同共享清单中分配给你的任务，你可以在这个清单中查看你在不同共享清单中的任务。」

## 现状（origin/develop@429d7045ba6e）

- `SmartList` 枚举七项（inbox/today/tomorrow/upcoming/all/completed/trash），没有 assignee 类；侧栏与 `TaskStats` 都没有这一行。
- 数据面已具备：`todo_tasks.assignee_user_id`（Drift `assigneeUserId`，由 `PUT /task/{id}/assignee` 协作指派写入）、`TaskFilter.assigneeUserId` 与内存求值都已实现；当前用户 id 走 `sessionProvider?.userId`。
- 术语：本端 `upcoming` 标「未来7天」，嘀嗒 `:16` 写「最近七天」⇒ 按北极星要求照抄嘀嗒术语（矩阵 #19 已把这条记在 #338 名下）。

## FR

- FR-1 `SmartList` 新增 `assignToMe`，label「指派给我」，位置紧跟收集箱（嘀嗒 `:20`→`:21` 的相邻次序）。
- FR-2 侧栏出现该行（key `todo-sidebar-row-assignToMe`，与既有行同一套「`todo-sidebar-row-<枚举名>`」命名），徽章 = 当前用户名下未完成任务数；无会话时徽章为 0。
- FR-3 「有内容时显示」三态适用于该行（内容计数已由 FR-2 具备），与 specs/103 的口径一致。
- FR-4 选中该行时任务面板只显示 `assigneeUserId == 当前用户` 的任务（复用 `TaskFilter.assigneeUserId`，不新增查询通道），面板标题走枚举 label ⇒ 「指派给我」。
- FR-5 术语：`upcoming` 的 label 改为「最近七天」，并同步 `test/shell_responsive_test.dart`、`test/features/shell/sidebar_test.dart` 里钉死旧文案的断言。
- FR-6 视图偏好键：该行要独占 `smart:assign`，不许与「全部」共用 `smart:all`（否则排序偏好互相顶掉）。

## 取舍

1. **本端口径 = `assigneeUserId == 当前用户` 的未完成任务，不叠加"所在清单是共享清单"**（与嘀嗒 `:21` 有已知偏差，已登记后续单）：
   - 客户端本地**没有成员表**（`app_database.dart` 的表清单里没有 list members），成员只由 `listMembersProvider` 现取服务端，离线不可判；
   - 唯一可用的本地线索是 `TodoLists.accessRole`（pull 会填，`sync_coordinator.dart`），但 `accessRole != 'owner'` 会**漏掉**"我建的、拉了协作者的清单里指派给我的任务"——那是嘀嗒原文点名的场景，比多收"我在自己清单里指派给自己"这类任务更错；
   - 所以先按超集实现，偏差写在这里与矩阵追记里，收紧需要成员面落到本地（FL Issue #559）。
2. **未登录时 `lockedAssigneeUserId` 传 null ⇒ 不加约束**：无会话时 `appDatabaseProvider` 返回 null，页面没有行可筛，不存在"看到全部任务"的可达路径（cursor 交叉验证同此判）。
3. **页面身份不放进用户可清的滤镜**（这是交叉验证推翻掉的初版设计）：嘀嗒里标题写着「指派给我」时列表必须仍是分配给你的任务。因此走 `lockedAssigneeUserId` 硬闸门，与 `selectedListId` 同层（`applyTaskFilter` 里"硬闸门"那段就是给页面作用域用的，跨条件逻辑词碰不到它）；筛选器点「全部」只清用户叠加的日期/标签/优先级条件。

## 测试

- `TaskStats.fromTasks` 计数：本人未完成计入、他人/已完成/未指派不计入、无 assignee 参数时为 0。
- 侧栏：行存在 + 徽章数字；三态（隐藏 / 有内容时显示）跟着走。
- 面板：`assignToMe` 只渲染本人任务（含一条他人指派任务作反向对照）。
- 术语：枚举文案表含「指派给我」「最近七天」。
- 视图偏好键：`smart:assign` 独立。
- 连带修：侧栏多一行把清单行挤出懒渲染窗口 ⇒ specs/102 的 `test/features/shell/sidebar_list_color_test.dart` 两处 `tester.widget` 抛 "Bad state: No element"，改成先 `scrollUntilVisible` 再断言（不自己造"可见"阈值）。
- 变异探针 + 全量门禁（analyze + 全量 test，跑在 commit 之后）+ golden 基线按实际画面重录并单独提交（差异图确认只落在侧栏一列，主区逐像素不动）。
