# Tasks 100：智能分组（六维档位）

- [x] T001 摸底：任务列表页结构（`TasksByListPage`/`_ListBody`/`TaskGroupHeader`）、
  `TaskSortPreferenceRepository` 偏好模式、`assigneeUserName`/标签映射数据面、
  六维可纯客户端实现确认
- [x] T002 实现：`lib/features/task/smart_grouping.dart` 引擎（六维 + 嘀嗒桶名 +
  空桶省略）、`task_grouping_preference_repository.dart`（TASK_GROUP 偏好 +
  outbox 入队）、`task_workspace_header.dart` 分组菜单、`tasks_by_list_page.dart`
  接线（恢复/保存 + 组渲染 + 行 key 带组 id）
- [x] T003 测试：引擎 10 用例 + 偏好仓 3 用例 + 页面 6 用例全绿；
  两处变异探针证红还原；红测抓到并修复 GlobalKey 撞车缺陷（见 spec.md）
- [x] T004 门禁：`flutter analyze` 全仓 0 issue + `flutter test` 全量
  （2026-10-12 实测，日志 /tmp/fl321-gate2.log；首跑 7 张 workspace golden 红，
  isolatedDiff 确认差异仅头部新按钮，重录后全绿）
- [x] T005 `check_spec_selfscan.py` 单文件自扫：spec.md / tasks.md 失项 0 条（rc=0）
- [x] T006 收口全链完成（2026-10-12）：PR !550 合并 develop（`aaec68166517`）→
  #321 关单（收口留言 id 13316）→ 矩阵 #20 翻「有」（docs PR !179，develop
  `9ce1e409c96e`，缺口 58→57）→ 父仓双指针 bump（FL `aaec68166517` + docs
  `9ce1e409c96e`，见父仓 develop 本轮 chore 提交）
