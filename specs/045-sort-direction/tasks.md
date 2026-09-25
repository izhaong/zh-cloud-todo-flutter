# 045 · 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/320-sort-direction`。

## 勾选（只勾真满足的）

- [x] FR-1 方向两档 + label 照嘀嗒（「从新到旧」「从旧到新」），`newestFirst` 是默认值
- [x] FR-2 只有 `createdAt` / `updatedAt` 读方向；四档非时间轴不受方向影响（探针 PB 证这条断言有力）
- [x] FR-3 `valueJson` 多存 `direction`；缺键读回 `newestFirst` 且**不牵连档位**；未知方向名同理（`sort` 仍读得出）
- [x] FR-4 菜单在时间轴档给两行方向（当前项勾选）、非时间轴不给；页面级重排 + 重进清单仍是该方向
- [x] FR-5 未改表结构、未 bump `schemaVersion`（`git diff origin/develop...HEAD -- lib/core/db/` 为空）
- [x] 四件套：320px+1.3 与读屏已实测，且"读屏能分辨当前方向"单独有断言（探针 PH 钉住）；
      「失败保留已加载数据」沿用既有 `_changeSort` 分支，未为该分支单独写用例；
      「过期响应不覆盖新响应」对本面不适用（本地单一写入者），理由写在 spec 表里而不是空勾
- [x] Issue #320 验收①②③④ 逐条对上：①两条互逆用例；②页面级"重进清单仍是该方向"（含真卸载，探针 PG）；
      ③切方向后看板与时间线的既有顺序不变（探针 PI 钉住）；④方向是纯本地写偏好，
      页面级用例全程没有 fake API ⇒ 未同步任务不阻塞切换
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

### 门禁 5 第一次是红的：三处既有断言被我的返回类型变更打断

第一版 `get()` 从 `TaskSort` 改成 `TaskSortPreference` 后全量跑出 3 条红：
`task_sort_updated_at_test.dart` 两处（`Expected: TaskSort:<TaskSort.updatedAt> / Actual: <Instance of 'TaskSortPreference'>`）、
`sync_coordinator_organize_search_test.dart` 一处（上行 payload 的 `valueJson` 现在是
`{"sort":"dueDate","direction":"newestFirst"}` 而不是 `{"sort":"dueDate"}`）。
⇒ A→B 那条顺手升级成同时断言**方向也同步过去了**。
这三处是靠"先 commit 再跑门禁"的顺序才发现的，如果先跑测试再提交就会被格式化噪音混过去。

## 下一轮入口

1. 矩阵 #20 的证据列与状态列要等本 PR 合并后按已合并 SHA 写；本轮不翻状态。
2. 嘀嗒「分组排序」面板里的**分组**那一半（智能分组六维度 = Issue #321）仍未做，那是独立一轮，
   不要顺手接进来。
