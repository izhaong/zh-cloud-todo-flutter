# 推荐任务独立页 实施计划

## 现状与地基

- 取数链路已存在且不动：`RecommendationApi.list()` → `RecommendationRepository.refresh()` 整体替换 Drift 表
  `todo_recommendations`（带 `reasonCode`），`watchAll()` 按 `score desc` 出流；失败保留缓存。
- UI 已有 `features/home/recommendation_panel.dart`（工作区里只摊前 3 条），挂在 `home_shell.dart:664`。
- 四组判据由服务端给（`TodoHelpCenterService.java:173,176,179,183`），客户端不重算。

## 改动清单

1. 新增 `lib/features/home/recommendation_page.dart`：`RecommendationPage`（push 路由页）。
   按 `_recommendationGroups` 的固定顺序分组渲染，空组跳过；`DUE_SOON` 用 `dueAt` 拆明天/后天子档，
   拆不进的仍留在组内；行 = 标题 + 理由 + 「+」添加到今天 + 点行回调；刷新失败/添加失败各一条 live region；
   四组全空给「暂无推荐任务」。
2. `recommendation_panel.dart` 标题行加一个 `查看推荐任务` 动作，push 上面的页面，
   `onTaskSelected`/`onAddToToday` 原样转发（`home_shell` 零改动）。

## 关键取舍

- 流在 `initState` 里 `ref.read(...)?.watchAll()` 存字段：写在 `build` 里会逐帧造新流，
  `StreamBuilder` 反复退订/订阅，Drift 每次排一个 zero-delay 关闭定时器 ⇒ 页面永远 settle 不下来（实测整文件挂死）。
- 「+」在飞**只靠禁用态**（`onPressed: adding ? null : …`）挡重复点击：早退守卫经反向探针证明摘掉后用例仍绿，
  即它咬不住任何行为，已删。
- 页面自带刷新而不是复用面板的：两者生命周期不同（面板嵌在工作区、页面是 push 路由），
  共用 controller 要把面板已验收的 6 条用例一起改，收益不抵风险。
- 子档只做「即将到来」：其余三类的判据字段不在契约里，见 `spec.md` 与 izhaong/zh-cloud-service#271。

## 验证

- `test/features/home/recommendation_page_test.dart`：10 条用例 + 8 组反向探针（PA-PJ）。
- 六项门禁；黄金基线 9 张不重录（9 个场景都不 seed 推荐表 ⇒ 面板本身在基线里不渲染，
  `grep todoRecommendations test/support test/visual` 零命中）。
