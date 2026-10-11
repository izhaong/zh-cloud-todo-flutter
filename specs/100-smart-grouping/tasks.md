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
- [ ] T004 门禁：`flutter analyze` 全仓 0 issue + `flutter test` 全量
  （2026-10-12 实测，日志 /tmp/fl321-gate.log）
- [x] T005 `check_spec_selfscan.py` 单文件自扫：spec.md / tasks.md 失项 0 条（rc=0）
- [ ] T006 PR → 合并 develop → 关 #321 → 矩阵 #20 追记（docs PR）→ 父仓 bump
