# 045 · 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/320-sort-direction`。

## 勾选（只勾真满足的）

- [x] FR-1 方向两档 + label 照嘀嗒（「从新到旧」「从旧到新」），`newestFirst` 是默认值
- [x] FR-2 只有 `createdAt` / `updatedAt` 读方向；四档非时间轴不受方向影响（探针 PB 证这条断言有力）
- [x] FR-3 `valueJson` 多存 `direction`；缺键读回 `newestFirst` 且**不牵连档位**；未知方向名同理（`sort` 仍读得出）
- [x] FR-4 菜单在时间轴档给两行方向（当前项勾选）、非时间轴不给；页面级重排 + 重进清单仍是该方向
- [x] FR-5 未改表结构、未 bump `schemaVersion`（`git diff origin/develop...HEAD -- lib/core/db/` 为空）
- [x] 四件套：320px+1.3 与读屏已实测，且"读屏能分辨当前方向"单独有断言，勾的**归属**会随方向换行
      （探针 PJ 钉住：把勾写死在 `newestFirst` 上，320px 那条当场红 —— 补 loop 之前它是绿的）；
      「保存失败仍保留已选方向」有独立用例（假仓储让 `save` 抛错，断可见提示 + 界面仍是刚选方向 +
      重开菜单勾还在这一行；探针 PK / PL 各钉一半）；
      「过期响应不覆盖新响应」对本面不适用（本地单一写入者），理由写在 spec 表里而不是空勾
- [x] Issue #320 验收①②③④ 逐条对上：①两条互逆用例；②页面级"重进清单仍是该方向"（含真卸载，探针 PG）；
      ③切方向后看板与时间线的既有顺序不变（探针 PI 钉住）；④**可复现判据**：种进夹具的两行
      `serverId` 为空（用例里断言），且 `TodoVisualFixture` 本身不通网 ——
      `test/support/todo_visual_fixture.dart:76` 把 `apiClientProvider` 换成 `_NoNetworkApiClient`
      （`:455`，任何非预期请求直接回 `Future.error`）、`:86` 把 `syncCoordinatorProvider` 置 null，
      所以"用例能跑完"就等于"切方向一次请求都没发"。旧措辞「全程没有 fake API」不写判据，已作废
- [x] 六道门禁日志 —— 见「门禁原文记录」节（最终字节，六项全 `rc=0`）
- [ ] 只读复核 `VERDICT` —— 待派
- [ ] 矩阵 #20 回写 —— **合并后**才动状态与证据列，本轮只允许写「已实现待合并」

## 反向探针（每条先跑"未打补丁"的对照组）

`--plain-name` 命中 0 条时 `flutter test` 也报绿，所以没有对照组就分不清"用例不会红"和"根本没跑到用例"。

| 探针 | 抽掉什么 | 对照 | 打补丁后 |
| ---- | -------- | ---- | -------- |
| PA | 时间轴不吃方向（去掉 `reversed *`） | `+2` 绿 | `-1`「创建时间档：两个方向排出来互为逆序」红 |
| PB | 方向错误地作用到标题档 | `+1` 绿 | `-1`「非时间档不受方向影响」红 |
| PC | `save` 不写 `direction` 键 | `+1` 绿 | `-1`「方向能存能读…」红 |
| PD | 缺/未知方向的默认改成 `oldestFirst` | `+1` 绿 | `-1`「方向能存能读…」红（旧格式那半） |
| PE | `hasDirection => true`（所有档都给方向行） | `+1` 绿 | `-1`「方向行只在两档时间轴下出现」红 |
| PF | `_ListBody` 渲染时不传方向 | `+1` 绿 | `-1` 页面级用例红 |
| PG | 回读偏好时把方向写死成 `newestFirst` | `+1` 绿 | `-1` 页面级用例红 |
| PH | 当前方向的勾选去掉 `semanticLabel: '当前方向'` | `+1` 绿 | `-1` 320px 那条「分辨当前方向」红 |
| PI | 让所有视图都吃方向（铺平前按方向整体反转） | `+1` 绿 | `-1` 页面级用例红（验收③ 那段） |
| PJ | 勾写死在 `newestFirst` 上（不看传进来的方向） | `+1` 绿 | `-1` 320px 那条红在**负向**配对断言上 |
| PK | `_changeSortDirection` 的 catch 里去掉可见提示 | `+1` 绿 | `-1` 「方向保存失败」那条红在 SnackBar 断言 |
| PL | 方向不喂给 header（写死 `newestFirst`） | `+1` 绿 | `-1` 「方向保存失败」那条红在"重开菜单勾还在这一行" |

> **复核 !347 第 1 轮之后重跑过一遍全表**：320px 那条从"只跑一个方向"改成两个方向各一轮，
> 用例数从 8 变 9，旧数字不沿用。PA 对照仍是 `+2`（两条互逆用例共享 `互为逆序` 这个名字），
> PB–PL 对照都是 `+1`；12 条打补丁后全部 `-1`，每条红的都是**该咬的那一条**（逐条比对
> `/tmp/g65/<探针>.log` 里的 `[E]` 行）。PJ 就是复核员那条 finding：补 loop 之前它对绿。
>
> 另两条顺手学到的：`--plain-name "320px + 1.3 倍"` 的命中数**不能**用同名正则去 grep 输出
> （`+` 在正则里是量词，数出来恒 0，会让人以为"根本没跑到用例"）—— 以对照组的
> `+1: All tests passed!` 为准；`TaskWorkspaceHeader` 那个 `sortDirection:` 调用点在
> `_ListBody` 与铺平排序里各有一份，PL 的锚点必须带上下两行才唯一（命中 1 次）。

### 复核 !347 第 1 轮（`VERDICT: FAIL`）逐条处置

| # | finding | 回源复验 | 处置 |
| - | ------- | -------- | ---- |
| 1 | 「当前方向」的配对断言不可证伪：勾写死在 `newestFirst` 上，8 条仍全绿 | 采信，自己重跑 PJ 复现 | 320px 用例改成两个方向各一轮 + 每轮先真卸载；PJ 现在红 |
| 2 | 帮助页行号错位：应为 `:143` / `:156` / `:186` 与 `:192-193` / `:219` | `git show origin/develop:…03-用分组和排序管理任务.md \| sed -n '143p;156p;186p;192,193p;219p'` 逐行对上 | 采信，5 个文件 12 处改正（commit `ce2b7a9`） |
| 3 | 门禁 5「三处红」数错了，实际四处，多出的一处在 `task_sort_preference_repository_test.dart` | 在 develop 的测试字节上重跑（`/tmp/g64-recount`），输出 `Failing tests:` 恰好 4 条 | 采信，见下节「门禁 5」改写 |
| 4 | 四件套第 3 条（保存失败仍保留已选方向）零用例 | 采信：`_changeSortDirection` 的 catch 分支只被 `_changeSort` 的同形分支间接测过 | 新增一条用例；`tasks.md` 的四件套勾改成引用 PK/PL |

四条全部采纳，无驳回项。

### PG 第一次跑是绿的 —— 假绿，记录以免重犯

PG 首轮**没红**：页面级用例里"重进清单"是再 `pumpWidget` 一次同一个页面，而 `pumpWidget` 会**复用**
同类型同位置的 `State` ⇒ `_restoreSortPreference` 压根没重跑，`_sortDirection` 还是上一次设的值。
修法是先 `pumpWidget(SizedBox.shrink())` 真卸载再重挂（commit `68ad9b3`），PG 才红在该红的断言上。
⇒ 「重进页面后仍是上次的状态」这类用例，必须自己证明确实换了一个 State。

### 另一条：菜单没展开时，负向断言会假通过

菜单用例第一版在 helper 里 `return tapped` —— 返回的是那一刻的 `null`，闭包写的是 helper 自己的局部变量，
调用方永远读不到；同时 `pumpWidget` 复用 Navigator 的 State，**上一轮没收起的弹层还挂在上面**，
下一轮点菜单按钮打在遮罩上（`warnIfMissed` 只警告不红），于是"这一档没有方向行"是在
"菜单压根没开"上通过的。两条都已修：回调由调用方持有 + helper 结尾断言"智能（置顶优先）"在屏上
+ 每轮收尾把菜单收掉并断言收掉了。

## 门禁原文记录（跑在**最终字节 `e21f2f2`** 上，日志 `/tmp/g64/gates2.out` 与末次终端输出）

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check` | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed <本轮 7 个显式文件>` | `Formatted 7 files (0 changed)`，`rc=0` |
| `flutter analyze` | `No issues found! (ran in 1.8s)`，`rc=0` |
| `flutter test --tags golden` | `00:05 +9: All tests passed!`，9 张基线未重录（golden 文件变更提示 0） |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:25 +906 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web`，`rc=0` |

计数对账：干净 worktree 实跑基线 `9032005` ⇒ `02:29 +898 ~26`；本分支 `+906 = 898 + 8`（新文件 8 条），逐条对上。
`pubspec.lock` 未进 PR（门禁跑完工作区 0 项）。

### 门禁 5 第一次是红的：四处既有断言被我的返回类型变更打断

第一版 `get()` 从 `TaskSort` 改成 `TaskSortPreference` 后全量跑出 4 条红（复核第 1 轮数的是 3，
我按 develop 的测试字节 + 本分支的 `lib/` 重跑了一次（日志 `/tmp/g65/recount-gate5.log`），`Failing tests:` 恰好 4 条）：

| # | 文件 | 红的那条 |
| - | ---- | -------- |
| 1 | `task_sort_updated_at_test.dart` | 修改时间档能存能读，不会被静默退回智能排序 |
| 2 | `task_sort_updated_at_test.dart` | sync pull 的嵌套包装能读出修改时间档；未知档位名退回智能排序 |
| 3 | `sync_coordinator_organize_search_test.dart` | sort preference pushes from A and B restores it from the sync feed |
| 4 | `task_sort_preference_repository_test.dart` | 排序偏好按清单隔离，离线保存后入队并可重启读取 |

⇒ 第 3 条顺手升级成同时断言**方向也同步过去了**。
第 5 个消费方 `b3_live_sort_preference_ab_test.dart` 也要改（`.sort`）才编译得过，但它
`skip: !_enabled`（要真服务才跑），所以**不在红测清单里** —— 这是"改动波及面"与"红测数"
不相等的另一种情形，别拿红测数当波及面。
这四处是靠"先 commit 再跑门禁"的顺序才发现的，如果先跑测试再提交就会被格式化噪音混过去。

## 下一轮入口

1. 矩阵 #20 的证据列与状态列要等本 PR 合并后按已合并 SHA 写；本轮不翻状态。
2. 嘀嗒「分组排序」面板里的**分组**那一半（智能分组六维度 = Issue #321）仍未做，那是独立一轮，
   不要顺手接进来。
