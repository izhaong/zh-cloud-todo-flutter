# 规格：侧栏清单「置顶」

- 来源 Issue：#341（同单另一半「拖拽排序」已在 develop，登记 outbox 那半是第 79 轮做的）。
- 判据源逐字：`zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md`
  「在侧边栏左滑某个清单，会出现「置顶」、「编辑」和「删除」3个选项。点击中间「编辑」图标，即可进入清单编辑页面。」

## 落地

本地表 `todo_lists` 新增 `isPinned`（schema v24→v25 迁移加列，存量行默认未置顶）；
`ListRepository.setPinned` 写本地列并登记一条 `list`/`upsert` outbox，payload 字段名 `isPinned`
与服务端 `AppTodoListBaseVO.isPinned`（`todo_list.is_pinned`，service 第 92 轮已合）同名同义；
入口在侧栏清单行：左滑唤出动作表，表里有「置顶 / 取消置顶」，长按这一既有入口保留；
清单查询把置顶行排在最前，否则用户看不出任何效果。

置顶写失败就地显示在动作表里（表不关），不做「关掉表再弹一条没人看见的 SnackBar」。

## 范围外

标签项的置顶在 #329（前置 service #318，标签表还没有置顶列）；
清单拖拽排序不在本轮；桌面端与移动端的呈现差异沿用同一张动作表。
