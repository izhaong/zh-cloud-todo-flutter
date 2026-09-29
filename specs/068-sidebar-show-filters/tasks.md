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
| 2 `dart format --output=none --set-exit-if-changed` 加五个字面量路径 | `Formatted 5 files (0 changed)`、rc=0。这里的 5 要等于 `git diff --name-only origin/develop HEAD -- '*.dart' \| wc -l` = 5 |
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
