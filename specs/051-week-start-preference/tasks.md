# 任务清单：星期开始于（specs/051）

## 完成情况

- [x] `spec.md` 来源表：4 个锚点逐字引用（`01-欢迎/03-常见问题.md:125/:134/:143/:159`、`02-功能指南/02-日历/08-常见问题.md:145/:149/:155`）；移动端「星期开始于」/ 桌面「每周开始于」的措辞差异如实登记，本仓采移动端措辞
- [x] 红测（步骤 2）
- [x] `WeekStart` 纯函数 + 偏好仓储 + provider（步骤 3–5）
- [x] 日历/时间线 8 处周一硬编码接线（步骤 6；判据见 `spec.md` 现状表两条 `git grep`）
- [x] 设置「日期与时间」-「星期开始于」三档入口 + 四件套（步骤 7）
- [ ] 六道门禁（见下表，跑在最终字节上）
- [ ] 只读复核 `VERDICT`
- [ ] 矩阵 #31 缺口列回写

## 红测读数

```
$ flutter test test/core/time/week_start_test.dart test/week_start_preference_repository_test.dart
00:00 +0 -2: Some tests failed.
  Error when reading 'lib/state/repositories/week_start_preference_repository.dart': No such file or directory
```

⚠️ **这一条是编译红，不是行为红**（`loading …[E]` 且计数停在 `+0`）——两个文件引用的 API 还不存在。新章
节的第一版测试只能证明"接口没实现"，不能证明"行为错"。真正的行为约束见下面的绿测。

## 绿测与接线过程中发现的两处自身缺陷（都已真修，不记成存量欠债）

| 现象 | 根因 | 处置 |
| --- | --- | --- |
| `+19 -1`：`offsetOf 给出某天距本周起点要回退的天数` 红，报 `Expected <7> Actual <2>`（`firstDay=7 weekday=1`） | **我的断言算错了方向**：把"回退 offset 天"写成了"前进 offset 天" | 实现是对的（同组 `startOf` 的周日档用例同时是绿的）。改断言为 `((weekday - 1 - offset) % 7 + 7) % 7 + 1`，复跑转绿。先怀疑预期值，不先改实现 |
| 提交后自查发现**同一个数字在四处写错**（spec / plan / tasks / PR 描述 / Issue 评论都写「7 处，全部同型表达式」） | 数的时候把 `calendar_view.dart:333` 的 `leadingBlanks = firstOfMonth.weekday - 1`（不是 `subtract` 式）和整行 `const` 表头都算进了"同型"，又把总数少算成 7 | `git grep -nE "Duration\(days: [a-zA-Z]+\.weekday - 1\)" origin/develop -- lib` = **6**，加 `weekday - 1` 非 subtract **1** 与 const 表头 **1** ⇒ 共 **8 处**，其中只有 6 处同型。四处文档已按实测改写，判据命令本身写进 `spec.md` 现状表。**这一条是派复核之前自己量出来的**，不是复核抓的 |
| `dart analyze` 4 条 error：`Expected to find '}'` ×3 + `Undefined name 'weekStartProvider'` | 脚本给三个公开函数加命名参数时写成 `… scale, { int firstDay = …,\n) {`，漏掉收尾的 `}`；`timeline_view.dart` 本来没 import `state/providers.dart` | 三处补 `}) {`；按 `calendar_view.dart` 的既有 import 顺序补 import。**教训：脚本换函数签名时，带 `{` 的命名参数列表必须整段自己写全，不能只改参数行** |

## 用例账

| 文件 | 覆盖 |
| --- | --- |
| `test/core/time/week_start_test.dart` | `startOf` 4、`columnOrder` 4、档位与文案 3、`offsetOf` 2 |
| `test/week_start_preference_repository_test.dart` | 默认/读写/单行更新/watch 推新值/拒写非三档/出箱一条/服务端包装可读/脏数据兜底 = 8 |
| `test/features/task/week_start_consumers_test.dart` | 网格 4、表头字形 2、周档标签 2、日历端到端 3、时间线端到端 2 = 13（实测 `+13`） |
| `test/features/settings/settings_week_start_test.dart` | 分组与档位显示、三档与勾选、即时生效、保存失败、库未就绪、字面值语义、320px+1.3 = 6 |

> 全量套件以门禁 5 的输出为准；上表是"本轮新增了什么"的清单，其中 13 那条有实际读数，其余按用例逐条数出。

## 六道门禁

| # | 门禁 | 跑在哪 | 读数 |
| --- | --- | --- | --- |
| 1 | `git diff --check` | 待填 | 待填 |
| 2 | `dart format --output=none --set-exit-if-changed <本轮显式文件>` | 待填 | 待填 |
| 3 | `flutter analyze` | 待填 | 待填 |
| 4 | `flutter test --tags golden` | 待填 | 待填 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 待填 | 待填 |
| 6 | `flutter build web --release` | 待填 | 待填 |

## 反向探针（待跑，逐项补读数）

| 编号 | 摘掉什么 | 预期 |
| --- | --- | --- |
| PF | `WeekStart.offsetOf` 退回 `weekday - 1`（等于忽略档位） | 月网格 + 表头 + 时间线端到端三组同时红 |
| PG | 只换网格、表头仍用 `const` 的 `一…日` | 表头用例红、网格用例绿 ⇒ 证明两处是独立判据（漏一半会被抓到） |
| PH | `settings_route.dart` 的 `labelOf` 兜底去掉（`valueOrNull!`） | 首值未到即崩，证明 FR-7 的兜底不是装饰 |
| PI | 三档改成四档（加「周二」） | 档位数量断言红 |

## 已登记的残留（不当成已解决）

- **四件套 ④ 的写入并发**：`save` 落的是"点中的字面值"，所以不存在取反/盖回；但两次点选的写入若在 SQLite 事务层面重叠，仍可能是先点的后落地。本轮**没有**加写队列（那要为一条从未观察到的小窗口引入新机制），已按现状把测试钉成"重复点同一档不变 + 顺序点选停在最后一次"。若复核认为该窗口不可接受，再加序列化。
- **习惯「本周完成」仍是服务端周界**（`/app-api/todo/habit/stats` 的 `weeklyDone`），不随本偏好变，见 `spec.md`「明确不做」。

## 矩阵

`#31 日历显示设置` 的缺口列要补上「星期开始于」，并且它原本的 `firstDayOfWeek` 0 命中判据在合并后不再是 0（本 PR 引入了 `WeekStart`，但**不引入** `firstDayOfWeek` 这个词）——复跑口径要在回写时重测一遍再写，别提前抄。
