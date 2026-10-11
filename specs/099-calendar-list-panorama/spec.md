# Spec 099：日历列表档「下拉展开日历全景」

## 判据源

- 嘀嗒《02-功能指南/02-日历/08-常见问题.md》`:167` 标题「日历列表视图，不能看到完整的日历吗？」、
  `:168` 原句「在列表视图，手指按住第一排日历，向下拉，即可展开一个小的日历全景。」
  （基准 zh-cloud-docs `origin/develop`，镜像 PR !70 已合并）
- Issue：izhaong/zh-cloud-todo-flutter#362（矩阵 #29「列表视图（按天）」缺口列本面）

## 范围

- 列表档（`CalendarMode.list`）常驻「第一排日历」：锚点所在周的一条周条（按「星期开始于」偏好取周首）。
- 向下拉（primaryVelocity > 120）在同屏周条下方展开小月网格全景；上滑收起；
  也可走读屏按钮（`Semantics` 容器 key `calendar-list-panorama-toggle`，label 展开/收起态切换）。
- 点周条或全景里的某天：锚点切到那天并收起全景（周条日格读屏念「M月d日」+ `selected` 位）。
- 全景复用 `_MonthGrid`，锚点日随全局「星期开始于」一致。

## 明确不做

- 全景里不渲染任务点/任务数（嘀嗒只写「日历全景」，任务标记无判据；顺带避开 320px 下 chip 溢出）。
- 展开态不进持久化偏好（嘀嗒未写跨启动保留；Issue #362 约束：若必须持久化先留言说明，不自行扩面）。
- 不切月视图档、不开新页面、不弹层（同屏瞬时展开/收起）。

## 测试台账（test/features/task/calendar_panorama_test.dart，5 用例全绿）

| 用例 | 断言 |
| --- | --- |
| 列表档默认收起 | 全景 key findsNothing、toggle 语义 label =「展开日历全景」 |
| 点读屏按钮展开/收起 | 全景 key 出现/消失、label 随态翻转、月网格表头字形出现 |
| 下拉/上滑手势（:168 字面） | fling(0,200) 展开、fling(0,-200) 收起 |
| 点全景某天 | 锚点切日 + 收起 + `calendar-strip-day-*` 语义 label「6月20日」+ `flagsCollection.isSelected == Tristate.isTrue` |
| 320px + 1.3 倍字号 | 展开态不溢出（`takeException` isNull） |

## 变异探针（/tmp/cv-backup.dart 备份，cmp 字节一致还原）

1. 下拉阈值 120 → 99999 ⇒ 手势用例红。
2. 语义 label 三元改恒「展开日历全景」 ⇒ 按钮/收起用例红。
   还原后 5/5 全绿。

## 门禁

- `flutter analyze`（全仓）+ `flutter test`（全量）：见 tasks.md T005 实测记录。

## 诚实登记

- 本轮未跑真机/桌面端手动验证；widget 测试语义断言以 `getSemanticsData().flagsCollection` 为准（先例 timezone_preference_test.dart）。
- `check_spec_selfscan.py` 未执行（≠通过）：本仓工具链本轮未跑，若 CI 有跑以 CI 结果为准。
