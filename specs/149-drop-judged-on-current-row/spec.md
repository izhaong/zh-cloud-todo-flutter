# 149 · 侧栏拖放落点按库里当前行判据（原 FL #585）

## 现象

侧栏拖放落点判断「这一次拖要不要写」用的是**拖出那一刻的任务快照**
（`Draggable<TodoTask>` 的 data），而真正写库前读的却是库里的当前行。
快照与库分叉时，落点按旧数据判「已满足」而 **skip** —— 用户那一次拖动被**静默吞掉**：
没有写入、没有提示、任务还在原地。

分叉是正常的：拖出源（看板 / 时间线 / 日历 / 并列视图）在渲染时取行，
跨一次 pull 之后就与库分叉（pull 会周期性覆盖本地行）。

## 关键发现：skip 其实发生在**悬停**那一步，不是落下

原单把它描述成「落下时 skip」，但现读三处落点的接法是：

```dart
// sidebar.dart
accept: (task) => controller.acceptsSmartList(task, condition),   // 智能清单行
accept: (task) => controller.acceptsList(task, list.id),          // 清单行
accept: (_) => true,                                              // 标签行（对照）
```

`DragTarget.onWillAcceptWithDetails` 是**同步**的，只能看快照；它一旦按快照返回 false，
`onAcceptWithDetails` **根本不会触发** ⇒ 落点里任何「按库里当前行重判」都没有机会跑。
所以只改控制器是不够的：**悬停那一层也必须不再当闸门**。

原单点名的第三处 `addTagToTask` **本来就没有这个病**（它现读 `tagIdsOf`），
且它的 `accept: (_) => true` 正是本单要的形状 —— 于是本单把另两处**对齐到标签那处**。

## 修法

1. **控制器加读取接缝** `loadTask`（`Future<TodoTask?> Function(String)`）。
   判据改成在 operation 内 `await _currentRow(task)` 之后再算 ——
   两个落点（`moveToList` / `applySmartListTimeCondition`）一起改才对称。
2. **`loadTask` 是必填参数**：可选 + 默认退回快照等于留一个「静默关掉本修复」的口子。
3. 读不到当前行（被删 / 被 pull 掉）⇒ **退回拖出快照**，让下游仓储去决定怎么写。
4. **悬停不再当闸门**：`accept: (_) => true`（与标签落点同口径），判据统一交给落下时那一步。
5. `_serialize` 从「接 `Future<void> Function()`、自己算 applied/failed」改成
   「接 `Future<SidebarDropOutcome> Function()`」，好让落点把自己算出的 `skipped` 带出来。
   `addTagToTask` 只跟签名，行为不动。

## 一处**刻意不改**

悬停时那两处 `acceptsList` / `acceptsSmartList` 仍是公开方法、仍是「什么算有效落点」的
**唯一定义处**，只是改为在落下时调用。没有删掉它们去换内联判断 ——
那会让「有效落点」长出一份并行的定义。

复跑命令（「定义处只有这里」的判据）：

```bash
# 定义处各 1（都在 sidebar_task_drop.dart）
grep -rn "bool acceptsList\|bool acceptsSmartList" lib/          # ⇒ 2 行，同一文件
# 调用点只有这两处，且都写着 await _currentRow(task)（即判据读的是库里的行）
grep -rn "acceptsList(\|acceptsSmartList(" lib/ | grep -v "bool accepts"
# ⇒ sidebar_task_drop.dart:122 (`await _currentRow(task)`) 与 :141（同）
```

（注：`smart_list_time_condition.dart` 里另有 `satisfiedBy` 的**定义**，它是窗口谓词本身、
不是第二处落点判据；落点只在上面那两处调用它。第一版我把这条判据写成「别处无命中」，
实跑发现会把那个定义也算进去 ⇒ 改成上面这种**分清定义与调用**的写法。）

## 判据（各端成对：绿要能写、红要不写）

| 用例 | 快照 | 库里的当前行 | 期望 |
| --- | --- | --- | --- |
| 清单行：快照说已在目标清单、库里已不在 | `L1` | `L2` | **写**（`t1->L1`） |
| 清单行：库里确实已在目标清单 | `L1` | `L1` | **不写**（skipped） |
| 清单行：库里那一行没了 | `L1` | `null` | **不写**（退回快照） |
| 智能清单：快照说已满足、库里已挪出窗口 | 10-12 | 10-20 | **写**（落到 `targetDay`） |
| 智能清单：库里确实已满足 | 10-12 | 10-12 | **不写**（skipped） |

**反向探针**：把 `_currentRow` 改回直接返回快照（= 修复前行为）⇒
上表两条「**写**」各自转红，另外三条仍绿。这正是本单要的判别力。

## 边界

- **不带 #600/#590 的第 4 形**（`task_subtask_drop`）：原单只点侧栏三处，
  第 4 形是否同单要另裁，不在本切片。
- 不改 pull / 同步链路本身 —— 本单治的是「落点判据读错了数据源」。
- 悬停文案（`hoverLabel`）仍在，只是不再代表「这个落点一定会写」。
