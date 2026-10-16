# 145 · 每清单偏好：「无清单上下文」与「收集箱」分键（原 FL #619 后半）

## 背景

FL #619 记了两件事。前半（跨设备键归一：`TASK_SORT`/`TASK_GROUP` 发本地 UUID）
已由 PR !622 修掉并合入 develop（`b8af771b`），但那笔用了 `Refs` 而不是 `Fixes`，
所以单子一直开着。

**本切片修的是后半**（原单「两条补充」的第 2 条）：

> 智能清单的排序/分组现在写进了收集箱那一行：`tasks_by_list_page.dart:856-861`
> 是 `save(_selectedListId, sort, _sortDirection)`，而 `_selectedListId`（`:91` 声明为 `String?`）
> 在智能清单/四象限这类"没有清单上下文"的页面就是 null ⇒ 落进 `inbox` 行。
> 后果：在"今天"里改排序，会连带改掉收集箱的排序档位（同一把键）。

两个仓储都用 `listId == null || listId.isEmpty ? 'inbox' : listId` 作键，
把「无清单上下文」与真实清单收集箱混成同一个值。

## 取证（先证它真的会串）

`home_shell.dart` 的 `_effectiveListId` 对 `SmartList.inbox` 返回**字面量 `'inbox'`**，
对其余智能清单（today / tomorrow / upcoming / completed / trash / assignToMe）返回 `null`。
即**生产代码从不传 `null` 来表示收集箱** —— 收集箱有它自己的 id。

一次性探针（先红后修）：

```dart
await repo.save('inbox', TaskSort.tag);            // 收集箱设「按标签」
await repo.save(null, TaskSort.priorityDesc);      // 智能清单设「按优先级」
expect((await repo.get('inbox')).sort, TaskSort.tag);
// 修复前：Expected: TaskSort.tag / Actual: TaskSort.priorityDesc ⇒ 收集箱被顶掉
```

## 内容

- 两个仓储各加一把独立键 `_noListSourceKey = 'no-list'`，`null` / 空串落它，
  真实清单（含收集箱 `'inbox'`）仍按 id 作键。
- `ListViewPreferenceScope.deviceNeutralKeys` 加 `'no-list'`：
  它是**设备无关的字面量**，绝不能被同步层当成「一个还没上服务端的清单」去归一，
  否则跨端各写各的 —— 那正是 #619 前半的病。这一步不做就等于把前半修好的又绕回去。

## 边界

- 不改 `_effectiveListId` / 页面调用点：键这一层分开就够了，调用方语义不变。
- 存量数据：此前「在智能清单里改排序」写下的行落在 `'inbox'` 键上，
  与收集箱自己的值本来就分不开。不写迁移脚本（无法判定哪一行是智能清单写的），
  修后各端重新改一次即覆盖 —— 与原单给的判断一致。

## 验证

| 门 | 读数 |
| --- | --- |
| 新增判据 `test/task_list_preference_no_list_context_test.dart` | `+4 All tests passed!` |
| 反向探针（把 `_noListSourceKey` 还原成 `'inbox'`） | 排序/分组两条各自红 |
| `flutter analyze` | `No issues found!` |
| 全量（exclude golden/performance） | `+2079 ~26`，0 失败 |

### 连带订正的三处「测试本身在编缺陷」

改键后有 3 条存量用例转红，逐条查证**都是用例自身把「无清单上下文」当成了收集箱**，
不是产品回归：

1. `test/sync_coordinator_list_scoped_preference_test.dart`：`save(null, …)` 后断言
   出站 `sourceKey == 'inbox'`。生产里收集箱传的是 `'inbox'`，`null` 只能来自智能清单
   ⇒ 改成 `save('inbox', …)`。
2. `test/task_grouping_preference_repository_test.dart`：注释逐字写着
   「null（收集箱/智能清单视角）」—— 把两种语义写成一个视角。改成分别用
   `'inbox'` 与 `null` 各存一份、各读一份，顺带把两条路径都盖住。
3. `test/task_sort_direction_test.dart` / `test/features/task/task_organize_search_test.dart`：
   fixture 的任务都在收集箱、断言也要收集箱那把键，但构造页面时**没传**
   `initialListId` ⇒ 实际落在「无清单上下文」。补 `initialListId: 'inbox'`
   让用例真的是收集箱页（生产由 `_effectiveListId` 显式给出这个值）。
