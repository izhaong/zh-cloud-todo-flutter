# 152 · 「换清单」剩下两条通道并轨（原 FL #603 第二批：详情面板 + 批量）

## 背景

`specs/151`（第一批）并掉了拖放那两条通道。本批收掉剩下两条，
`moveToList` 现在**是**唯一的换清单通道：

```bash
# 换清单的调用点：只剩 moveToList
grep -rn "moveToList(" lib/ | grep -v task_repository.dart
# 还有没有人借 update(listId:) 换清单：应为空（改前这里有 4 处）
grep -rn "listId:" --include=*.dart lib/ | grep -E "\.update\("
```

顺带收掉第 5 处同形状的（原单的表没列它）：`task_detail_pane.dart` 的 `_moveToInbox`
原来也是 `repo.update(t.id, listId: kInboxListId)` —— 同样不清分组、子树不跟。

## ① 详情面板：带分组换清单会**抛错**

`task_detail_pane.dart` 的 `_save` 原来把 `listId` 一起交给 `repo.update`（"标题/时间/清单一次写入"）。
而仓储里 `update` 会 `_requireSectionInList(targetListId, sectionId ?? current.sectionId)` ——
拿**旧清单的 `sectionId`** 去校验**新清单** ⇒ 当场抛错，用户看到的是**"改不动"**，
而不是"要先移分组"。这正是原单点名的「红色起点」。

**修法（两笔写）**：`update` 里**不再带 `listId`**；换清单改由随后的 `moveToList` 承担。
判据在**接缝**上钉（`_RecordingMoveRepository`）：
- `update` 收到的非空 `listId` 必须**为空**；
- 必须有且仅有一次 `moveToList(taskId, 目标清单)`。

**为什么不用"只在只改了清单时才走 moveToList"那条更小的口径**：
它会把「同时改了标题和清单」那一支留在原路 —— 而那一支**今天就是抛错的**，
且"改标题顺带换个清单"是常见动作。要修就修全，不能只修一半、另一半照旧抛错。

第二笔失败**必须可见**（与同一函数里"标签是第二次写"同一处置）：
`moveToList` 抛错时报的是 `taskViewMutationFailureMessage`（只读清单说"只读"，其余说"没能移到目标清单"），
**不静默早退**。

## ② 批量「移至清单」：三条都缺

`task_batch_edit_repository.dart` 的 `listId` 分支原来**只校验「清单存在」**：

| 缺什么 | 后果 |
| --- | --- |
| 不查目标清单**可写** | 往只读清单（订阅来的）搬会**静默成功** |
| 不清 `sectionId` | 留下「`listId` 在新清单、`sectionId` 还是旧清单的」**违规数据** |
| 不拒**子任务** | 子任务被单独挪走 ⇒ 当场造出「父子不同清单」 |

**修法**：三条都在写库前拦下，理由**原样上报**（`on StateError` → `error.message`）。
原来外层是 `catch (_)` 兜底成「本地写入失败」——
那是一句**没有下一步的句子**，用户不知道该怎么办。

**为什么批量没有直接调用 `moveToList`**：试过。它会**各自再入队一次**，
于是每个任务产生两条 outbox（`moveToList` 一条 + 批量一条），
破坏了批量"逐项各一条"的既有约定（实测：2 个任务 4 条，既有用例当场红）。
要真正复用 `moveToList` 的**子树**那一半，得先把它的"落库部分"与"入队部分"拆开 ——
**那是独立一刀**，本批不顺手做。

**因此批量这条**：三条守卫 + 清分组**已修**；**「子树跟着走」仍未做**，
记为 `#603` 的遗留（理由如上，不是漏掉）。

## 判据

| 入口 | 判据 | 反向探针 |
| --- | --- | --- |
| 详情面板 | 接缝：`update` 无 `listId` + 恰一次 `moveToList` | 退回 `update(listId:)` ⇒ 红（`Expected: empty / Actual: ['visual-list-personal']`） |
| 批量·子任务 | 拒绝且理由 =「子任务请随主任务一起移动」 | 撤掉守卫 ⇒ 红 |
| 批量·只读 | 拒绝且理由 = `taskViewReadOnlyMessage` | 撤掉守卫 ⇒ 红 |
| 批量·清分组 | `sectionId` 变 `null` | 撤掉清分组 ⇒ 红 |

## 边界

- 批量「子树跟着走」未做（见上，需先拆 `moveToList` 的落库/入队两半）。
- `_pumpDirectPane` 新增了 `prepare` 接缝（在 pump 前写种子），本批用它做诊断；
  最终那条判据改走**接缝**而不是 UI 点击，因为 UI 路径在"带分组"时不容易稳定驱动。


---

## 收口（本轮补做）：批量的「子树跟着走」已落地

`specs/152` 当时把批量的**子树**记为遗留，理由是"要复用 `moveToList` 的子一半，得先把它的
落库部分与入队部分拆开 —— 那是独立一刀"。**这一刀本轮做了**（用户裁定「按推荐的来：拆」）：

- `TaskRepository` 拆出 **`moveRowsToList(taskId, targetListId)`**：校验 + 子树 + 清分组，
  **不开事务、不入队**；`moveToList` = `transaction { rows = moveRowsToList(...); 逐行入队 }`。
- 批量的 `listId` 分支改调 `moveRowsToList`，并**自己补入队被挪的子级**
  （它们是这一刀的真实副作用，不补就不同步）；本任务那条仍由批量原来的 enqueue 统一带上其它字段。
- 副作用：`moveRowsToList` 对 no-op（已在目标清单）返回**空列表**，由 `moveToList` 翻译回
  「被点的那一行」—— 若照旧返回 `[task]`，no-op 会**白排一条 outbox**（重构时踩到，既有用例当场红）。

**现在五个入口全部「子树跟着走」**：

| 入口 | 子树 | 入口级用例 |
| --- | --- | --- |
| 行左滑 | ✅ | ✅ |
| 拖到侧栏清单 | ✅ | ✅ |
| `list_drop_target` | ✅ | ✅ |
| 详情面板 | ✅ | ✅ |
| 批量「移至清单」 | ✅ | ✅（本轮补） |

判据：批量移父任务 ⇒ **子任务也在新清单**，且 `task-1`/`task-2` 各有 outbox。
**反向探针**：把批量那处 `moveRowsToList` 调用去掉 ⇒ 子任务留在 `list-inbox`，判据转红。
