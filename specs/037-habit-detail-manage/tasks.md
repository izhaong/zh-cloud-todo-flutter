# 037 任务清单

关联：Gitea `izhaong/zh-cloud-todo-flutter#290`；契约侧未合并依赖 `izhaong/zh-cloud-service!276`（归档，本单不接）；契约缺口 `izhaong/zh-cloud-service#277`（NOT_NULL 更新策略 / 删除不级联打卡 / 逻辑删除）。

## 第 1 轮

- [x] T-001 详情页可达：点击习惯卡片 → `HabitDetailPage`（FR-1；探针 PA 摘掉 `_HabitTile.onTap` → 11 条红）
- [x] T-002 「...」恰含「编辑」「删除」，且**不含**「归档」（FR-2；探针 PB 删「编辑」项 → 8 条红；「不含归档」是刻意的反向断言，归档端点只在未合并的 !276 里）
- [x] T-003 `HabitRepository.update` → `PUT /habit/update`，body 含 `id` + 六个可编辑字段 + 原 `sortOrder`（FR-3；探针 PC 把 `id` 改名 `idx` → 红；PN 抽掉 `icon` → 红）
- [x] T-004 未改动的提示原样回传，不发 `null`（FR-3 边界②；探针 PE 把 `reminderAt` 恒置 null → 红）
- [x] T-005 `HabitRepository.delete` → `DELETE /habit/delete?id=`；取消确认不发任何写请求（FR-4；探针 PF 摘掉 delete 调用 → 红；PG 摘掉 `!confirmed` 早退 → 红）
- [x] T-006 失败保留已加载数据 + 提示落在弹层内联可见（探针 PH 摘掉 `_submitError` 赋值 → 红）
- [x] T-007 新建与编辑共用同一张表单，`create` 带齐 7 个字段（FR-5；新增用例 + PN 红；复核 NIT8 的「FR-5 零用例」已补）
- [x] T-008 时间字段按 epoch 毫秒上送（FR-6；探针 PJ 让 `checkedAt` 退回 ISO → 红）
- [x] T-009 四件套：320px + 1.3 档位在**四个**新表面（详情页 / 编辑弹层 / 「...」菜单路由 / 删除确认框）各用自己的 context 复检；「...」与色块有独立读屏语义；校验错误落在字段上（探针 PM 摘掉 `errorText: _nameError` → 红）
- [ ] T-010 六项门禁日志齐全（见下）
- [ ] T-011 矩阵 #43/#44 补 `文件:行号` 证据；PR 未合并前不翻「有」（在 `zh-cloud-docs` 侧回写，落点 `todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 第 95-96 行）
- [x] T-012 契约缺口按规则 5 另开 Service 单：`zh-cloud-service#277`

## 反向探针的两个「绿」，以及它们真正说明什么

`保存在飞期间重复点保存 ⇒ 只发一次 PUT` 这条用例，**摘掉任一侧都仍然全绿**：

| 探针 | 摘掉什么 | 结果 |
| --- | --- | --- |
| PI | 只摘按钮的 `loading: _saving` | 绿 |
| PK | 只摘 `if (_saving) return;` | 绿 |
| PL | 两处**同时**摘 | **红** |

⇒ 这条用例覆盖的是**这一对守卫的协同**，不是其中某一行。两侧职责不同：`loading` 管可感知（按钮点不动 + 转圈），早退守卫管正确性（键盘 Enter、重建后的残留回调这类不经过指针的触发）。**保留两处**，并按上面的粒度记录，不写成「两行各有独立用例」。

`maxLength: 64`（对齐 `AppTodoHabitBaseVO:15` 的 `@Size(max = 64)`）**没有反向探针覆盖**——现有 17 条用例里没有「输入 65 字」这条。它是一行纯声明式护栏，本轮如实标注为「未钉住」，不宣称有测试证明。

「...」菜单路由与确认框的 320px 档位自检同样**没有反向探针**：档位继承自框架，没有一段生产代码可以摘掉来让它变红。这条只能算「跑了没溢出」，不算机制被钉住。

## 复核（第 1 轮）

复核手段替换：`claude` CLI 本机不可用（`unrecognized_model`）⇒ 用本会话**只读子代理**审本单 FR，被明确要求不得 Edit/Write。结果 **`VERDICT: FAIL`**，3 BLOCKERS + 16 NITS。逐条处置：

### BLOCKERS（全部已修，并独立复验过事实）

| # | 结论 | 处置 |
| --- | --- | --- |
| B-1 | 非 golden 套件实际是红的：`efficiency_api_contract_test.dart:349` 仍钉 `create` 的 3 键 body，而 FR-5 把它变成 7 键 ⇒「六项门禁齐全」当时是假的 | 接受。已改为钉 7 键。**我先前跑门禁用的是 `tail`，只看到 `Some tests failed` 前几行就以为只有习惯文件的问题**——复核员给了计数才逼出这条。本地独立复现：`+722 ~26 -1`，红的那条正是它。 |
| B-2 | 详情页的统计卡看的是 `habitStatsProvider` = `overviewStats()`（跨**所有**习惯的 max/sum），却标着「连续打卡 / 本周完成 / 总打卡」放在单个习惯里；`_HabitStats.habitId` 在 `build` 里一次都没读 | 接受。整块 `_HabitStats` 删除。这是「给错数」不是风格问题，而且不在任何 FR 里。 |
| B-3 | 删除确认文案「所有打卡记录也会被清空」后端不兑现：`TodoHabitServiceImpl:70-74` 只有 `deleteById`，`TodoHabitCheckInMapper` 无按 `habitId` 删除的方法；`deleted` 还是 `@TableLogic` 逻辑删除 | 接受，但**不改文案**（FR-4 要求逐字对齐嘀嗒 :122）。按规则 5 开 `zh-cloud-service#277`，并在 spec 边界表写明「本条结掉前该承诺对外不成立」。 |

### NITs：接受并已改

1 → 手写 `AlertDialog` 改走仓里统一的 `AppDialog.confirm(danger: true)`（原来删除按钮是 accent 色不是 destructive 色）。
2 → 「目标次数」改「目标」（spec.md:16 自禁同义词，词是从 VO 的 `@Schema` 抄来的，不是从嘀嗒来的）。
3 → 名称补 `maxLength: 64`（`AppTodoHabitBaseVO:15` 的 `@Size(max = 64)`）。
4 → 「每天8 次」补空格，与列表页一致。
5 → 详情页那个不在任何 FR 里的「打卡」按钮整块删除（无 try/catch ⇒ 失败是未处理异常；无在飞守卫 ⇒ 会连发；而 `checkIn` 的去重是按 `checkedAt` 精确等值，两次毫秒不同就真的多一条）。列表行仍可打卡。
6 → 保存按钮改 `AppButton(loading:)`，与 NIT-B2 的守卫结论一致。
7 → 补「...」菜单路由 + 删除确认框的 320px + 1.3 自检。
8 → 补 FR-5 用例（新建走同一张表单 + 7 键 body）。
9 → 删调 `checkIn` 里没人调用的 `note` 形参。
10 → 校验错误改落 `errorText` 在字段上（本仓 `ux-preferences.mdc:50` 明写「优先在字段附近」）。
11 → spec 的「8 条路由」改为实测的 7 条（`grep -cE "@(Get\|Post\|Put\|Delete)Mapping"` = 7）。
12 → plan.md 里 `reminderAt` 仍写 ISO 形状、PK 探针描述与实现不符 ⇒ 重写探针表为 PA–PN 的实际结果。
13 → `await` 之后用 `ref` 前补 `context.mounted`（列表页 + 详情页两处）。
15 → FR-6 补「同族仍有 21 处 `toIso8601String`，未逐处判定，另开单」，不把习惯当孤例。
16 → 矩阵回填落点写进 T-011（`zh-cloud-docs` 的 `dida-parity-matrix.md` 第 95-96 行）。

### NITs：不采纳（附理由）

- **NIT 14（`_HabitHeader` 与列表头像行重复）不改**：两处只有半径不同，抽公共组件属未被要求的重构，且会牵动已验收的 `HabitPage` 布局。
- **不删 `?? initial` 回退**（复核员自己也归入 REJECTED）：`myHabitsProvider` 处于 loading/error 时详情页仍可显示与操作，这正是四件套「失败保留已加载数据」。
- **「保存失败：$error」把 DioException 整个插进文案不改**：`note_page.dart:68`、`task_comments_page.dart:136`、`calendar_subscription_page.dart:88` 全仓既有风格，要收就全仓一次收，不在本轮单点改。
- **`targetPerWeek` 兜底（`habit_repository.dart:39`）不删**：本轮之前就有的遗留兼容，按「发现无关死代码只提醒不删」处理，已在此留痕。
- **提示列的「绝对时点 vs 每日重复」不改 UI**：属契约语义缺口，已补进 spec 边界①-b，需要 Service 侧先动。

### 复核员替我挡住的两个陷阱（记录以免下次重犯）

1. `PopupMenuItem` 的语义断言原本是空转——SDK 的 `Tooltip` 给的是 `Semantics(tooltip:)` 而非 `label:`，`find.bySemanticsLabel('更多操作')` 恒 0 命中；实现里那句显式 `Semantics(label:)` 是**必需**的，不是重复语义（我一度想删掉它）。
2. `?? initial` 方向相反的那个风险才是要害：`invalidate` 之后 `AsyncValue.valueOrNull` 会 `copyWithPrevious` 继续给**旧列表**，所以「保存成功 → 重拉」这个往返里标题短暂回旧值，此时再点编辑会用旧值预填，直接保存就覆盖掉刚做的修改（lost update）。窗口约一次 `/habit/page` 往返（100–300ms），人手赶不上 ⇒ 记为**已知限制**，不在本轮修；根治方向是保存成功后本地合并，而不是只 `invalidate`。

## 门禁原文记录（最终状态一次跑完，日志 `/tmp/r21-gates-final.log`）

```
$ git diff --check
exit=0

$ dart format --output=none --set-exit-if-changed <本轮 6 个显式文件>
Formatted 6 files (0 changed) in 0.03 seconds.
exit=0

$ flutter analyze
Analyzing zh-cloud-todo-flutter...
No issues found! (ran in 1.6s)

$ flutter test --tags golden
00:03 +9: All tests passed!                      # 9 张基线未变，未重录

$ flutter test --exclude-tags 'golden || performance' --concurrency=1
01:53 +726 ~26: All tests passed!                # 726 passed / 26 skipped / 0 failed

$ flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1
Compiling lib/main.dart for the Web...    19.8s
✓ Built build/web
```

格式门禁**先红后绿**：第一次跑 `dart format` 报了 4 个文件 `Changed`（`habit_page` / `habit_detail_page` / `habit_editor` / `habit_detail_page_test`），
`exit=1`。为排除"存量欠债"，把 HEAD 版单独抽出来量同一判据：`/tmp/hp_head.dart`、`/tmp/hr_head.dart` 都 `0 changed / exit=0`
⇒ 这 4 处红是我本轮引入的，就地只格式化这 4 个文件（不整仓原地格式化），红日志留存。

- [x] T-010 六项门禁日志齐全（见上）

测试计数对账（已定死，不靠推测）：在干净 worktree `/tmp/zh-tf-develop`（HEAD = `a1d7733`）实跑同一判据 ⇒
`flutter test --exclude-tags 'golden || performance' --concurrency=1` → **`+709 ~26: All tests passed!`**
分支 726 = 709 + 本文件 17 条新用例，**逐条对上，没有凭空消失的用例**。
⇒ 目标里记的「基线 713 passed / 26 skipped」**多算了 4 条**，后续轮次按 709 起算（日志 `/tmp/r21-baseline-develop.log`）。

