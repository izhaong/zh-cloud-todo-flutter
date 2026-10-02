# 台账：侧栏「过滤器」显隐偏好（FL Issue #336，第 146 轮）

分支 `fix/336-sidebar-filter-visibility`，基线 `origin/develop`（取数基准现读）。
规格与方案见同目录 `spec.md` / `plan.md`。

## 一、红测 → 实现

- 实现前跑 `flutter test test/features/shell/sidebar_show_filters_test.dart`
  ⇒ **编译期红**，报错点名不存在的 API：
  `The method 'saveFilters' isn't defined for the type 'SidebarVisibilityRepository'` 与
  `getFilters` 同样一条（`00:00 +0 -1: Some tests failed.`）。
  诚实记账：这一面的红在编译期而不是行为期 —— 因为"设置页有这一档 / 这一档能落库"
  在旧代码里根本没有可调用的入口，写不出不依赖新 API 的行为断言。
  面本身的缺口另有可复算判据，写在 `spec.md` §二那张表里。
- 行为级的红另有一处，是**首版实现自己引入的**：照抄 `showTags` 的三态口径
  （没读到值不画）后门 5 变红，
  `test/shell_responsive_test.dart: 渲染智能清单与浏览入口` ⇒
  `Expected: exactly one matching candidate` / `Actual: _TextWidgetFinder:<Found 0 widgets with text "筛选器">`。
  改成"按默认显示绘制、只有读到隐藏才收"后该条回到绿，理由与代价记在 `spec.md` §三 决定 3。
- 实现后同一条命令 ⇒ `00:01 +5: All tests passed!`（本文件五条用例）。
- 反向探针：把 `sidebar.dart` 里的 `if (showFilters)` 摘掉（恢复常驻形状）后重跑
  ⇒ 两条用例红（"关掉就没"与末条窄屏态），且 `00:01 +3 -2`。
  探针字节用 `cp` 备份、`cmp -s` 还原，输出 `restored byte-identical`，还原后重跑 ⇒ `+5 通过`。

## 二、两条语义取舍与第二意见

1. **写路径改 patch**：`save()` 原来整块覆盖 `valueJson`，加第二个键后必须读旧行再合并，
   否则改「过滤器」会把「标签」顶回默认。用例「两个开关写同一行偏好」两个方向都断言。
2. **设置页新档单独一张卡**：并进「标签」那张卡会改掉后者的合并语义节点
   （`test/features/settings/sidebar_show_tags_settings_test.dart` 的四件套 ② 那条实测变红，
   报 `Actual: '标签\n'` ⇒ 合并节点里丢了失败提示）。分组标题「智能清单」仍共用。
3. 交叉验证通道本轮**未取第二意见**（该通道留给语义取舍拿不准时；本轮两处取舍都有
   既有用例的红灯当判据，不需要外部意见顶替）。VERDICT 走 `claude -p`，见下面第五节。

## 三、六道门禁（跑在最终代码字节上）

脚本 `/tmp/r136/gates336.sh`，日志 `/tmp/r136/gates336b.log`（换文件名：复跑会覆盖旧证据）。

| 门 | 读数 |
| --- | --- |
| 1 `git diff --check origin/develop HEAD` | rc=0，跑在差集上（提交后工作树是空的，只跑工作树等于没跑） |
| 2 `dart format --output=none --set-exit-if-changed` 加五个字面量路径 | `Formatted 5 files (0 changed)`、rc=0。这里的 5 要等于 `git diff --name-only f361be4 HEAD -- '*.dart' \| wc -l` = 5
（基准钉在门禁时点 `f361be4`：写成 `origin/develop` 会随上游前进漂成 19 —— 第 1 轮 NIT-3 就是抓到这个。） |
| 3 `flutter analyze` | `No issues found! (ran in 1.5s)`、rc=0 |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、rc=0，9 张基线未重录（`find test -name '*.png' \| wc -l` = 9） |
| 5 非 golden 用例集 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:06 +1201 ~26: All tests passed!`、rc=0 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`、rc=0 |

- 六个 rc：门1=0 门2=0 门3=0 门4=0 门5=0 门6=0。
- 卫生：`status_after_gates=[?? specs/068-sidebar-show-filters/tasks.md]`、`lock_in_pr=0`、`goldens_dirty=0`。
- 头：门禁跑在 `ed35632` 上；本节这笔台账只动 `specs/`，
  `git diff ed35632 HEAD -- lib test` 为空 ⇒ 门 2–6 承接，门 1 在新头另跑一次。

## 四、台账自扫

`python3 tool/check_spec_selfscan.py specs/068-sidebar-show-filters/tasks.md` ⇒ 下面这行是现跑读数：

```
specs/068-sidebar-show-filters/tasks.md: 失项 0 条（仓库根按 wt-fl-336 解析）
```

## 五、只读复核

第 1 轮已排进 `/tmp/r136/review_queue.txt`（`review-336-r1`），
报告未回 ⇒ 三格缺最后一格，本轮**不合并、不翻矩阵**。


## 第 1 轮只读复核 `VERDICT: FAIL` 的处置（第 154 轮，2026-09-30）

日志 `/tmp/r136/review-414-r1.jsonl`（result 块复算 `grep -c '"type":"result"'` ⇒ 1；`num_turns` 151、耗时 103 分钟；审 `6fed55e`）。一条 FAIL、四条 NIT，逐条：

- **FAIL（采纳）**：`spec.md` §五 漏登记「跨设备 pull 整行覆盖这行偏好」。本机写路径的键级合并是本轮亲手做的、也有用例，
  但 pull 路径 `_upsertLocalViewPreference` 仍是整块覆盖 ⇒ 本 PR 把该行从单键变双键后它成了丢键源。已按现跑锚点补进 §五并立 **FL #422** 承接修本身。
  复核员给的行号 `:1922-1924` 与现跑差 5-7 行 ⇒ 台账只记自己量到的 `:1856` / `:1929` / `:1015` / `:1282`。
- **NIT-1（写侧 `_json_map` 只保 bool 键）**：记为已知边界、本轮不改。判据 `git grep -rn SIDEBAR_VISIBILITY lib/` ⇒ 该行今天只有本仓这两个 bool 键，
  没有第三种键可丢；将来该行要放非 bool 键时按「写侧全量保留、读侧再过滤」改。
- **NIT-2（「并进同一张卡必红」缺留痕）**：**采纳并降格措辞** —— 支撑它的是实现者一次实测，`/tmp/r136` 里没有对应探针日志，
  所以 spec 里凡据此写「必红」的地方都改成「实测会红、无留痕日志」（本轮只降措辞，不改「独立卡」这个取舍）。
- **NIT-3（门禁计数命令判据漂移）**：**采纳**。`git diff --name-only origin/develop HEAD -- '*.dart' | wc -l` 现跑 = 19，
  门禁时点基准 `f361be4` 上确为 5 ⇒ 表里那条命令改成钉死 `f361be4..HEAD`。同因，门 1 用两点式比到分支头会报上游
  `specs/044-kanban-groups/tasks.md:59: new blank line at EOF`（rc=2）；正确形态是三点式对 merge-base、或两点式对**合并产物**。
- **NIT-4（「9 张基线」口径）**：**采纳并改口径** —— 9 是门 4 的用例数（`+9`），其中渲染侧栏的是 wide×4 + compact
  ⇒ 文案改成「含侧栏画面的那几张要重录」，不再把 9 当受影响图数。

**改完仍欠**：本轮只动 `specs/`（`lib`/`test` 未变 ⇒ 门 2–6 读数仍由上文各节承接，门 1 在新 head 上另跑）；
FAIL 的收回要一轮新复核 ⇒ 第 2 轮已入队。矩阵 #22 仍不翻状态（本 PR 未合并）。

## 第 2 轮复核 `VERDICT: FAIL`（B：台账超出测试证据）的处置（2026-09-30）

回源复验后**采纳**。复核员说 `spec.md` §四 把 ②③④ 与「设置页那一档的 ①」记成「通过」而测试里没有断言 ——
现跑复算 `grep -c 'ensureSemantics\|getSemantics\|valueOrNull' /tmp/r160/t414.dart`（那份与本节改动前的
`cbe7ee3` 版本 `cmp -s` 逐字节相同）= 0；`grep -n '320\|textScale'` 在那份上命中五行 —— 两行在那条侧栏用例
（`:106`/`:107`）、三行在 `_pumpSidebar` 助手（`:120`/`:125`/`:130`），`_pumpSettings` 里一处也没有，
它的视口写死 `TodoVisualViewports.wide` ⇒ 「通过」两字当时没有测试撑。

- 补法：设置页的 ①、②、④ 各起一条用例，③ 在既有失败用例里加断言。用例条数判据
  `grep -c 'testWidgets(' test/features/shell/sidebar_show_filters_test.dart` 现跑 = 8；「改动前 5」用带 ref 的命令复算 `git show cbe7ee3:test/features/shell/sidebar_show_filters_test.dart | grep -c 'testWidgets('` = 5（现跑已验 = 5；旧字节不在本轮提交里，光写「改动前 5」不可复算）
  `_pumpSettings` 的视口与字号改成入参，并**从被测那一行自己的上下文读回**
  `MediaQuery.textScaler.scale(14)=18.2`、视口逻辑宽 = 320 —— 防的就是这次踩到的「参数没接线也绿」。
- ④ 的口径降格：这一面只有一条 `watch` 偏好流、界面不缓存副本 ⇒ 「旧响应盖新响应」没有可达路径。
  `spec.md` §四 该行结果列由「通过」改成「可测部分通过，乱序态不适用」，可测部分是
  「写的是点中的字面值」这条新用例。
- 断言绑定探针（脚本 `/tmp/r164/probe414.py`，日志 `/tmp/r164/probe-*.log` 六份）：每条新判据都要能被一处
  字节改动打红，改完 `cmp -s` 逐字节还原。

| 探针 | 打红的用例（现跑读数） |
| --- | --- |
| `saveFilters(showFilters: !picked)`（④ 取反） | 「设置页…选了「隐藏」就落库」、「「过滤器」这一行的读屏名字…」、「存的是点中的那个字面值…」⇒ `+5 -3` |
| `trailingText: null`（② 撤掉取值） | 「保存偏好失败时…」、「「过滤器」这一行的读屏名字…」⇒ `+6 -2` |
| `_visibilityLabel` 反着念（③ 取值显示错） | 「设置页…落库」、「保存偏好失败时…」、「读屏名字…」⇒ `+5 -3` |
| `_pumpSettings` 视口写死宽屏（① 参数不生效） | 仅「设置页 320px + 1.3 倍字号…」⇒ `+7 -1` |
| `_pumpSettings` 字号写死默认（① 同上另一路） | 仅「设置页 320px + 1.3 倍字号…」⇒ `+7 -1` |
| 还原后复跑 | `00:01 +8: All tests passed!`、rc=0（`/tmp/r164/probe-restored.log`） |

- 本节之后的门禁：`lib/` 未动（探针逐字节还原，`git status` 只列测试与本目录），`test/` 与 `specs/` 动了
  ⇒ 门 3–6 在本节这笔提交的重堆上另跑，读数记在下一节，不承接上文 `ed35632` 那份。

## 六、重堆后的门禁读数（head `4827634`，2026-09-30）

| 门 | 分支头读数（`/tmp/r164/gates414/`） | 累积合并产物读数（`/tmp/r164/cum414/`，产物 `9192cf4` = develop `8b59d7e` + 本 PR） |
| --- | --- | --- |
| 1 `git diff --check <merge-base> HEAD` | rc=0（首跑 rc=2 报的是本节上一版在 EOF 多留的空行，摘掉后为 0） | rc=0 |
| 2 `dart format --set-exit-if-changed` 显式路径 | `Formatted 5 files (0 changed)` rc=0，5 = `git diff --name-only f361be4..HEAD -- '*.dart' \| wc -l` 现跑 | rc=0（7 个路径，含并进来的 !382 那几个） |
| 3 `flutter analyze` | `No issues found! (ran in 4.2s)` rc=0 | `No issues found! (ran in 3.7s)` rc=0 |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!` rc=0，`find test -name '*.png' \| wc -l` = 9 | `00:06 +9` rc=0，png 仍 9 张 |
| 5 非 golden 用例集 | `03:45 +1204 ~26: All tests passed!` rc=0 | `03:44 +1306 ~26: All tests passed!` rc=0 |
| 6 `flutter build web --release` | `✓ Built build/web` rc=0 | `✓ Built build/web` rc=0 |

- 卫生：两轮 `git status --short` 在门禁后均为空 ⇒ `pubspec.lock` 没被本机镜像改写、golden 未脏。
- 真实合并试算：`git merge-tree --write-tree origin/develop 4827634` rc=0，`^CONFLICT` 计数 0。
- 覆盖面绑定：第 3 轮复核审的是 `f2cb384`，到现头 `4827634` 的差集只有 `specs/068-sidebar-show-filters/tasks.md`
  （文档路径）⇒ 报告对现头仍成立。第 3 轮 `claude -p` 进程在写 `review-414-r3.jsonl`（6.3 MB、尚无 result 块）
  ⇒ 本轮**不合并**，等 VERDICT 落地。
- 队列连带：!382 已按同一份累积产物合进 develop（合并提交 `8b59d7e`，Issue #381 已带证据关闭）。
  本 PR 合并时的产物判据就是这张表右列那份，前提是该期间 develop 不再前进；若前进了要重跑右列。

## 七、第 3 轮复核 `VERDICT: PASS` 与合并（2026-09-30）

- 报告 `/tmp/r164/review-414-r3.jsonl`（result 块复算 `grep -c '"type":"result"'` = 1；`num_turns` 47、耗时 24.3 分钟；
  审头 `f2cb384`）⇒ `VERDICT: PASS`。第 2 轮 FAIL(B) 的「台账超出测试证据」由 §六 那节记录的三条用例与反向探针收回。
- 报告另点两处措辞与实现不同形，已各改一笔：`spec.md` 四件套 ① 行原把「视口宽 320」也说成从该节点 context 读回
  （实际字号取自该行 `MediaQuery`，尺寸取自 `tester.view`）；`tasks.md` 的「改动前 5」改成带 ref 的可复算命令。
  诚实记账：订正首笔 `373044498` 的正文说改了两处，实际脚本在写 `tasks.md` 前抛异常、只落了 `spec.md` 一处，
  第二处由 `a337e47` 补上并在正文里更正说明；已推送的历史不改写。
- 合并提交 `9fd24c5e85f399eb2e9eebf4ff06a111c2d97c38`（回读 `merged=true`；写这笔账时它就是 `origin/develop` 的头，此后 develop 又前移到 !356 的合并提交 ⇒ 「现头」二字以当时为准，)
  分支头 `a337e47` 经 `git merge-base --is-ancestor` 证为其祖先）。FL Issue #336 随合并自动关闭（现读 `state=closed`）。
- 覆盖面绑定：审头 `f2cb384` 到合并头 `a337e47` 的差集 = `git diff --name-only` 现读 2 条，全在 `specs/068-sidebar-show-filters/`
  下（文档路径）⇒ 报告对合并头仍成立。
- 合并前置的门禁读数：产物 `eb49b10`（`origin/develop@8b59d7e` + `a337e47`）门 1/3/4/5/6 rc 全 0，
  门 5 = `03:39 +1306 ~26: All tests passed!`，门 4 = `+9`（`find test -name '*.png' | wc -l` = 9，未重录），门 6 = `✓ Built build/web`；
  门 2 跑在分支头字节上 = `Formatted 5 files (0 changed)`（本轮新增两笔只动 `specs/`，dart 字节未变）。
- 合并后主干复验：本 worktree 按 `9fd24c5` 检出后 `flutter analyze` ⇒ 下面这行是现跑读数。

合并后主干复验：`flutter analyze`（worktree 按 `9fd24c5` 检出）现跑 `No issues found! (ran in 4.3s)`、rc=0 ⇒ develop 绿。
