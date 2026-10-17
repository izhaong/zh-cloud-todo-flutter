# 156 台账

## T1 取证

- [x] 嘀嗒 :17 原文；服务端契约已落（`specs/057`）。
- [x] 客户端 `TodoTaskBatchUpdateRequest` / `TaskBatchEditCommand` 都没有指派人字段。
- [x] 单条指派的拒绝文案在 `task_assign_action.dart`（「任务尚未同步，无法指派」）。

## T2 改动

- [x] API 模型 + `hasChanges()` + `toJson`。
- [x] 批量命令 + 本地写库（`Value.absent()` 而非 `Value(null)`）。
- [x] 动作枚举 + 菜单项 + label（逐字用「分配给」）。
- [x] `_assignBatchSelection` + `_selectBatchAssignee`（只列 active；没取回不猜）。

## T3 判据与探针

- [x] 两条判据（每条都写 / null 不动）。
- [x] 两条独立反向探针，各自转红。
- [x] 全量见提交信息。

## 过程教训

1. **`Value.absent()` 与 `Value(null)` 是两种语义**：前者"这一档不改"，后者"清空"。
   批量编辑里字段多，混用的后果是"改优先级顺手清空执行人"——**用户不会知道是自己干的**。
2. **"没取回来"与"没有成员"必须分开**：`valueOrNull == null` 时给"请稍后重试"，
   而不是"这个清单还没有其他成员"。后者是一句**结论**，而当时并没有依据。
3. **只列 `active` 成员**：列一个"点了必被拒"的人，等于把服务端的校验结果前移成一次
   无意义的失败 —— 界面上能提前判的就别让用户去撞。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 该文件 | `+35 All tests passed!` |
| 两条反向探针 | 各自转红 |
| `flutter analyze` | 0 issue |
| 全量（exclude golden/performance） | `+2113 ~26`，**0 失败**（较修前 +2 = 本单新增） |
