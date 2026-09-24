# 037 习惯详情页与「...」管理（编辑 / 删除）

## 来源（唯一事实源，逐行引用）

`zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/05-习惯打卡/`

| 出处 | 原文摘录 | 本单取什么 |
| --- | --- | --- |
| `01-开始坚持一个习惯.md:58` | 「点击习惯进入详情页，点击右上角「...」，可进行编辑、开始专注、分享、归档或删除等操作。」 | 交互骨架：详情页是「...」菜单的宿主；本单只做其中的**编辑**与**删除** |
| `01-开始坚持一个习惯.md:75` | 「可以填写习惯名称、选择图标，还能根据情况写点鼓励自己的话」 | 编辑表单项：名称、图标 |
| `01-开始坚持一个习惯.md:85` | 「你可以在「编辑习惯」频率中设置」 | 编辑表单有「频率」一项 |
| `01-开始坚持一个习惯.md:95` | 「在建立习惯时，「目标」中选择「当天完成一定量」设置」 | 编辑表单有「目标」一项 |
| `02-更好地完成习惯.md:40` | 「可以根据自己完成习惯的时间来设置提示…到点都会自动提醒」 | 编辑表单有「提示」一项（契约只有单个 `reminderAt`，见 FR-3 边界） |
| `02-更好地完成习惯.md:122` | 「删除：习惯将被永久移除，所有打卡记录也会被清空，无法恢复。」 | 删除确认文案的措辞 |

术语照抄：「习惯」「编辑」「删除」「频率」「目标」「提示」。不引入「重命名」「移除」「周期」「次数」等同义词。

## 用户故事

作为使用移动端 App 的用户，我希望点击一个习惯进入它的详情页，并通过右上角「...」编辑该习惯或把它删除，以便我建错的习惯能改、不做的习惯能清掉——而不是像现在这样只能建不能管。

## 现状（本单开工前的证据，全部来自 `origin/develop` a1d7733）

- `lib/features/habit/habit_page.dart`：列表卡片 + 行内「打卡」按钮。全文 225 行内 `Navigator.push` **0 次**、`PopupMenuButton` **0 次**、「编辑」**0 次**、「删除」**0 次**。
- `lib/features/habit/habit_repository.dart`（155 行）只消费 4 个端点：`/habit/page`、`/habit/create`、`/habit/check-in`、`/habit/stats`。
- 后端 `zh-cloud-service@48f1e4db60`（Gitea `origin/develop`）的 `AppTodoHabitController` 已提供 7 条路由（`grep -cE "@(Get|Post|Put|Delete)Mapping"` = 7：create/update/delete/get/page/check-in/stats），其中 `/update`、`/delete`、`/get` 客户端一条都没接；`AppTodoHabitBaseVO` 已支持 `name/icon/color/period/targetCount/reminderAt/sortOrder`。
- 结论：**这是纯客户端接线，不需要动契约**（规则 5 不适用）。

## FR（功能需求）

- **FR-1 详情页可达**：列表项可点击，进入 `HabitDetailPage`，标题为该习惯名称（嘀嗒 :58「点击习惯进入详情页」）。
- **FR-2「...」菜单**：详情页右上角有一个「...」按钮，展开后含「编辑」「删除」两项。本单**不含**「开始专注」「分享」「归档」——归档契约未合并（见下方边界），专注/分享属其它功能。
- **FR-3 编辑**：编辑弹层字段与 `AppTodoHabitBaseVO` 已支持的能力一一对应——名称（必填）、图标、颜色、频率（每天 / 每周 / 每月）、目标次数、提示时间。提交走 `PUT /app-api/todo/habit/update`，请求体必须带 `id`。
  - 边界①（不发明）：契约里 `reminderAt` 是**单个** `LocalDateTime`，嘀嗒 :40 允许多个时间点（9:00、12:00、18:00、21:00）。本单只落**单条提示**，多时间点属契约缺口，另开 Service 单。
  - 边界①-b（复核 NIT 后补，别再当它不存在）：契约这一列是**绝对时点**（日期 + 时分），嘀嗒的「打卡提示」是**每天重复**。本单 UI 只在 `showTimePicker` 里收时分，日期取「已有值或今天」（`habit_editor.dart` 的 `base = _reminderAt ?? now`）⇒ 库里的日期对「每日重复」这个语义没有意义，且**目前没有任何通知投递消费它**（全仓 `reminderAt` 只有 UI 读）。要真正对齐嘀嗒，需要 Service 侧把这一列改成「每日时间」语义或加重复规则；本单只到「存的值可回显」为止。
  - 边界②（**本单实证的契约缺口，已自查源码**）：`TodoHabitServiceImpl.java:55-66` 的 `updateHabit` 是「取旧行 → 逐列 set → `updateById`」，而 `TodoHabitDO.java` 的 `icon/color/reminderAt/sortOrder` **没有任何** `@TableField(updateStrategy = ...)` 注解，`yudao-server/src/main/resources/application.yaml:55-66` 的 `mybatis-plus.global-config.db-config` 也**没有** `update-strategy` 覆盖 ⇒ 走 MyBatis-Plus 默认 `NOT_NULL`，**传 null 不会写进 SET 子句**。因此「清除提示 / 取消图标」在当前契约下必然静默失败。本单的编辑**只提供设置与修改，不提供清除入口**（给了就是一个点了没坏的按钮）；已按规则 5 在 Service 侧开单补 `FieldStrategy.ALWAYS`，见 tasks.md。
  - 契约没有「鼓励自己的话」/描述列（`TodoHabitDO` 字段仅 id/userId/name/icon/color/period/targetCount/reminderAt/sortOrder/archived），故本单**不做**描述字段——宁缺勿造。
- **FR-4 删除**：点「删除」先二次确认，正文取嘀嗒 :122 的措辞；确认后走 `DELETE /app-api/todo/habit/delete?id=`，成功后返回列表并把该习惯从列表中移除。取消则不发请求。
- **FR-5 新建补齐**：`create` 与 `update` 共用同一份字段（名称/图标/颜色/频率/目标/提示），新建习惯不再只有名字。
- **FR-6 时间字段的 wire 形状修正（本单实证）**：`zh-cloud-service` 全局把 `LocalDateTime` 注册成 **epoch 毫秒** —— `YudaoJacksonAutoConfiguration.java:52-53`（`TimestampLocalDateTimeSerializer`/`TimestampLocalDateTimeDeserializer`），反序列化器实现是 `LocalDateTime.ofInstant(Instant.ofEpochMilli(p.getValueAsLong()), systemDefault())`（`yudao-framework/yudao-common/.../TimestampLocalDateTimeDeserializer.java`）。同仓其它调用点也确实按毫秒上送（`state/repositories/task_repository.dart:1063`、`core/api/todo_api.dart:580-582`）。
  而 `habit_repository.dart` 现在把 `checkedAt` 拼成 ISO 字符串 `'2026-07-30T08:00:00.000'` 上送 ⇒ **形状与契约不符**。本单把习惯家族（`checkedAt`、`reminderAt`）统一改为 epoch 毫秒，并修正 `test/efficiency_api_contract_test.dart:357-359` —— 那条断言把错误的 wire 形状钉成了"契约"。
  诚实边界：发 ISO 字符串时服务端**具体**落成什么值未实测（本机想用 jackson-core 3.1.5 直接复现 `getValueAsLong()` 对 `VALUE_STRING` 的行为，两次都没编译过，未跑通）。但无论退化成 1970 还是报错，都不是期望值 —— 结论不依赖这个未知数。真机验证需要能登录 test 的设备，属已知硬阻塞。

  同族漏网（复核 NIT 后补，别当它是孤例）：`grep -rn toIso8601String lib/` 仍有 **21 处**，按文件分布 `repeat_rule_repository.dart` 4、`task_repository.dart` 3、`core/api/efficiency_api.dart` 3、`reminder_repository.dart` 2、`todo_api.dart` 2、`task_search_page.dart` 2、`filter_bar.dart` 2、`native_entry_page.dart` 1、`list_page.dart` 1、`sync_coordinator.dart` 1。**其中哪些是「上送服务端 LocalDateTime」、哪些只是本地展示/游标格式化，尚未逐处判定**（`filter_bar.dart`、`task_search_page.dart` 看着就是展示）⇒ 另开单逐处判，本单只收习惯家族。

## 边界与明确不做（含被否方案）

| 项 | 决定 | 理由 |
| --- | --- | --- |
| 归档 / 恢复 | **不做** | `PUT /habit/{id}/archived` 只存在于 zh-cloud-service **未合并** 的 PR !276（本地校验：`git show origin/develop:...AppTodoHabitController.java` 的 8 条路由里没有它）。客户端现在调就是线上 404。合并后另开单接。 |
| 打卡方式三档（自动记录 / 手动记录 / 完成全部） | **不做** | 嘀嗒 `02-更好地完成习惯.md:5-30`；`TodoHabitDO` 无对应列 ⇒ 契约缺口，按规则 5 先在 Service 加字段。 |
| 打卡日志开关、打卡分组（上午/下午/晚上/其他）、打卡样式（对勾/打卡图标） | **不做** | 同上，`02-更好地完成习惯.md:60,97,112`，均无列。 |
| 删除级联打卡记录 | **不做（契约缺口）** | 嘀嗒 :122 说删除会清空打卡记录，但 `TodoHabitServiceImpl.java:70-74` 只有 `habitMapper.deleteById(...)`，`TodoHabitCheckInMapper` 没有按 `habitId` 删除的方法；且 `deleted` 走 `@TableLogic` 是逻辑删除。确认文案照抄了嘀嗒 ⇒ 在本条结掉前，那句「所有打卡记录也会被清空」对外不成立。已开 `zh-cloud-service#277`。 |
| 月度打卡表 / 补记打卡 | **不做** | `/habit/stats` 的 `dailyCounts` 可支撑，但它是另一个表面；本单只做嘀嗒 :58 那一条菜单。留下轮入口。 |
| 把「编辑 / 删除」做成列表项长按菜单 | **否** | 嘀嗒明确是「点击习惯进入详情页，点击右上角「...」」。北极星禁止自创交互。 |
| 在 `HabitPage` 的 AppBar 放「...」 | **否** | 帮助文档的「...」属于**习惯详情页**（单个习惯的动作），页面级 AppBar 语义是列表级的，会与管理已归档等混淆。 |
| 用 `/habit/get` 拉详情 | **否** | 详情页字段列表接口已全部返回；多一次请求只增加失败面。与 `zh-cloud-client` 无关（该端已废弃，不作证据）。 |

## 验收标准

1. `test/features/habit/habit_detail_page_test.dart` 全绿，且逐条反向探针能证明「摘掉生产代码 → 对应用例红」。
2. 请求形状断言：`PUT /app-api/todo/habit/update` 的 body 含 `id` 与六个可编辑字段；`DELETE /app-api/todo/habit/delete` 的 `queryParameters['id']` 命中该习惯 id。
3. 四件套：详情页与编辑弹层在 320px + 1.3 倍字体下不溢出（档位各用自己的 context 复检）；「...」菜单项有独立可读屏语义；编辑/删除失败时列表已加载数据保留且提示可见；编辑弹层「在飞」期间二次提交不重复发请求。
4. 六项门禁日志齐全；一轮只读 `VERDICT`。
5. 矩阵 #43/#44 行补 `文件:行号` 证据；PR 未合并前状态写「已实现待合并」，不翻「有」。

## 非目标

不改 `HabitPage` 的统计卡与列表布局（避免动 9 张黄金图基线；`grep -c 习惯 test/visual/todo_workspace_golden_test.dart` 判据见 tasks.md）；不做 native 通知投递（提醒时间只入契约，真机投递受「无第二台可登录 test 的真机」阻塞）。
