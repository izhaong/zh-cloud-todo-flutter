# 041 任务清单

## 已证实
- [x] FR-001..FR-005 的 5 条用例存在且**先红后绿**：红 = `00:01 +0 -5: Some tests failed.`
      （`Expected: exactly one matching candidate / Actual: ... Found 0 widgets with widget matching predicate`，
      即 tooltip「加粗」不存在）；实现后 `00:01 +5: All tests passed!`
- [x] 反向探针：摘掉两个 `IconButton` ⇒ `00:01 +0 -5`；`cp` 还原后 `cmp -s` 判「byte-identical OK」，
      再跑 `00:01 +5: All tests passed!`
- [x] `dart format --output=none --set-exit-if-changed`（仅本轮 2 个显式文件）⇒ `Formatted 2 files (0 changed)`、rc=0

## 门禁（最终状态一次跑完，日志 `/tmp/r38_gates.log`）
| 门禁 | 结果 |
| --- | --- |
| `git diff --check` | 待填 |
| `dart format --output=none --set-exit-if-changed <本轮 2 个文件>` | 待填 |
| `flutter analyze` | 待填 |
| `flutter test --tags golden`（基线 9） | 待填 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1`（基线 713 passed / 26 skipped） | 待填 |
| `flutter build web --release --dart-define=...` | 待填 |

## 仍缺（不谎称完成）
- [ ] 折叠光标下「先点样式后打字」在真机（iOS/Android 软键盘）上的表现未验；本机只有 web 构建可用
      （`github.com` 超时 ⇒ iOS SPM 编译不可用）。
- [ ] 嘀嗒《11-笔记与摘要.md:43》原文是「键盘上方的样式菜单」，本端做成内容框上方一排按钮（桌面/移动同一位置），
      位置语义与「键盘上方」不严格一致，需产品确认是否要求跟随软键盘。
- [ ] 「等样式」（斜体、删除线、标题等）未做 —— 本轮只落原文点名的加粗与高亮两种。
- [ ] 向后选择（Shift + ←）的选区方向未回写，见 `spec.md` 取舍。
- [ ] 矩阵第 89 行 ② 的回写：合并后把「已实现待合并」换成合并 SHA 并复算行号。
