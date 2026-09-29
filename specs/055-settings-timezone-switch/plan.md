# 实施计划：设置里的「日期与时间 → 时区」总开关（specs/055 / FL Issue #368）

## 一、落点（四处，全在客户端；不动 SQL、不动后端契约、不新增依赖）

| 落点 | 做什么 | 为什么是这里 |
| --- | --- | --- |
| `lib/state/repositories/timezone_preference_repository.dart`（新增） | `DATE_TIME` + `timezone` 一行的 `get/watch/setEnabled`，写后置入 outbox | `todo_view_preferences` 是仓内既有偏好表，`task_sort_preference_repository.dart` 与 `task_capture_defaults_repository.dart` 已经是这个形；新表要动 SQL ⇒ 越界 |
| `lib/state/providers.dart` | `timezonePreferenceRepositoryProvider`（可空）+ `timezoneEnabledProvider`（`StreamProvider<bool>`，无库时 `Stream.value(true)`） | 与仓内其它 `*RepositoryProvider` 同一写法；无库=未就绪时按「开」，与仓储"无记录即开"同口径 |
| `lib/features/settings/settings_route.dart` | 新 `_Section('日期与时间')` + `_TimezonePreferenceTile`（`SwitchListTile`，`ValueKey('settings-timezone-enabled')`） | 设置页就是 `_Section` + 卡片分组，跟着长；不新增 push 路由 |
| `lib/features/task/task_detail_pane.dart` | 提醒编辑器里「固定时区」那一档按偏好显隐 | 嘀嗒《01-任务/07-固定时间与固定时区》:11 的"开启后才能选"就落在这条 `SwitchListTile(key: 'task-reminder-fixed-timezone')` 上 |

## 二、顺序（红 → 最小实现 → 门禁）

1. 先写仓储侧红测（R1/R2，真 in-memory Drift）：无记录即「开」、只占一行、入队 `view_preference`、切开关不动任务字段。
2. 写设置页红测（W1–W5，见「三」的取舍）→ 落实现。
3. 写 FR-2 红测（提醒编辑器显隐）→ **这条真的把实现判红了一次**（见 `tasks.md` 的红测记录），修成 `await ref.read(...future)`。
4. 六道门禁跑在**已提交终态**上（`pubspec.lock` 会被 `flutter test` 重写，所以门禁一定在 commit 之后跑）。

## 三、两条会咬人的设计决定（细节见 `spec.md` 五、六）

- **状态读法**：`_showReminderEditor` 打开弹窗前 `await ref.read(timezoneEnabledProvider.future)`，
  不读 `valueOrNull`。后者在 provider 首帧是 `AsyncLoading` ⇒ `?? true` ⇒ "关掉到底有没有效"取决于手速。
- **读屏状态**：判据用 `getSemantics(f).getSemanticsData().flagsCollection.isToggled`（正反两条）。
  ⚠️ 这里返过工：先按 `SemanticsNode.flagsCollection` 读到 `none` 就下了「状态位到不了读屏」的结论、
  并给标题加了 `semanticsLabel`；复核 F-1 指出平台吃的是 `getSemanticsData()` 那份，`Switch` 的
  `toggled` 本来就出得来 ⇒ 自创文案已撤回。见 `tasks.md` 三-3。
- **写偏好整段包 `_db.transaction`**：`{sourceType, sourceKey}` 上有 UNIQUE 索引，
  「读 → 插」不在事务里时并发写会撞 `2067` 并丢最后一次意图（复核 F-2 实测）。
  仓内先例 `task_sort_preference_repository.save()` 本来就是包事务的 —— 抄形要抄整段。

## 四、风险与不做的事

- 不做「固定时间」档（FR-6）：需要逐任务三态模式位 ⇒ 先补 service 契约，已另立 FL #369。
- 不重录黄金基线：本次只在设置页**新增**一节；设置页不在 9 张基线里（`flutter test --tags golden` 的读数会证实这点）。
- 不碰 `task_time_formatter.dart`（FR-5）：数据还在就该照旧渲染「`<IANA> 固定时区`」。
