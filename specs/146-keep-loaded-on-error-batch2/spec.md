# 146 · 失败保留已加载数据 · 批次 2（侧栏/列表主路径，原 FL #375）

## 背景

FL #375 记的是同一形状的 16 处：**已经加载出来的内容一旦遇到失败，就被 `.when` 的
`error:` 分支整页换掉**，用户看到的列表直接消失，而不是「保留旧数据 + 一条可见失败提示」。

批次 1（`habit_page` 两处 + `countdown_page`）已由 PR !376 合并（`4b71d21a`）。
本切片是**批次 2**。

## 现读订正（原单的行号与分类已过期，本切片现读重取）

- `grep -rn "\.when(" lib/` 现读 **17** 处，其中 2 处是注释 ⇒ 真实调用 **15** 处。
- 批次 1 那两处**已经不在列表里**（已改 `valueOrNull` + `AppRefreshFailedHint`）。
- 新增两处原单未点名：`habit_journal.dart:147`、`tasks_by_list_page.dart:3243`
  —— 本切片**不碰**（需各自探针，见 `tasks.md`）。
- `calendar_subscription_page.dart` 的 provider **自己 `try/catch` 成 data**
  （`:19-32`），那条 `.when(error:)` 对拉取失败**不可达** ⇒ 照套 `valueOrNull` 是无效功，
  本切片**排除**它（真修法是 provider 不再吞异常，另属一单）。

## 内容

本切片改 **4 处流背书页面**（形状与已合并的 #353 完全一致）：

| 文件 | provider | 提示文案 |
| --- | --- | --- |
| `features/filter/saved_filters_page.dart` | `savedFiltersStreamProvider` | 过滤器刷新失败，仍显示上一次的数据 |
| `features/folder/folder_page.dart` | `foldersStreamProvider` | 文件夹刷新失败，仍显示上一次的数据 |
| `features/list/list_page.dart` | `listsStreamProvider` | 清单刷新失败，仍显示上一次的数据 |
| `features/tag/tag_page.dart` | `tagsStreamProvider` | 标签刷新失败，仍显示上一次的数据 |

改法（最小 diff，不重写各页的数据渲染块）：

1. 给 `.when(...)` 加 **`skipError: true`**。Riverpod 2.6.1 里 `AsyncValue.when` 的判据是（本机 pub cache 的 riverpod 源码，非本仓文件）
   `if (hasError && (!hasValue || !skipError))` ⇒ **有值**时跳过 error 分支走 data；
   **首值没读到**（`!hasValue`）时仍走失败态 —— 正是 #375 要求的第 1/2 条。
2. 在其**上方**用 `if (x.hasError && x.hasValue) AppRefreshFailedHint(...)` 给可见提示，
   与批次 1 `habit_page.dart:63` 的写法一致（框架不替我们显示「失败但有旧值」这档）。

## 为什么用 `skipError` 而不是手写 `valueOrNull` 三分支

手写三分支要把每页的 `data:` 渲染块抽成独立方法（4 个页面各一次大改，diff 大且易错）；
`skipError` 是框架**为此设计的开关**，语义逐字相等，diff 只多一行 + 一个提示条。

## 验证

| 门 | 读数 |
| --- | --- |
| 新增 `test/features/keep_loaded_on_failure_pages_test.dart` | `+2 All tests passed!` |
| 反向探针（删掉 `skipError: true`） | **两条各自红** |
| 既有相关回归（saved_filters / tag_page / folder_disband） | `+27 All tests passed!` |
| `flutter analyze` | `No issues found!` |
| `dart format --set-exit-if-changed lib test` | `rc=0` |
| 全量（exclude golden/performance） | 见 `tasks.md` |

### `skipError` 的语义出处（不靠记忆）

本机 pub cache 的 riverpod 2.6.1 源码（`lib/src/common.dart`，**仓外文件**，故不写成可解析锚点）：

```dart
if (hasError && (!hasValue || !skipError)) {
  return error(requireError.$1, requireError.$2);
}
```

复核方式：`grep -n "hasValue || !skipError" ~/.pub-cache/hosted/pub.dev/riverpod-2.6.1/lib/src/common.dart`

## 边界

- **不改** `habit_journal.dart:147` 与 `tasks_by_list_page.dart:3243`：原单没点名，
  各需自己的探针确认「有没有值可留」。
- **不改** `calendar_subscription_page.dart:122`：机制不同（见上）。
- **不改** `quadrant_rules_page` / `achievement_page` / `list_member_page` /
  `task_assign_page` / `reminder_inbox_page`：它们或带重试部件（改的是 UI 语义）、
  或有内层软失败、或双层 `.when`，属批次 3，另单。
