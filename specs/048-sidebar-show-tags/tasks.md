# 048 · 任务清单（Issue #328 / 矩阵 #21）

分支 `feat/328-sidebar-show-tags`，基准 `origin/develop@9032005`。

## 实现

- [x] `SidebarVisibilityRepository`（`get/watch/save`，`SIDEBAR_VISIBILITY` + `global`，`viewPreference` outbox）
- [x] `sidebarVisibilityRepositoryProvider` / `sidebarShowTagsProvider`
- [x] 侧栏 `tagEntries` 门控（`lib/features/shell/sidebar.dart:70-82`）
- [x] 设置 →「智能清单」→「标签」行 + 显示/隐藏选项弹层（`settings_route.dart:137-158`、`_pickShowTags`）
- [x] `_Tile` 支持 `super.key` 与 `trailingText`（取值用文字而非勾，读屏同源）

## 验收（本轮新增 14 条用例，`flutter test` 实测全绿）

| FR | 用例 | 文件 |
| -- | ---- | ---- |
| FR-1 默认显示 | `默认值必须是「显示」…` | `test/sidebar_visibility_repository_test.dart` |
| FR-1 关掉就没 / 再开回来 | `侧栏标签条目跟着「显示标签」走：默认在、关掉就没、再打开又回来` | `test/features/shell/sidebar_show_tags_test.dart` |
| FR-1 取舍 1（入口行不收） | 同上第 3 条断言 `todo-sidebar-row-tags` 仍 `findsOneWidget` | 同上 |
| FR-1 读不到偏好不清空 | `偏好读不到时侧栏按默认「显示」处理…` | 同上 |
| FR-1 实时生效 | `watch 在写之后立刻推新值，侧栏不必重进` | 仓库层文件 |
| FR-2 一次点击写库 / 点回也写回 | `设置 →「智能清单」→「标签」：一次点击选「隐藏」就写库…` | `test/features/settings/sidebar_show_tags_settings_test.dart` |
| FR-2 取消不写 | `打开弹层后不选直接关掉：不写库、取值不变` | 同上 |
| FR-3 跨重启 + outbox | `保存「隐藏」落同一行、入 outbox，重开库仍读得到` | 仓库层文件 |
| FR-3 服务端包装可读 | `同步拉回的服务端包装格式要能读出来…` | 仓库层文件 |
| FR-4 默认值不动黄金基线 | `默认值必须是「显示」…` + 黄金门禁 ④ 未重录 | 仓库层文件 + 门禁 |
| FR-5 读屏 | `取值由这一行自己的读屏语义念出来，不是只画一个勾` | 设置文件 |
| FR-5 失败保留 | `写入失败时给出可见提示，取值与库里的值都保持原样` | 设置文件 |
| FR-5 320px + 1.3 | `320px + 1.3 倍字号：设置行与选项弹层都排得下…`、`320px + 1.3 倍字号下「显示」与「隐藏」两种侧栏都不溢出` | 设置 / 侧栏文件 |

## 四件套（新增界面 = 设置里那一行 + 选项弹层）

| 维度 | 结论 | 证据 |
| ---- | ---- | ---- |
| ① 320px + 1.3 | 通过：设置页与弹层各在自己的 context 上测（`MediaQuery.builder` 注入 1.3，视口 320×720），`takeException()` 为 null | 设置文件最后一条 |
| ② 独立读屏语义 | 通过：取值是 `trailingText` 的 `Text`，合并进该行的语义节点 ⇒ 念出「标签 … 显示」；配对反向断言（当前「显示」时念不到「隐藏」） | 设置文件第二条 |
| ③ 失败保留已加载数据 | 通过：`save` 抛错 → SnackBar「保存失败，显示标签仍为当前设置」，行内取值与 `todo_view_preferences` 行数都不变；SnackBar 4s 后自动消失仍被断言 | 设置文件第三条 |
| ④ 过期响应不覆盖新响应 | **通过（按实现方式排除）**：写入的是**点中的字面值**，不是 `!current`；`current` 只用于画勾选标记。⇒ 读到过期值最坏是标记画错一帧，不可能盖掉更新的值。仓库层 `重复切换只改写同一行…` 钉住"最后一次点中的值生效 + 同一行同一 id" | 仓库层第 3 条 |

## 反向探针（摘掉实现看测试会不会红）

| 探针 | 变异 | 期望 | 实测 |
| ---- | ---- | ---- | ---- |
| PA | 侧栏门控 `!showTags` → `!false && showTags`（等于永不收起） | 红 | 红 `-2` |
| PB | `defaultShowTags = false` | 红 | 红 `-5`（仓库 + 侧栏） |
| PC | `_decode` 丢掉服务端嵌套包装分支 | 红 | 红 `-1` |
| PD | `save` 的 id 改为每次新生成（update 命中 0 行） | 红 | **首跑绿 —— 假阳性，已补强后转红** |
| PE | 设置行 `trailingText` 的取值改成 `null` | 红 | 红 `-4` |
| PF | `catch` 里改成 `rethrow`（不再给可见提示） | 红 | 红 `-1` |

**PD 的教训（诚实记录）**：原断言只在 4 次 save 之后读一次最终值 ⇒ "id 漂移导致每次都写不进去、库里停在第一次的 false" 这条 bug 恰好也停在 `false`，测试全绿。
补强为**每次 save 后立刻回读** + 断言行 id 不变 + outbox 计数 4 ⇒ PD 转红（`改写必须真的落到那一行`）。
副作用：这条同时把"写入的是字面值不是取反"锁住了（取反实现会在第 2 次 `save(false)` 后读出 `true`）。

## 与嘀嗒的已知偏差（不写成"一字不差"）

1. 只收起标签**条目**，不收「标签」那一行入口（spec 取舍 1）。
2. 移动端 `:16` 的「清单管理页」本 App 不存在，开关放在设置页 ⇒ 可达但层级不同（spec 取舍 3）。
3. 帮助页两张截图取不到（离线镜像只有 .md）⇒ 无法核对"隐藏后整组是否留标题"。

## 门禁（最终字节，commit 之后跑）

| # | 门禁 | rc | 日志 |
| - | ---- | -- | ---- |
| 1 | `git diff --check` | 待跑 | — |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 7 个文件>` | 待跑 | — |
| 3 | `flutter analyze` | 待跑 | — |
| 4 | `flutter test --tags golden`（9 张，不重录） | 待跑 | — |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 待跑 | — |
| 6 | `flutter build web --release --dart-define=…` | 待跑 | — |

## 复核

- [ ] 只读复核 `VERDICT`（待派）

## 残留缺口（本轮不做，留下轮）

- 矩阵 #21 其余面：任务详情输入 `#`、`TaskQuickAddSheet` 的 `#` 入口仍被未合并的 `!319/!322/!314` 挡着。
- 移动端「清单管理页」界面本身（嘀嗒 `:16` 的入口位置）——需要单独立项，属矩阵 #19。
