# Spec 100：智能分组（六维档位）

## 判据源

- 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/03-用分组和排序管理任务.md》
  （基准 zh-cloud-docs `origin/develop`，镜像 PR !70 已合并）：
  `:57`「# 智能分组」、`:58`「除了自定义分组外，滴答清单还提供多种智能分组方式：」；
  六小节 `:60` 按清单分组 / `:67` 按时间分组 / `:80` 按优先级分组 /
  `:94` 按标签分组 / `:103` 按指派人分组 / `:112` 按创建时间分组（新增）。
- 时间桶 `:69`-`:74`：今天、明天、最近 7 天、以后、已过期（顺序按原文）；
  优先级桶 `:82`-`:86`：高优先级、中优先级、低优先级、无优先级。
- Issue：izhaong/zh-cloud-todo-flutter#321（矩阵 #20「智能分组」缺口）。

## 范围

- 任务列表页头部新增「智能分组」菜单（key `todo-grouping-menu`），七档：
  不分组 / 按清单 / 按时间 / 按优先级 / 按标签 / 按指派人 / 按创建时间，
  文案与嘀嗒小节标题逐字；当前档位打勾（Icon semanticLabel「当前分组」）。
- 组头沿用 `TaskGroupHeader`（key `todo-task-group-<组id>`），桶名逐字用嘀嗒原文：
  时间 = 已过期/今天/明天/最近 7 天/以后/无日期（空桶省略）；
  优先级 = 高优先级/中优先级/低优先级/无优先级（0=无、1=低、2=中、3=高）。
- 多标签任务在每个标签组各出现一次；桶序按任务输入首次出现；无标签组排最后。
- 按指派人：`assigneeUserName` 分桶，空值进「无指派人」组（排最后）。
- 按创建时间：今天/昨天/最近 7 天/更早（档名为本端补，见诚实登记）。
- 分组偏好按清单持久化（`todoViewPreferences` 表 sourceType `TASK_GROUP`、
  收集箱视角独立一份 sourceKey `inbox`），离线保存走
  `SyncChangeQueue.enqueue(entity: 'view_preference')` outbox；认不出的档位回退「不分组」。

## 明确不做

- 排序（同组内任务排列）不在本 spec：`compareTodoTasks` 既有排序继续在组内生效。
- 智能分组不改变既有的默认分区（置顶/已逾期/今天/…）与自定义分组行为：
  仅当选了非「不分组」档时整体替换分区。
- 按指派人不做同名不同人并桶的拆分（客户端只有 `assigneeUserName` 一个字符串，
  无成员 id 可依，见诚实登记）。

## 测试台账

- 引擎单测 `test/features/task/smart_grouping_test.dart`（10 用例全绿）：
  时间五桶 + 无日期、allDay 边界、空桶省略、优先级四档、多标签重复出现 +
  无标签回退、清单名 + 未命名清单、指派人 + 无指派人、创建时间四桶、none 为空。
- 偏好仓 `test/task_grouping_preference_repository_test.dart`（3 用例全绿）：
  读回/按清单隔离/outbox 入队（entity=`view_preference`、op=`upsert`）、
  重启读回、坏档位与坏 JSON 回退不分组。
- 页面 `test/features/task/smart_grouping_page_test.dart`（6 用例全绿）：
  菜单七档 + 时间组头逐字、优先级四组头 + 高优先级归属、
  标签组头 + 多标签任务三次渲染、指派人单组、
  重挂载恢复 + 勾选态、320px + 1.3 倍字号不溢出。
- 回归：`drag_list_task_into_calendar_test.dart` 7 用例全绿（默认分组行 key 未变）。
- golden：头部新增分组按钮改变工作区视觉，`todo_workspace_golden_test.dart`
  7 张基线重录（isolatedDiff 确认差异只在头部两图标位置，无其它区域漂移），
  重录后该文件 9/9 绿。

## 变异探针（cp 备份 + cmp -s 字节一致还原）

1. `lib/features/task/smart_grouping.dart` 时间桶名 `'明天'` → `'明天X'`
   ⇒ 引擎时间用例与页面时间组头用例红。
2. `lib/features/task/tasks_by_list_page.dart` 撤掉行 key 的组 id 前缀
   （`ValueKey('${group.id}:${task.id}')` → `ValueKey(task.id)`）
   ⇒ 页面按标签分组用例红（`_ReorderableListViewChildGlobalKey` 撞车，见缺陷登记）。
   还原后页面 6/6 全绿。

## 缺陷登记（红测抓到并已修）

- 桌面端列表是 `ReorderableListView`，子项 key 会被包成
  `_ReorderableListViewChildGlobalKey`；按标签分组让同一任务出现两次时
  裸 `ValueKey(task.id)` 撞 GlobalKey。修复：智能分组激活时行 key 带
  `组id:任务id` 前缀；非智能分组维持 `ValueKey(task.id)`
  （`drag_list_task_into_calendar_test.dart:139` 依赖不变）。

## 诚实登记

- 本面 N/M 档 = 6/6（清单/时间/优先级/标签/指派人/创建时间全做）。
- 「无日期」时间桶是本端补的（原文只列五桶）；「以后」与「无日期」的分界
  按「未来 7 天之后」取「以后」，原文未给精确边界，客户端口径：
  `due >= 7 天后的今天 00:00` 为「以后」。
- 按创建时间的四档名（今天/昨天/最近 7 天/更早）原文未列档名，本端补齐。
- 按指派人：共享清单成员唯一性客户端只有 `assigneeUserName` 字符串；
  同名不同人会并进同一组，待成员 id 贯通后另立单。
- `check_spec_selfscan.py` 实测：spec.md / tasks.md 双文件失项 0 条（rc=0）。
- 未跑真机/桌面端手动验证；读屏断言以 Icon `semanticLabel` 属性 +
  菜单项 key 下的 Text 为准。
