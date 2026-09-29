# 069 · 标签维度真正参与筛选求值（FL Issue #417）

## 一、判据源（逐字，zh-cloud-docs 镜像）

`todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md`

- `:6`「在建立任务的时候，要尽可能的为任务添加「时间」、「标签」、「优先级」等属性，方便过滤器进行多维度筛选。」
- `:50`「按照清单名称、标签、日期等属性进行多维度筛选，还可以按照关键词做内容筛选。」
- `:71`「你还可以使用“且”逻辑、“或”逻辑来关联前后两个筛选条件。并且，在同一个筛选条件（仅标签支持）内，也可以选择使用“且”逻辑、“或”逻辑。」

术语照抄：本文只说「标签」「筛选条件」「“且”逻辑 / “或”逻辑」，不自创"标签组/交集/并集"这类同义词。

## 二、实现前的事实（每条带命令，基准 FL `origin/develop@5a831a1`）

| # | 主张 | 复算命令 |
| --- | --- | --- |
| 1 | `applyTaskFilter` 里**没有标签分支**（连“且”都没有） | `git grep -n 'filter\\.tagIds' origin/develop -- lib/features/task/tasks_by_list_page.dart` ⇒ 0 命中 |
| 2 | 因此带标签的已存过滤器被标成「不支持套用」 | 读 `lib/features/filter/saved_filter_mapping.dart:46-48`（`if (conditions.tagIds.isNotEmpty) return null;`） |
| 3 | 取标签只有逐条法，批量会 N+1 | `git grep -n 'Future<List<String>> tagIdsOf' origin/develop -- lib/state/repositories/tag_repository.dart` ⇒ 命中 `:153`；无批量法 |
| 4 | 服务端的缺省口径是「且」 | zh-cloud-service `origin/develop` `dal/dataobject/filter/TodoFilterConditionsDO.java:61-62`（`LOGIC_AND = "and"`、`LOGIC_OR = "or"`） |

## 三、决定

1. **本轮只做 `:50` 的「标签参与多维度筛选」+ 缺省“且”**。`:71` 的“或”与跨条件布尔组合是 FL Issue #334，不在这里顺手开口子——`TaskFilter` 本轮**不加** `tagLogic` 字段，避免留一个没人消费的半截契约。
2. **缺省按“且”**：任务标签是所选标签的超集才算命中。理由是第 4 条（服务端把缺省定为 `and`），客户端自创“或”会让本机预览与服务端保存后的结果不一致。
3. **索引一次取全表**：新增 `TagRepository.watchTagIndex()`（Drift `watch()`，标签绑定变更会自动重发），provider `taskTagIndexProvider` 供列表与预览同源消费；不引入逐任务查询。
4. **索引没就位时不假装过滤**：带标签条件而索引为 `null` 时列表画加载指示，预览给空图（报 0 项）。宁可"看不出来"也不画一份标签没参与的列表——那正是 #417 原本的病症。
5. **流出错保留上一份好数据**：`StreamProvider` 出错时 `valueOrNull` 仍留最后一次的索引，不因为读失败把已加载任务清空。

## 四、四件套

本轮**不新增界面、不改任何 widget 的视觉结构**（只在既有 builder 里加一个提前 return 的加载分支），所以 ①（320px + 1.3 倍字号）与 ②（独立读屏语义）在本轮无新增承载体，判「不适用」并留下面两条实测：

| 项 | 结论与证据 |
| --- | --- |
| ③ 失败保留已加载数据 | 决定 5：索引流出错 ⇒ `valueOrNull` 留旧索引，列表不清空；用例见 `test/features/filter/task_filter_tag_logic_test.dart` 第 3 条（映射缺失不得改变其余维度的结果） |
| ④ 过期响应不覆盖新响应 | `watch()` 的发射顺序天然后到覆盖先到；列表与预览读的是同一个 provider 实例（`ref.watch` 与 `ref.read`），不存在两处各算一份索引的可能 |

## 五、仍缺（下一轮入口）

- `:71` 的“或”逻辑（同一标签条件内 + 跨筛选条件）与「多语句查询」= FL Issue #334；`TaskFilter` 需要 `tagLogic`，`savedFilterOf` 要往契约里写 `tagLogic`/`conditionLogics`（值用小写 `and`/`or`）。
- 高级筛选 sheet 里目前没有“且/或”控件；加控件就要重跑 golden（9 张基线，侧栏/筛选条都在图里）⇒ 触碰前先确认是否需授权重录基线。
- 矩阵 `#21/#22` 的 FL 面证据本轮只推进"标签维度生效"这一格；翻转只在合并后引 SHA。
