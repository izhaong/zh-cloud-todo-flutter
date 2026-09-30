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
