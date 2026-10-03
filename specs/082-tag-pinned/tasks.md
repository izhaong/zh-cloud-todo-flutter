# 任务清单：侧栏标签「置顶」接线（specs/082）

基准提交：分支 `feat/329-tag-pinned`，起点 `origin/develop@b7802f684b70`（FL 现读，开工与提交前各核一次，
`git merge-base HEAD origin/develop` 仍等于起点 ⇒ 本轮没有踩过别人的合并）。
前置：service `origin/develop@944ae83b9019`（#318 标签置顶契约，已合并）。

## 实现

- [x] 本地列 `TodoTags.isPinned`（默认 false）：`lib/core/db/app_database.dart:138`
- [x] `schemaVersion` 25 → 26：同文件 `:449`；`onUpgrade` 的 `from < 26` + `_columnExists('todo_tags','is_pinned')` 守卫：`:706-710`
- [x] Drift 生成物：`lib/core/db/app_database.g.dart`（`dart run build_runner build --delete-conflicting-outputs` 重生成，
      该表新增 `is_pinned` 的读写与 `TodoTag` 构造参数）
- [x] 写路径 `TagRepository.setPinned`（本地列 + 一条 `tag`/`upsert` outbox，payload 走整行 `toJson()`）：
      `lib/state/repositories/tag_repository.dart:109`
- [x] 读路径两处排序改成「置顶降序领头 + createdAt 升序」：同文件 `:30`（`watchAll`）、`:38`（`getAll`）
- [x] 入站同步认 `isPinned`，缺键时保留本地值：`lib/core/sync/sync_coordinator.dart:1722`（`_upsertLocalTag`）
- [x] 侧栏标签行左滑 + 长按唤出动作表：`lib/features/shell/sidebar.dart:647`（`Dismissible` key）、
      `:658-659`（次层背景的读屏名）、`:678`（`onLongPress`）
- [x] 动作表本体（只放「置顶」一项，失败横幅就地可见）：`lib/features/tag/tag_actions.dart:37`（key
      `sidebar-tag-action-pin`）、`:32`（key `sidebar-tag-pin-error`）
- [x] 新增用例：`test/state/tag_pinned_repository_sync_test.dart` 7 条 +
      `test/features/shell/sidebar_tag_pin_test.dart` 8 条 +
      `test/app_database_migration_test.dart` 的 `v25→v26` 那条，合计 16 条新用例

## 本轮改动拉长出来的既有债（认账，不是"不适用"）

- [x] 加列使 `TodoTag` 生成构造多出必填参数，`test/features/filter/advanced_filter_tag_condition_test.dart`
      的三处字面量当场编译红（analyze 报 `missing_required_argument` 三行）⇒ 已在 `:237`、`:249`、`:262`
      三处补 `isPinned: false,` 后 analyze 回到 rc=0。
- [x] `schemaVersion` 常量一推，**另一个文件**里硬编码同数字的用例也会红：
      `test/state/list_pinned_repository_sync_test.dart:96` 断的是 `schemaVersion == 25`，全量测试把它抓了出来
      ⇒ 改为断 26 并把用例名改成「库表升到 v26：todo_lists 仍带 is_pinned 列」。
      教训已按可复算方式处理：本仓现读 `grep -rn "schemaVersion, 2[0-9]|user_version'], 2[0-9]"` 全仓 19 处命中，
      除本文件外都在 `test/app_database_migration_test.dart`（一次改到 26）。

## 四件套（新 UI 逐条量，不写"不适用"）

- [x] 320px + 1.3 倍字号：`sidebar_tag_pin_test.dart` 的「320px 宽 + 1.3 倍字号：左滑动作表可点且不溢出」，
      视口 `Size(320, 700)`、`textScaleFactorTestValue = 1.3` 都在**侧栏这条路由自己的 context** 里设，
      磁贴宽度断言 `lessThanOrEqualTo(320)` 且 `takeException()` 为 null
- [x] 独立读屏语义：两条用例分别量「磁贴自己的 `getSemantics(...).label` 含『置顶』」与
      「左滑次层背景（key `todo-sidebar-tag-swipe-actions`）自己的 label 含『置顶』」，
      `ensureSemantics()` 的句柄在**用例体内** dispose（不用 `addTearDown`）
- [x] 失败保留已加载数据：「置顶失败：当场可见提示，已加载标签不丢」用 `_ThrowingTagRepository`
      经 `overridesBuilder` 注入，断 key `sidebar-tag-pin-error` 在、`find.textContaining('置顶失败')` 在、
      前后标签 id 集合相等、且失败那条的 `isPinned` 仍为 false（本地位没被改脏）
- [x] 过期响应不覆盖新值：本轮**没有**异步回读覆盖本地状态的路径 —— 置顶是本地写 + outbox 登记，
      入站只在 `payload` 带 `isPinned` 时才改本地（不带就保留），这一条由用例
      「pull 带回 isPinned 就落列；没带就保留本地置顶位」直接量到，不是"没有对应场景"

## 门禁（在最终字节上现跑现读）

- [x] `git diff --check` 干净（staged 与最终字节各跑一次）
- [x] `dart format --output=none --set-exit-if-changed` 跑这 10 个 .dart 文件 ⇒ `Formatted 10 files (0 changed)`，rc=0
- [x] `flutter analyze` ⇒ `No issues found!`，rc=0（此前有 3 条 `missing_required_argument` 红，已按上一节修）
- [x] `flutter test --tags golden` ⇒ `00:06 +9: All tests passed!`，rc=0（基线 9 张，本轮**一张都不用重录**：
      动作表是新唤出的浮层，不在任何既有 golden 视口的静态绘制里）
- [x] `flutter test --exclude-tags="golden || performance" --concurrency=1`
      ⇒ `03:48 +1403 ~26: All tests passed!`（0 失败、26 跳过），日志 `/tmp/r213-fullsuite2.log`
- [x] `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`
      ⇒ rc=0，日志 `/tmp/r213-buildweb.log`
- [x] 反向探针 A（排序面）：删掉 `tag_repository.dart` 两处 `OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc)`
      ⇒ rc=1，2 红：`getAll 把置顶标签排在最前` `Expected: ['丙','甲','乙'] Actual: ['甲','乙','丙']`、
      `watchAll 与 getAll 同一顺序` `Expected: 't-b' Actual: 't-a'`；`cp` 还原后 `cmp -s` 证字节一致
- [x] 反向探针 B（入站保留面）：把 `sync_coordinator.dart:1722` 的 `?? existing?.isPinned ?? false` 改成 `?? false`
      ⇒ rc=1，红在 `pull 带回 isPinned 就落列；没带就保留本地置顶位`，`Expected: <true> Actual: <false>`；还原同上
- [x] 反向探针 C（入口面）：摘掉 `sidebar.dart:678` 的 `onLongPress`
      ⇒ 红在 `长按给出同一动作表（读屏与桌面靠它，不只手势）`（`Which: means none were found but one was expected`）
- [x] 反向探针 D（失败可见面）：删掉 `tag_actions.dart` 的 `if (pinError != null) Padding(...)` 横幅块
      ⇒ 红在 `置顶失败：当场可见提示，已加载标签不丢`；C+D 同批跑，日志 `/tmp/r213-probeCD.log`
      （三处还原逐文件 `cmp -s` 均 identical）
- [x] `tool/check_spec_selfscan.py` 对本目录两份文件跑过，结果与失项数记在下一节
- [ ] `claude -p` 只读复核 VERDICT：未取到（该通道近期持续 0 字节），以「六道门禁 + 四条反向探针 + 合并试算」替代，
      **本轮未经独立复核**

## 欠账（如实登记）

1. 面 ⑥ 的**拖拽半面**（`:118`「通过在侧边栏「长按标签」即可进行拖拽，可以对清单进行自由排序」）没做，
   留在 #329；本端标签行也没有 `sortOrder` 列（Drift 里标签只有 `createdAt` 序），
   下一轮做拖拽要先定"排序值存哪"：加 `todo_tags.sort_order` 列 + 服务端 `sortOrder` 已有，
   属于"客户端加列 + 复用既存契约"，不需要新开 service 单。
2. 桌面端「右键标签唤出同一张表」（`:94`）未接：本端侧栏没有右键手势通道，本轮走左滑/长按同一张表，
   矩阵回写时不许把这行写成"三选项一字不差"。
3. 置顶后服务端是否真的把该标签排在 `/app-api/todo/tag/list` 首位，**未做端到端实测**
   （service 侧有单测与 SQL，但增量 SQL 尚未在任何环境执行 ⇒ 端上真机联调前这一格只能记「未验证」）。

## 下一轮入口

- #329 剩拖拽半面：`todo_tags` 加 `sort_order` 列 + v27 迁移 + `TagRepository.reorder` + 侧栏 `ReorderableListView`
  （基准 FL 合并后的 `origin/develop`，届时行号要重跑）。
- 矩阵 `zh-cloud-docs/todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 的 `#21` 行：本轮合并后只把
  **缺 ⑥ 里的「置顶」子句**改成已合并（引合并 SHA），`:118` 拖拽那句留着不动。
- 服务端增量 SQL `zh-cloud-service/sql/mysql/modules/todo-m14-tag-pinned-2026-10-03.sql` 待批准后在 test 库执行，
  执行完才谈得上端到端联调。
