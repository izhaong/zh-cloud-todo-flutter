# 149 台账

## T1 取证

- [x] 现读 `sidebar.dart` 三处落点接法：清单行与智能清单行拿快照当闸门，标签行 `(_) => true`（对照）。
- [x] 现读 `onWillAcceptWithDetails` 同步 ⇒ 闸门返回 false 时 `onAcceptWithDetails` 不触发
      ⇒ **skip 发生在悬停层**，原单说的「落下时 skip」不准确。
- [x] 现读 `addTagToTask` 一侧：`attachTag` 现读 `tagIdsOf`，本来就没这个病。

## T2 改动

- [x] `SidebarTaskDropController` 加必填 `loadTask`；provider 接 `taskRepository.getById`。
- [x] `moveToList` / `applySmartListTimeCondition`：判据移到落下时、按当前行算。
- [x] `_serialize` 改接 `Future<SidebarDropOutcome> Function()`；`addTagToTask` 只跟签名。
- [x] `_currentRow`：读不到则退回快照。
- [x] `sidebar.dart` 两处 `accept` → `(_) => true`，并写明为什么悬停不能当闸门。

## T3 判据与探针

- [x] 清单行 3 条 + 智能清单行 2 条（成对）。
- [x] 既有 6 个构造点补 `loadTask: (taskId) async => null`（存量语义不变）。
- [x] 定向回归：两文件 `All tests passed!`
- [x] **反向探针**：`_currentRow` 退回快照 ⇒ 两条「必须写」转红
      （清单行那条 + 智能清单行那条），另三条仍绿。

## 过程教训

1. **先量「这个 bug 发生在哪一层」再动手**：原单把它写成「落下时按快照判」，
   实际闸门在同步的 `onWillAcceptWithDetails` 上 —— 只改控制器的话，新加的「重读库」
   一次都不会被执行，而**控制器级用例却会全绿**（它们直接调控制器，绕过了悬停）。
   这就是「修了但没生效」的典型形状：**判据的层次必须与被修的层次一致**。
2. **测试与实现用不同的时钟 = 假红**：智能清单那两条我一开始用 `_dueAt(offsetDays: 0)`，
   而该 group 的 `now` 是固定值 ⇒ 两边不是同一个时钟，稳定判错。
   写成固定日期后与 `now` 对齐。（这类错会表现成「实现有问题」，实际是判据自己在错。）
3. **给读取接缝设默认值 = 留一个静默关掉修复的口子**：故 `loadTask` 设为**必填**，
   让 6 个测试构造点各自显式表态。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 定向（两文件） | `All tests passed!`（12 + 15 条，含新增 5 条） |
| 反向探针 | 两条「必须写」转红 |
| `flutter analyze` | `No issues found!` |
| `dart format --set-exit-if-changed` | `rc=0` |
| 全量（exclude golden/performance） | `+2100 ~26`，**0 失败**（较修前 +5 = 本单新增的 5 条） |
