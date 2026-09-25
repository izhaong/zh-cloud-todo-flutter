# 执行计划：specs/054 清单拖拽排序要能同步出去

对应 `spec.md`（同目录）。范围极窄：一处仓储缺陷 + 它的用例与探针，**不动 UI**。

## 步骤 → 验证

| # | 步骤 | 怎么验它做过了 |
| --- | --- | --- |
| 1 | 读嘀嗒《02-用清单管理任务》`:78`，确认本面只吃"排序可同步"，把「置顶」推到服务端契约 | `spec.md` 一、五、FR-5 引的原文与行号；`git show origin/develop:<路径> \| sed -n '78p'` |
| 2 | 取证 develop：`reorder` 不登记 outbox、五个写方法都登记、无事务 | `spec.md` 二的四条 grep，逐条可复算 |
| 3 | 红测：新增 `test/state/list_repository_reorder_sync_test.dart` 5 条 | 读数 `+1 -4`（4 条行为红，非编译红；空列表那条本就该通过） |
| 4 | 最小实现：`reorder` 内 ①每条登记 `list/upsert`（payload 读回行）②整批 `_db.transaction` ③跳缺失 id、位次不留空洞 | 同一套用例转绿 `+5`；`dart format` 显式两文件 0 changed |
| 5 | 反向探针 Y1–Y4（摘登记 / 摘事务 / 位次改用传入下标 / payload 改用拼装） | `/tmp/r80/probes-all.log`：每条对照组先绿、`cmp -s` 还原一致。⚠️ 这份日志末段其实是
        `PRESENT reorder 内确有 enqueue（localId: id） 命中 3 期望 1 不对 !!` + `结论：异常计数 = 1`
        （判据放宽那一版），"成对 grep 命中数对"只能引**改窄之后**的 `/tmp/r80/grep-scoped.log` |
| 6 | 六道门禁（含 `flutter test --tags golden` 必须仍是 9 张且 `基线目录脏项数=0`——本面无 UI 变更这条才有意义） | `/tmp/r80/gates-final.log` 七行 rc 全 0（`/tmp/r80/gates.log` 那份门 3 是 `rc=1`、
        `5 issues found`（含新测试文件 unused import），已由 `186527f` 修掉 ⇒ 原引对象错，复核 A 项）；
        读数写进 `tasks.md` 表格 |
| 7 | 只读复核 | 必须拿到 `VERDICT`；FAIL 逐条回源复验 |
| 8 | 回写 `tasks.md` 与矩阵 #19 缺口列（**未合并不翻状态**） | `check_parity_matrix.py` 判定不变（主表 89 行） |

## 明确不做（写清楚，不是拖延）

- **置顶**（嘀嗒 `:78` 三项之一）：`TodoLists` 表无 `isPinned` 列、`AppTodoListBaseVO` 只有 `name`/`sortOrder`
  ⇒ 按「后端缺契约先修契约」，已另立 zh-cloud-service Issue，本 PR 不碰。
- **左滑动作形态**（同一句 `:78`）：本仓清单级动作表在侧栏长按（`list_actions.dart`），
  改左滑要动手势层并可能惊动黄金基线 ⇒ 单独一面。
- 不做"只登记变化那几条"的差量优化（`spec.md` 取舍 2）。

## 风险

- 事务包裹后，`reorder` 在真实同步链路上会串行写 N 条 outbox；清单数量级（几十）下无性能问题。
  若将来清单数上千，改差量登记并给"少登记但不能少收敛"的判据（见取舍 2）。
