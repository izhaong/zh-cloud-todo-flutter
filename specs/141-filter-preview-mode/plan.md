# 141 实施计划：高级筛选的「预览模式」

## 落点

| 文件 | 改什么 |
| --- | --- |
| `lib/features/filter/filter_bar.dart` | `FilterBar` 多一个可选入参 `previewResolver`；新增私有 `_draftFilter`（草稿 → 完整 `TaskFilter`）；「高级筛选」对话框加「预览模式」开关与预览区；`应用高级筛选` 的 `onChanged` 改走 `_draftFilter` |
| `lib/features/task/tasks_by_list_page.dart` | `FilterBar(...)` 注入 resolver：`(next) => applyTaskFilter(tasks, next, _selectedListId, ref.read(currentDateTimeProvider)())`，`tasks` 就是 `_openFilterPanel(raw)` 手里那份未过滤列表 |
| `test/features/filter/filter_advanced_preview_test.dart` | 三条用例（默认关 / 只列命中且不套 / 关掉再打开草稿仍在） |

## 为什么是"注入 resolver"而不是在 `filter_bar.dart` 里直接算

`applyTaskFilter` 是 `tasks_by_list_page.dart` 的顶层函数，而页面已经 `import '../filter/filter_bar.dart'`。
反向 import 会成环。注入还顺带把"预览与列表同源"这件事写在了**渲染列表的同一处**：
页面自己就是 `applyTaskFilter(raw, _filter, _selectedListId, now)`（`:177`）的调用者，
预览闭包用的正是同四个入参口径。

## 单一事实源

`_draftFilter` 同时被两处用：预览（对话框每次重算）与 `应用高级筛选`（pop 之后 `onChanged`）。
不各写一份 `copyWith` ⇒ 不会出现"预览说命中 3 条、套上变 5 条"。

## 步骤

1. 红测：三条用例先行（缺开关 ⇒ `findsOneWidget` 红）。
2. 最小实现：入参 + 开关 + 预览区 + `_draftFilter`。
3. 反向探针（每条都要变红，且还原后 `cmp` 干净）：
   - PA 预览永远不算 → 「只列命中项」「草稿仍在」两条应红；
   - PB 预览忽略用户输入的关键词 → 同上两条应红；
   - PC 默认就开着预览 → 「默认关 / 关时不显示预览区」应红。
4. 六道门禁 + 台账自扫 + 只读复核 `VERDICT`。

## 不动的东西

- `applyTaskFilter` 本体、`_AdvancedFilter` 的返回结构、`保存为过滤器` 的多余维度提示。
- 高级筛选原有的日期校验（`请输入有效日期` / `起不能晚于止`）——预览只在日期档可解析时才算，
  不可解析时明写「日期无效，未预览」，不静默给一个错的数。
