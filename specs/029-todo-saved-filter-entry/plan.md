# 实现计划：已保存过滤器

| 变更 | 文件 | 说明 |
| --- | --- | --- |
| 条件模型 | `lib/state/repositories/filter_repository.dart` | `TodoFilterConditions` 补 `dateRange{preset,from,to}`（对齐服务端 `TodoFilterConditionsDO`）+ `fromJson`（未知键进 `unsupportedKeys`）；新增 `watchAll()` 与 `remove()`（删除走事务 + outbox `filter/delete`） |
| DI | `lib/state/providers.dart` | `filterRepositoryProvider`、`savedFiltersStreamProvider`（照 `tagRepositoryProvider` / `tagsStreamProvider` 的既有写法） |
| 映射 | `lib/features/filter/saved_filter_mapping.dart`（新） | `TaskFilter ↔ conditions` 双向 + 条件摘要。映射不下的维度回报 `skipped`；无法忠实还原时 `taskFilterFromSaved` 返回 null |
| 保存入口 | `lib/features/filter/filter_bar.dart` | 「保存为智能清单」→「保存为过滤器」，改写 `todoFilters`；对话框点名不保存的维度；`TaskFilter` 构造器加 `const` |
| 列表页 | `lib/features/filter/saved_filters_page.dart`（新） | 真列表 + 摘要 + 空态 + 错误态 + 二次确认删除 + 点行 pop `TaskFilter` |
| 套用 | `lib/features/home/home_shell.dart`、`lib/features/task/tasks_by_list_page.dart` | `SavedFiltersPage` 接进原 `_FiltersPage` 的位置；`_openFilters` 等 pop 结果存 `_appliedFilter`；面板加 `initialFilter`，`initState` 与 `didUpdateWidget` 都按它播种；切侧栏选择时清空 |

## 顺序

1. 先把 `_FiltersPage` **原样**搬成 public 的 `SavedFiltersPage`（内容仍是那 3 条假条目）并接进
   `home_shell` —— 这样红测能落在**断言层**（假条目还在、真数据没渲染），而不是「文件不存在」的编译错。
2. 补数据层与映射（`filter_repository` / `providers` / `saved_filter_mapping`）。
3. 写红测 `test/features/filter/saved_filters_test.dart`（8 条）→ 逐条失败信息指向缺失实现。
4. 实现列表页 / 保存入口 / 套用链路 → 全绿。
5. 六项门禁（`/tmp/gate-029.log`）→ 只读复核 → 回写 `tasks.md` 与矩阵 #22。

## 用例的判别性

- 有反向探针的（复核自己也复跑复现）：静态假条目换回 ⇒ 6 条红；保存改回 `saveSmart` ⇒ 用例 1 红；
  删掉 `skipped` 回报 ⇒ 「不静默丢条件」那条红；去掉删除钮的 `Semantics(label:)` ⇒ 读屏那条红。
- 本轮补上的路径用例（第一版只写了实现没测，复核指出后补）：
  pull 风格行 `statuses:["in_progress"]` 与带 `tagIds` 的行 → 标「本机暂不支持套用」且点不动；
  条件流失败 → 错误态；只剩存不下的维度 → 拒存且不留 outbox 记录。

- 「假条目消失」：`find.text('今日任务' / '已完成' / '已过期')` 必须 `findsNothing` —— 静态占位没被真数据
  换掉时这条红。
- 「不再造 smart 清单」：保存后断言 `todoLists` 里没有 `smart:` 前缀行 —— 走回旧 `saveSmart()` 时红。
- 「不静默丢条件」：断言的是整句「本过滤器不保存：文件夹、负责人」而不是子串 ——
  筛选条本身的「负责人」芯片也会命中子串，那样写等于没验（实测踩过，一次 `findsWidgets` 变成 2 命中）。
- 「套用真的改变了列表」：先断两条任务都可见，套用后断不匹配那条 `findsNothing`。
- 换页时重挂整棵树（不传 key 会复用 `State`、`initState` 不跑）；读屏断言用**前缀锚定**
  （`ListTile` 把 title+subtitle 合成一个节点，`^名称$` 必然 0 命中）。
- 删除按钮的读屏名必须自带 `Semantics(label:)`：`IconButton(tooltip:)` **不产出语义标签**，
  而放进 `ListTile.trailing` 又会被合并进整行 —— 两处都是实测出来的，最后落在「行外用 Row + 显式 Semantics」。

## 已知未覆盖（登记，不算已验）

- `home_shell._openFilters()` 那 6 行接线（等 pop → 存 `_appliedFilter` → 传给面板）没有被用例 pump 过
  `HomeShell` 直接验证；用例覆盖的是「页面 pop 出忠实的 `TaskFilter`」+「面板拿 `initialFilter` 会真的筛」。
- 保存 → 推送 → 另一台设备 pull 回来的跨端一致，需要 test 环境与第二台设备（外部条件）。
