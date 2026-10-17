# 151 · 拖放两条「换清单」通道并轨到 `moveToList`（原 FL #603，第一批）

## 背景

FL #601 为「左滑 → 移动任务」新造了 `TaskRepository.moveToList`：**子树跟着走、跨清单清分组、
目标清单必须可写、子任务不许单独换清单**。但量代码发现「换清单」在仓里有多条通道、行为各不相同。

## 本轮现读的五条通道（原单的表已过期，重取）

| 入口 | 现读走哪 | 子树 | 清分组 | 目标可写 | 父子同清单 |
| --- | --- | --- | --- | --- | --- |
| 行左滑「移动任务」（`task_row_host.dart`） | `moveToList` | ✓ | ✓ | ✓ | ✓ |
| 拖到侧栏清单（`sidebar_task_drop.dart` 的 `moveTask`） | `update(listId:, clearSectionId: true)` | **✗** | ✓ | ✗ | ✗ |
| `list_drop_target.dart`（拖进当前清单） | `update(listId:, clearSectionId: true)` | **✗** | ✓ | ✗ | ✗ |
| 详情面板保存（`task_detail_pane.dart:1149`） | `update(listId:)` | **✗** | **✗（且抛错）** | ✗ | ✗ |
| 批量「移至清单」（`task_batch_edit_repository.dart:174-207`） | 直接 companion 写（校验只有「清单存在」） | **✗** | **✗** | ✗ | ✗ |

## 本批做哪两条、为什么

**做侧栏拖放与 `list_drop_target` 这两条**：它们是**同一形状的两份**
（都是 `update(listId:, clearSectionId: true)`），改动机械、没有口径分歧，
且症状最直白 —— **只挪父行会让子级留在原清单**，而清单页已经把子级铺成行
（specs/116），于是父行上的展开箭头点开是**空的**，看起来像子任务被删了。

**本批不做详情面板与批量**，理由是它们各自带一个**要裁的口径**（见下「边界」）——
按 AGENTS.md「多种解读先摆出来确认」，这两条留给下一批，不顺手选。

## 改动

1. **侧栏**：`sidebar_task_drop.dart` 的 `moveTask` 接缝从
   `update(listId:, clearSectionId: true)` 换成 `repository.moveToList(taskId, listId)`。
2. **清单落点**：`list_drop_target.dart` 的 `handleDrop` 同上，
   并把 catch 从 `catch (_)` 改成 `on Object catch (error)`，用
   `taskViewMutationFailureMessage(error, failureMessage)` 把**只读**与**失败**分开说。
3. **`SidebarDropOutcome` 加 `readOnly`**：只读是**可解释的拒绝**，
   说成「移到 X 失败」会让用户以为重试就好。判据复用既有
   `isTaskViewReadOnlyError`（与任务视图其它入口同一处定义）。
4. **`sidebar.dart` 抽 `_showDropFailure`**：三处落点（智能清单 / 标签 / 清单）共用一句「说哪句话」的口径，
   不再各抄一份；`applied` / `skipped` 不提示（`skipped` 是「本来就满足」的正常结果，报失败是谎报）。

## 判据

| 入口 | 判据 |
| --- | --- |
| 侧栏拖放 | 真库真手势：拖**父**任务换清单 ⇒ **子任务也在新清单**（反向探针：退回 `update` ⇒ 红） |
| 清单落点 | 同上（真库 + 真 `TaskRepository`）（反向探针：退回 `update` ⇒ 红） |
| 既有回归 | 侧栏/智能清单/清单落点三个文件全绿（含把假仓储的钩子从 `update` 挪到 `moveToList`） |

## 边界（本批**不做**，各带一个要裁的口径）

- **详情面板**（`task_detail_pane.dart:1149`）：它现在是「标题/时间/清单一次写入」
  （`_save`）。并过来会**拆成两笔事务** —— 原单说这是「本工单最需要裁的一处」，
  两条路（先写主体再挪清单并保证第二笔失败可见 / 只在「只改了清单」时走 `moveToList`）各有代价，
  **不擅自选**。它同时也是原单点名的「红色起点」（带着分组改清单会因 `_requireSectionInList` 抛错）。
- **批量移至清单**（`task_batch_edit_repository.dart`）：它一条命令写多个字段（标签/截止/优先级/清单），
  放进 `moveToList` 要么拆事务、要么在批量里重造那四条校验；
  且「批量里选中子任务」在 `moveToList` 下会**抛错**（子任务不许单独换清单），
  这需要一个用户可见的口径（拒绝并说明 vs 连父一起挪）。**不擅自选。**
