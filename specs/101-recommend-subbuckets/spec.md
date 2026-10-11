# Spec 101：推荐任务三组详情页子档（FL #553）

## 判据源

嘀嗒《推荐任务》（develop 镜像 `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/06-推荐任务.md`）：

- `:33`「你可以查看**刚刚**、**今天**、**昨天**添加、未设定时间的新任务」⇒ ⑥「最近添加」三档。
- `:40`「修改次数**超过 5 次**、**超过 3 次**、**超过 2 次**的任务」⇒ ⑦「多次修改时间」三档。
- `:48`「创建时间**超过 7 天**、**超过 14 天**、**超过 30 天**仍未完成的任务」⇒ ⑧「长时间未完成」三档。
- ③「即将到来」的 明天/后天 两档已由更早轮次落地（`recommendation-bucket-tomorrow`/`day-after`），本轮不动。

## 契约前提

service #271（PR !301，`86b26af3f5`）响应新增 `createdAt` / `rescheduleCount` / `unfinishedDays` 三个可空字段；
service #300（PR !352，`daa385c083b4`）把 LONG_UNFINISHED 准入降到 7 天并让 `unfinishedDays` 按 24 小时整日计。
本轮把三列接进 FL 全链：`RecommendationTask.fromJson` → Drift `todo_recommendations`（schema 27→28，三列可空、迁移不回填）→ `RecommendationRepository.refresh` → 页面分档。

## 分档规则（嘀嗒未定义边界的诚实登记）

- ⑥ 刚刚 = `createdAt` 在 1 小时内（**嘀嗒没定义「刚刚」的边界，1 小时是本端裁定**）；今天 = 同日历日但 ≥1 小时（与刚刚互斥）；昨天 = 昨天日历日；再早或 `createdAt` 为 null → 未分桶行。
- ⑦ `rescheduleCount` ≥6 → 超过 5 次；4–5 → 超过 3 次；3 → 超过 2 次；≤2 够不上任何一档（嘀嗒最低档就是「超过 2 次」）→ 未分桶行。
- ⑧ `unfinishedDays` ≥31 → 超过 30 天；15–30 → 超过 14 天；8–14 → 超过 7 天；≤7（准入 7 天整，刚好 7 天算不出「超过 7 天」）或 null → 未分桶行。
- 档序写死（⑥ 刚刚→今天→昨天、⑦ 5→3→2 次、⑧ 7→14→30 天，均按嘀嗒原文顺序），不跟 `score` 走；档内按分档原值降序（**嘀嗒没定义档内排序，本端裁定**）；「即将到来」保持服务端 score 序。
- 三组的分节形态与 ③ 的 明天/后天 完全同构：桶头独立 key `recommendation-bucket-<keyName>` + `Semantics(header: true)`，未分桶行仍渲染在组内。

## 形态差异（不算缺）

嘀嗒入口是「今天」智能清单的「💡」-「推荐任务」详情页；本端仍是工作区推荐面板头部 push 的独立页（既有形态差异，矩阵 #11 已登记），本轮只补子档，不改入口。

## 测试

- 页面 3 个新用例（⑥ 档序不跟 score + 未分桶行、⑦ 三档 + 改 2 次未分桶、⑧ 三档 + 档内降序 + 档头 header）。
- 仓储 2 个新用例（三列 round-trip、`fromJson` epoch 毫秒与缺列兜底）。
- 迁移 1 个新用例（v27→v28 三列、存量行 null 不回填，`_downgradeToSchema27WithoutRecommendationContractColumns` 降级辅助）。
- 变异探针 4 条证红还原：⑥ 档序互换、⑦ 门槛 6→9、⑧ 档界 31→25（31→26 不跨测试行，第一次探针假绿已换）、⑧ 档内排序短路。
- 门禁：`flutter analyze` 0 issue + `flutter test` 全量（结果记在 tasks.md T004）。
