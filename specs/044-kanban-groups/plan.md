# 044 实施计划

本轮范围 = 判定 + 注释纠错，无行为改动。

1. 读源页，摘出 `:14`/`:64`/`:99`-`:101`/`:108`/`:115` 五面原文 —— 验证：`spec.md` 的引号内文本可在源页逐行命中（python 扫 `02-看板视图：分类管理任务.md`）。
2. 用 `git grep -n -e 管理分组 -e boardGroup -e board_group origin/develop -- lib` 判「管理分组」是否已存在 —— 验证：命中 1 处（`tasks_by_list_page.dart:1849`），并把周边 `:1829`-`:1862` 读出来确认它确实是分组 CRUD。**这一步推翻了"缺契约"的初判。**
3. 纠正 `kanban_view.dart` 文件头里与代码矛盾的注释 —— 验证：`git diff` 只落在 `///` 行；六项门禁全跑一遍（无行为改动仍按规矩跑，不省略）。
4. 撤回 `zh-cloud-service` Issue #282（评论说明错在哪 + 关闭）—— 验证：`GET /repos/izhaong/zh-cloud-service/issues/282`
   返回 `state=closed`、`is_pull=null`、`comments=1`、`updated_at=2026-09-24T10:37:39Z`（2026-09-24 本机复核）。
5. 下一轮（044 的后半）：把 `KanbanView` 的列定义接到 `TodoTaskSection`（列名=分组名、顺序=分组 sort、列集合=分组集合、拖到"未分组"的落库语义），先红测再实现，四件套补齐。
