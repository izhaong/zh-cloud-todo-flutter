# Tasks 101：推荐任务三组详情页子档

- [x] T001 契约接线：`RecommendationTask` 加 `createdAt`/`rescheduleCount`/`unfinishedDays`
  （fromJson 按 epoch 毫秒或字符串解析，缺列为 null）；Drift `todo_recommendations` 加三列
  + schemaVersion 27→28 + `from < 28` 迁移（`_columnExists` 守卫、不回填）；
  `RecommendationRepository.refresh` 落三列；build_runner 重生成 `app_database.g.dart`
- [x] T002 测试先行：页面 3 用例（⑥⑦⑧ 分档 + 档序不跟 score + 未分桶行 + ⑧ 档内降序 +
  档头 header）先红（实现前 `-3`，恰好只红 3 个新用例）；仓储 2 用例 + 迁移 1 用例
- [x] T003 实现分档：`_recentlyAddedBucketOrder`/`_rescheduledBucketOrder`/
  `_longUnfinishedBucketOrder` 三张顺序表 + `_bucketOrderFor`/`_bucketLabel` 四组分档
  判定 + `_buildGroup` 泛化（DUE_SOON 特判删除，四组统一走 sections + unbucketed）+
  `_sortedBucketMembers` 档内原值降序（DUE_SOON 除外）
- [x] T004 门禁：4 条变异探针证红还原（⑥ 档序互换、⑦ 门槛 6→9、⑧ 档界 31→25、
  ⑧ 档内排序短路；31→26 首跑假绿——不跨测试行，换 25 后红）；`flutter analyze`
  全仓 0 issue；`flutter test` 全量通过（2026-10-12 实测，日志 /tmp/fl553-gate.log）
- [x] T005 `check_spec_selfscan.py` 单文件自扫：spec.md / tasks.md 失项 0 条（rc=0）
- [ ] T006 PR → 合并 develop → 关 #553 → 矩阵 #11 翻「有」（⑥⑦⑧ 齐）→ 父仓 bump
