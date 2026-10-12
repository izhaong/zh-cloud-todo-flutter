# Todo 倒数纪念日编辑与样式实施计划

规格见 [spec.md](spec.md)，任务见 [tasks.md](tasks.md)。

## 现状与最小改动面

- 契约层 `lib/core/api/efficiency_api.dart`：`CountdownApi` 增 `update` 与 `delete` 两个方法，载荷与 `AppTodoCountdownUpdateReqVO`/`@RequestParam id` 一一对应；`create` 补 `showAge` 已有但页面未传的参数，不新增字段。
- 装配层 `lib/state/efficiency_providers.dart`：沿用 `countdownApiProvider` 与 `countdownsProvider`，写操作成功后 `ref.invalidate(countdownsProvider)`，与 Timer 写路径同一套做法（参考 `specs/019` 的 `_saveTimerDraft`）。
- 页面层 `lib/features/countdown/countdown_page.dart`：由 `ConsumerWidget` 改为可持有 pending 状态的 `ConsumerStatefulWidget`；列表项加编辑/删除入口；新建与编辑共用一个表单体，避免两套字段漂移。

## 为什么不需要后端改动

`AppTodoCountdownController.java` 的 `update`（`:35`）与 `delete`（`:41`）端点、`AppTodoCountdownUpdateReqVO` 与 `style`/`showAge` 列均已存在且有 `todo_countdown` 表支撑，因此本切片是纯客户端接线，不触碰 Service 与 SQL。分组与背景图需要后端字段/存储，已划入边界之外。

## 风险

- 样式三档的视觉差异若做得过重会牵动黄金图基线；实现只在列表项 leading 与卡片装饰的既有布局槽位内区分，
  不新增页面与路由，若 golden 出现非预期差异则停下上报，不重录基线。
- 列表项从 `ListTile` 改为自建 `Row`：`ListTile` 会把 trailing 合并进整行的语义节点，编辑与删除
  无法各自保留可读屏语义（复核 1 发现的真实缺陷）。视觉槽位（leading / 标题 / 副标题 / 右侧动作）不变。
- `showAge` 文案改动会影响既有断言：`daysRemaining < 0` 的分支现被无条件显示为「已 N 天」，需同步核对该文案是否有现存用例依赖。
