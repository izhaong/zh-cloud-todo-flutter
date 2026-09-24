# 031 任务清单

**复核手段说明（工具替代）：** 目标要求的 `claude` CLI 复核在本机不可用（`--model` 报 `unrecognized_model`）。替代 = 本会话派出的**只读子代理**审本轮 FR，并要求它以 `VERDICT:` 结尾。第 1 轮结论 `VERDICT: FAIL`（5 条 finding），全部按结论落地或写明不采纳理由；第 2 轮（改完复验）在写回本文前的探针里以「四组反向探针 + 全量门禁」自证，未再取第二次 `VERDICT`（目标规定：两轮无新结论就停，不循环重跑）。

## 任务

- [x] **T1 帮助中心口径落地**：`06-多级任务.md:176-179` 的「仅检查事项的完成影响进度；全部完成后主任务自动完成」写进 `spec.md` 行为 1。
- [x] **T2 红测**：`test/features/task/checklist_completes_task_test.dart` 先建 8 例（后扩到 10 例），`00:00 +5 -3` 且失败信息精确指向缺失项（日志 `/tmp/red-031.log`）：`Expected: … 取消勾选 / Found 0 widgets`、`completed isFalse`。
- [x] **T3 实现**：`task_repository.dart` `toggleChecklistItem` 勾成完成时调用 `_completeTaskWhenChecklistDone(parent)`（同事务内：只读清单 / 已完成 / 已作废早退 → 重查全部检查事项 → 有未勾完则退 → 否则写 `completed/completedAt/updatedAt` 并入队一条 `task/upsert`）。未加新表、新列、新开关。
- [x] **T4 outbox 与同步核对**：子代理复核确认排序（检查事项必在父任务前，`sync_coordinator.dart:175` 比较器 + `:775` 同 localId 共用临时号）、pull 侧不反向入队（`:1595`）；本轮未改同步代码。
- [x] **T5 详情面板取证**：widget 用例证明 DB→`watchById`（`task_detail_pane.dart:709`）→头部按钮 `勾选完成 → 取消勾选`；勾选回调本身不做 `setState`，所以按钮变化只可能来自流。
- [x] **T6 四组反向探针**（见下表），每次恢复后 `cmp -s` 逐字节一致。
- [x] **T7 门禁全绿**（原文见下）。
- [x] **T8 复核 finding 逐条处置**（见下）。
- [ ] **T9 仍缺（不得被上面的勾选掩盖）**
  - 已证实：勾选路径的自动完成、幂等、作废与只读豁免、兄弟任务隔离、子任务不影响父任务、UI 经流刷新。
  - 仍缺：① `deleteChecklistItem`（`task_repository.dart:714`）删掉最后一条未勾项后留下的「全部完成」事实**未**触发自动完成（本轮有意不接线：那会让「删除一条待办」变成「完成整个任务」的隐式副作用）；② 取消勾选后是否该回退父任务，需要 `auto_completed` 之类的标记列才能区分自动/手动 ⇒ SQL + Service 契约变更，属需授权动作；③ 已自动完成的任务再新增一条未勾检查事项时不回退（未测，行为与 ① 同源）；④ 真机/远端 CI 未验证（`flutter build ios` 卡 SPM、Gitea runner cgroup 未挂载）。

## 反向探针

| # | 摘掉的生产代码 | 结果 |
|---|---|---|
| 1 | `if (next.completed) await _completeTaskWhenChecklistDone(parent);` | `+5 -5`：勾满自动完成 / 不回退 / 兄弟隔离 / 重勾幂等 / 详情面板 5 例红 |
| 2 | `if (task.completed \|\| task.cancelled) return;` | `+7 -3`：已手动完成不重复入队、已作废不复活、重勾幂等 3 例红 |
| 3 | `if (items.any((item) => !item.completed)) return;` | `+9 -1`：「还有未勾完就不动」红 |
| 4 | `if (list != null && !list.writable) return;` | `+9 -1`：只读清单豁免红 |

每次恢复后：`RESTORE byte-identical OK`（`cmp -s` 对 `/tmp/tr.orig.dart`）。

## 复核 finding 处置

| finding | 处置 |
|---|---|
| `tasks.md` 缺失、spec/plan 三处引用指向空气 | 采纳：本文件补齐 |
| 「没有检查事项的任务」用例是空跑，且 `items.isEmpty` 为死分支 | 采纳：删该用例 + 删 `items.isEmpty`，`spec.md` 行为 6 改为「规则只由勾选路径触发」的真实口径（复核员的推理成立：被勾项必属本任务，故空集不可达） |
| `pubspec.lock` 446 行镜像源改动 | **不采纳其「checkout 还原」建议**。理由：本机 Flutter 3.44.8 走镜像源重新解析是环境事实，还原后本地跑不了门禁；该文件按目标约定**不随功能 PR 提交**（本轮 staged 清单里没有它），CI 用仓库内的 lock 自行解析。这条与第 7 轮同一处理 |
| 只读清单副作用被放大（`toggleChecklistItem` 无 `_requireWritableList`） | 采纳（只补新副作用）：自动完成前判 `todoLists.writable`，只读则跳过。没给 `toggleChecklistItem` 加抛错守卫——那会改动既有已验收行为（勾选项本身照常入库）并回滚别人的用例 |
| 未钉住的边界：「上次自动完成」未测、`updatedAt` 前进未断言、缺兄弟任务隔离用例 | 采纳：补 2 例（重勾幂等、兄弟隔离）；`updatedAt` 断言**不加**——SQLite 毫秒存储使 `created→auto-complete` 可能同毫秒，断言会 flaky，已在 `spec.md` 行为 1 写明改由 `completedAt` + outbox 作证 |

## 门禁（最终状态一次跑完，日志 `/tmp/gate-031-final2.log`）

```
### 1 git diff --check
exit=0
### 2 dart format (explicit files)
Formatted 2 files (0 changed) in 0.04 seconds.
exit=0
### 3 flutter analyze
No issues found! (ran in 1.5s)
### 4 golden
00:03 +9: All tests passed!
### 5 full suite
01:54 +719 ~26: All tests passed!
### 6 build web
✓ Built build/web
```

`dart format` 本轮**真的红过一次**：首跑 `Formatted 2 files (2 changed)`、`exit=1`（日志 `/tmp/gate-031-final.log`），对两个显式文件原地格式化后复跑 `2 files (0 changed)`；格式化后重跑 golden/全量/构建（`/tmp/gate-031-postformat.log`、上表即最终态）。
本轮用例单独跑：`flutter test test/features/task/checklist_completes_task_test.dart` → `00:00 +10: All tests passed!`。
计数核对：develop 基线 709（第 7 轮 731 = 709 + 030 的 22 例，未并入本分支）+ 本轮 10 例 = 719，与输出一致；黄金图 9 张全部未变，无需重录授权。

## 同步状态

分支 `feat/todo-checklist-completes-task`，Issue #276，PR → develop（`Fixes #276`）。`pubspec.lock` 保持本机改动、不入 PR。

## 下一轮入口

1. **本行 #23 剩余面**：列表内子任务的展开/收起与缩进呈现（现清单页 `tasks_by_list_page.dart:1290` 只取 `parentTaskId.isNull()` 的顶层任务，子任务只在详情面板的 `_SubtaskList` 里可见）——**会改列表可见布局，先申请重录 9 张黄金图**。
2. 详情面板缺「关联主任务」到任意任务的入口与父任务面包屑跳转（批量模式已有 `tasks_by_list_page.dart:741-743`）。
3. 看板/时间线 B4 跨端可操作闭环；#67 导入收口（滴答官方导出格式仍 0 命中）。
4. #18 文件夹管理 UI 入口（`list_page.dart` 零引用）——同样需批准重录基线。
5. 矩阵轨道 A：未复校行 42 → 逐行换 `文件:行号` 证据；#20 分组排序与 #23 多级任务的行状态在 !277 合并后要翻并引合并 SHA。
