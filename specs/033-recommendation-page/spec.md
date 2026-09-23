# 推荐任务独立页（嘀嗒《01-任务/05-推荐任务》）

## 嘀嗒原样（唯一口径，不自创交互）

帮助中心 `zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/05-推荐任务.md`：

- 入口：「今天」智能清单右上角的「推荐任务」（移动端在「💡」里）。
- 页面按**四类**分组展示：最近添加、多次修改时间、长时间未完成、即将到来。
- 每类下的子档（嘀嗒措辞）：
  - 最近添加 → 刚刚 / 今天 / 昨天
  - 多次修改时间 → 超过 5 次 / 超过 3 次 / 超过 2 次
  - 长时间未完成 → 超过 7 天 / 超过 14 天 / 超过 30 天
  - 即将到来 → 明天 / 后天
- 行右侧「+」= 添加到今天；点行本身进任务详情。
- 推荐范围：无重复、非今天的未完成任务。

## 现有落点（本规格的地基）

- 数据：`GET /app-api/todo/help/recommend-tasks`（`core/api/todo_api.dart` `RecommendationApi`）→
  `RecommendationRepository` 成功后整体替换 Drift 表 `todo_recommendations`（含 `reasonCode`），失败保留缓存。
- 服务端已给出嘀嗒四类对应的 `reasonCode`：`RECENTLY_ADDED`、`REPEATEDLY_RESCHEDULED`、
  `LONG_UNFINISHED`、`DUE_SOON`（`TodoHelpCenterService.java:173,176,179,183`）⇒ **分组不需要新端点**。
- UI：`features/home/recommendation_panel.dart` 只平铺前 3 条，**没有独立页**（矩阵 #11 的「仍缺」项）。

## 功能需求

- FR-1 独立页按嘀嗒四类分组，顺序固定为 最近添加 → 多次修改时间 → 长时间未完成 → 即将到来；
  分组依据是服务端的 `reasonCode`，不在客户端重新发明判据。
- FR-2 空组不渲染；四组全空时给可读的空态，不留一片空白。
- FR-3 「即将到来」再按 `dueAt` 拆 明天 / 后天 两个子档 —— 这是**当前契约唯一能算的**子档。
- FR-4 行右侧「+」= 添加到今天，复用面板同一动作语义（在飞禁用、失败保留该行、可重试）。
- FR-5 点行进任务详情，复用面板的 `onTaskSelected`（工作区内选中，不新起路由栈）。
- FR-6 入口在推荐面板自己的标题行上（新增一个动作），**不改侧栏、dock、清单列表布局**。
- FR-7 页面可刷新；刷新失败要说明且保留上一次成功结果，不清空已渲染的分组。
- FR-8 四件套：320px + 1.3 倍字体不溢出（档位要在页面自己的 context 上自检）、每组每行有独立可读屏语义、
  失败保留已加载数据、过期响应不覆盖新响应。

## 取舍与被否方案

- **子档只做「即将到来」**：其余三类的子档要 `createdAt` / `rescheduleCount` / `unfinishedDays`，
  `AppTodoRecommendTaskRespVO.java:10-31` 现在只有 `taskId/title/dueAt/reasonCode/reason/score`。
  被否的两条捷径：① 从 `score` 反推改期次数（`1000+min(次数,99)` 是服务端打分实现细节，分值一改就静默错分类）；
  ② 解析 `reason` 文案里的「已超过 14 天」（拿自然语言当判据）。两者都是客户端猜服务端语义，
  故按「先改契约再改客户端」开 izhaong/zh-cloud-service#271，本轮把这三个子档**记为仍缺**，不假装完成。
- **入口放面板标题行，不放开「今天」右上角**：嘀嗒桌面端确实在列表头部，但那里是已验收的可见布局，
  动它要重录 9 张黄金基线（需授权）。面板只在有推荐缓存时渲染，且 9 张黄金图里没有一个场景 seed 推荐表
  （`grep todoRecommendations test/support test/visual` 零命中）⇒ 加在面板内不可能改变基线，
  且 push 路由本身拍不到（仅 `mobile-detail` 例外）。被否：为「像素级照抄入口位置」去申请重录基线。
- **页面读本地缓存而不是直连接口**：与面板同源，离线可看上次结果；被否：页面自己 `RecommendationApi.list()`，
  那会绕开 outbox/缓存语义并产生两条取数路径。
- **`onTaskSelected`/`onAddToToday` 由面板转发，不改 `home_shell`**：两个回调面板已经持有；
  被否：在 `home_shell` 里为页面另接一遍，等于同一动作两处接线。

## 验证边界（诚实）

- 证据只来自 `flutter test` 的用例与反向探针 + 六项门禁日志；不含真机、不含远端 CI
  （runner `cgroup is not mounted`、Jenkins Job 不可达）。
- 「刚刚/今天/昨天」「超过 N 次」「超过 N 天」三类子档**未实现**，原因见上；矩阵 #11 行必须写成仍缺。
- 推荐内容由服务端决定，本地测试用 Drift 种子行 + 假 API，不声称验证过真实推荐算法。
