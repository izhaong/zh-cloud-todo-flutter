# 执行计划：星期开始于（specs/051）

## 切片

| # | 步骤 | 产出 | 验证 |
| --- | --- | --- | --- |
| 1 | 读帮助页 + 现状取证 | `spec.md` 的来源表与现状表（**8 处**周一硬编码：6 同型 + 1 非 subtract + 1 const 表头行） | 行号逐行读源码核对；`日期与时间` 0 命中配 `_Section(title:` 正控 |
| 2 | 红测（纯函数 + 仓储） | `test/core/time/week_start_test.dart`、`test/week_start_preference_repository_test.dart` | 首跑必须红；红因是「文件不存在」的编译红，如实标注，不冒充行为红 |
| 3 | `WeekStart` 纯函数 | `lib/core/time/week_start.dart` | 三档往返 + 默认=周一 |
| 4 | 偏好仓储 | `lib/state/repositories/week_start_preference_repository.dart` | 复用 `todoViewPreferences`，不升 `schemaVersion`；出箱一条 `view_preference` |
| 5 | provider | `lib/state/providers.dart` 的 `weekStartPreferenceRepositoryProvider` / `weekStartProvider` | FR-7 三态读法收敛到一处 |
| 6 | 消费面接线 | `calendar_view.dart`（月网格 + 表头 + 周视图）、`timeline_view.dart`（本周/下周分桶、周档窗口标签、取值范围、全天槽） | 公开函数带 `firstDay=` 默认值 ⇒ 既有调用方与既有测试不改签名也能编译 |
| 7 | 设置界面 | 「日期与时间」分组 + 「星期开始于」行 + 三档弹层 | 四件套 ①②③④ |
| 8 | 六道门禁 + 只读复核 + 回写 | `tasks.md` 门禁表、矩阵 #31 缺口列 | 全跑在最终字节上 |

## 约束

- 9 张黄金基线不重录：默认档 = 周一 = 改造前行为，这是前提而不是巧合。
- 习惯「本周完成」不随档位变（周界在服务端），已写进「明确不做」，需要 service 侧先加参数。
- 三个消费文件都是既有大文件：只做「同一表达式换成 `WeekStart.*`」，不顺手重构、不重排无关代码；改完用 `git diff` 逐行确认没动到别人的行。
