# 145 台账

## T1 取证

- [x] 两个仓储：`listId == null || isEmpty ? 'inbox' : listId` —— 混键。
- [x] `home_shell.dart:767-781` `_effectiveListId`：inbox → `'inbox'`；
      today/tomorrow/upcoming/completed/trash/assignToMe → `null` ⇒ **null 从不代表收集箱**。
- [x] 探针实测（修复前）：`Expected: TaskSort.tag / Actual: TaskSort.priorityDesc`。

## T2 改键

- [x] `task_sort_preference_repository.dart` 加 `_noListSourceKey`。
- [x] `task_grouping_preference_repository.dart` 加 `_noListSourceKey`。
- [x] `list_view_preference_scope.dart` 的 `deviceNeutralKeys` 加 `'no-list'`。
- [x] 删掉因此变成未使用的 `_inboxSourceKey`（analyze 会报 unused_field）。

## T3 判据与订正

- [x] 新增 `test/task_list_preference_no_list_context_test.dart` 4 条。
- [x] 反向探针：还原成 `'inbox'` ⇒ 排序/分组两条红。
- [x] 订正 3 处把 null 当收集箱的存量用例（详见 spec.md）。

## 过程教训

1. **「测试红了」先问是谁错**：3 条转红里没有一条是产品回归 —— 它们都把
   `null` 当成收集箱在用，正是被修掉的那个缺陷。先读断言意图与生产调用点，
   再决定改代码还是改用例；这次是改用例（并补注释写清为什么）。
2. **加键必须同步查「归一白名单」**：新键 `no-list` 若不加进
   `deviceNeutralKeys`，同步层会把它当清单 UUID 归一，于是 #619 前半刚修好的
   跨端一致又被绕回去。判据里专门留了一条断言咬这个（`localListId` 返回 null）。
3. **原单可以只做一半**：#619 前半已由 !622 修好，但那笔用 `Refs` 而非 `Fixes`
   ⇒ 单子留着，容易让人以为整单没做。收尾时先查「这单是不是已被引用修过」。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `flutter analyze` | `No issues found!` |
| `test/task_list_preference_no_list_context_test.dart` | `+4 All tests passed!` |
| 偏好相关 8 个文件 | `+13 All tests passed!`（含订正后的 3 条） |
| 反向探针 | 排序/分组两条红 |
| 全量（exclude golden/performance） | `+2079 ~26`，0 失败 |
