# 123 · 日历任务块按清单/标签/优先级着色（矩阵 #31「清单自定义颜色」档）

## 背景

嘀嗒《02-功能指南/02-日历/08-常见问题.md》:58：

> 点击日历视图右上方「···」-「显示设置」-「颜色」-「显示方式」，
> 即可选择任务块按照清单、优先级或者是标签显示颜色。

矩阵 #31 的残面：日历显示设置此前只有「显示已完成」「热力图」两档，
颜色轴整体缺——所需的清单自定义颜色契约（service !307 + FL specs/102）
已先后合并，客户端一直没接。

## 设计（复用优先，零契约变更、零迁移）

- **着色解析直接复用** specs/121 的 `timelineTaskColor`/`TimelineColorBy`
  （lib/features/task/views/timeline_color.dart）——同一套「清单/标签/优先级
  三轴 + 无色回退优先级」语义，不复制第二份解析器。
- 偏好走 `saveCalendarDisplay` 既有 valueJson 通道新增 `calendarColorBy`
  键（patch 合并；非法档归一化 priority）。
- 「显示设置」抽屉加「颜色」节（RadioGroup 三档，key
  `calendar-color-by-<档>`）；`CalendarDisplayFlags` record 升级为
  `CalendarDisplaySettings` 类（成对交回原则不变，只是多带一格）。
- **顺带修正一处旧口径**：「显示设置」入口此前按 `filterCompleted` 隐藏
  （那是「显示已完成」一格的旧口径——无可见效果时藏入口）；颜色轴在
  任何模式都有可见效果 ⇒ 入口改为常显。

## 目标（FR）

- FR-1 抽屉「颜色」三档可选，即选即存（saveCalendarDisplay）。
- FR-2 月视图任务块按所选轴着色：清单色/标签色（多标签取位次最高），
  无色回退现有优先级色。
- FR-3 重进回读所选轴；非法档归一化 priority，不抛错。
- FR-4 显示设置入口常显（原 filterCompleted 门随颜色轴取消）。

## 验收（AC）

- AC-1 抽屉「颜色」三档可选；选「按清单」后 `calendarColorBy='list'` 落库。
- AC-2 跨会话回读（RadioGroup 当前档 = tag）。
- AC-3 非法档写不进去（归一化 priority）。
- AC-4 门禁：analyze 0 issue、新用例全绿 + 探针、全量不回归。
