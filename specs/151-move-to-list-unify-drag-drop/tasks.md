# 151 台账

## T1 现读五条通道

- [x] 侧栏 `moveTask` = `update(listId:, clearSectionId: true)`（子树不跟）。
- [x] `list_drop_target.handleDrop` = 同上形状。
- [x] 详情面板 `:1149` = `update(listId:)`（分组不清 ⇒ `_requireSectionInList` 抛错）。
- [x] 批量 = 直接 companion 写，只校验「清单存在」。
- [x] 行左滑 = `moveToList`（当时唯一对的那条）。
      复跑：`grep -rn "moveToList(" lib/ | grep -v task_repository.dart`
      ⇒ 改动前只有 `task_row_host.dart` 一处；改动后是它 + 本批并过来的两处。

## T2 改动

- [x] 侧栏接缝 → `moveToList`。
- [x] `list_drop_target` → `moveToList` + 只读/失败分开说。
- [x] `SidebarDropOutcome.readOnly`；`_serialize` 用 `isTaskViewReadOnlyError` 分流。
- [x] `sidebar.dart` 抽 `_showDropFailure`，三处落点共用。

## T3 判据与探针

- [x] 侧栏：新增「拖父任务 ⇒ 子任务也在新清单」真库真手势用例。
- [x] 清单落点：同类用例（真库 + 真 `TaskRepository`）。
- [x] 既有假仓储 `_ScriptedRepository` 的钩子（gate / failNext / writtenTargets）从 `update` 挪到 `moveToList`
      —— 否则「串行」「失败提示」那几条会变成**没有写请求也照样绿**的空断言。
- [x] **反向探针**：两处各自退回 `update` ⇒ 各自的新用例转红。

## 过程教训

1. **判据要落在被改的那一层**：仓储的 `moveToList` 早有 7 条用例（子树/只读/清分组），
   但它们**证明不了入口有没有调用它** —— 这正是本单的缺陷形状。
   所以两条新判据都用**真库 + 真手势/真仓储**，把「入口 → 通道」这一跳也钉住。
2. **换通道会把假仓储的钩子变成空钩子**：`_ScriptedRepository` 覆写的是 `update`，
   并轨后「串行」「失败提示」那两条**仍会绿**，但测的已经不是同一条路了
   （`writtenTargets` 恒空、gate 永不生效）。这类"绿得没意义"的用例必须跟着挪钩子。
3. **别把「拒绝」说成「失败」**：只读清单是可解释的拒绝，报「移到 X 失败」会让用户重试。
   分出一个 `readOnly` 枚举值 + 三处共用一句口径，比在三个 call site 各写一遍三元表达式稳。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 定向（侧栏/智能清单/清单落点） | 侧栏 `+13`、智能清单 `+15`、清单落点 `+7`，全绿 |
| 反向探针 | 两条各自红 |
| `flutter analyze` | `No issues found!` |
| 全量（exclude golden/performance） | `+2102 ~26`，**0 失败**（较修前 +2 = 本批新增） |
