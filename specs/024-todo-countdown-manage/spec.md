# Todo 倒数纪念日编辑与样式规格

**Issue:** 待创建
**状态：** 规格已冻结，实现未开始。

## 目标

让 `倒数纪念日` 模块达到嘀嗒清单「管理倒数纪念日 + 打造专属纪念页」中可离线自足的那部分：用户能**修改**和**删除**已建的倒数日，并让服务端已有的 `style`（样式）与 `showAge`（显示已过天数）真正生效。

现状缺口（`specs` 第 0 轮对账结论，矩阵行 #49）：`CountdownApi` 只有 `list()`/`create()`（`lib/core/api/efficiency_api.dart:901-939`），页面只有列表与新建（`lib/features/countdown/countdown_page.dart`，117 行），而服务端 `AppTodoCountdownController.java:35/41` 的 `update`/`delete` 端点已经存在但无人调用；`CountdownDto` 已解析 `style`/`showAge`/`backgroundImage`（`efficiency_api.dart:296-322`）但 UI 全不消费，卡片底色硬编码 `Colors.blue`。

## 可验收行为

- FR-001 列表项可进入编辑：预填名称、目标日期、样式与显示已过天数；保存只在 API 成功后刷新列表，失败时保留当前列表并给出可重试反馈。
- FR-002 删除必须先二次确认；确认成功后刷新列表，失败时该项仍在列表中且不产生本地不一致状态。
- FR-003 样式取嘀嗒的三档并保持同一措辞与取值：`1=默认`、`2=翻页`、`3=圆环`（服务端 `AppTodoCountdownBaseVO.style` 注释为唯一取值源）。列表项的呈现必须随样式可辨地变化，新建与编辑均可选择，缺省为 `1`。
- FR-004 `showAge` 开启时，已过期的倒数日显示“已过 N 天”；关闭时过期项只显示目标日期，不再出现 `还有 -N 天` 这类负数文案（当前页面在 `daysRemaining < 0` 时会显示 `已 N 天`，与本条统一为受 `showAge` 控制）。
- FR-005 契约严格对齐服务端而不越界：`PUT /app-api/todo/countdown/update` 载荷为 `{id, name, targetDate, style, showAge}`（`AppTodoCountdownUpdateReqVO` = `AppTodoCountdownBaseVO` + `@NotNull id`，其中 `name` `@NotBlank`、`targetDate` `@NotNull`）；`DELETE /app-api/todo/countdown/delete?id=...`。不发送未定义字段，不新增本地字段。
- FR-006 320px 视口与 1.3 倍字体下无布局溢出；编辑与删除入口各自具备独立、可读屏的语义名称。

## 边界

- 不做 `backgroundImage` 上传与展示：需要对象存储与上传通道，属独立规格。
- 不做嘀嗒的“显示分组”（倒数日/纪念日/生日/节日）：服务端 `TodoCountdownDO` 无类型字段，需先改 SQL 与契约。
- 不引入 Drift 本地缓存与 outbox：倒数日现状是直连 `/app-api/todo/countdown`，本切片不改变该数据通路。
- 不做倒数日提醒推送、农历、重复年纪念。
- 不改动 `specs/002-todo-visual-fidelity/` 已批准的黄金图基线。

## 验证边界

- 契约测试用 `Dio` + `InterceptorsWrapper` 拦截请求（沿用 `test/efficiency_api_contract_test.dart` 既有写法），断言方法、路径与载荷；不访问真实后端。
- Widget 测试注入可编程的假 `CountdownApi`，覆盖编辑保存、失败保留、删除确认与取消、样式与 `showAge` 呈现、320px 无溢出。
- 真机上与嘀嗒逐屏比对视觉与措辞不在本切片结项条件内，需人工验收后另行登记。
