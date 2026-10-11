# Spec: 智能清单「显示 / 隐藏 / 有内容时显示」三态与管理入口

- Issue: zh-cloud-todo-flutter #337（矩阵 #19 面 ⑥）
- 判据源：嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md》
  - `:29`「点击侧边栏「添加清单」右边的「设置」，即可打开「智能清单管理」页面」（mobile 形态）
  - `:45`「我们提供了三种显示状态：「显示」、「隐藏」、「有内容时显示」」
  - `:20`「（收集箱是不可以被隐藏或删除。）」
  - `:37` 桌面「设置」-「智能清单」——本端入口只做侧栏（`:29`）一处，设置页复用留给后续轮

## 现状（origin/develop@47bb514c053b）

- 侧栏 7 条智能清单（`SmartList` 枚举：inbox/today/tomorrow/upcoming/all/completed/trash）是硬编码常驻行，无开关、无管理入口。
- 已有偏好通道：`todo_view_preferences` 表 + `SIDEBAR_VISIBILITY` sourceType 行内多键 patch + viewPreference outbox（`SidebarVisibilityRepository`，showTags/showFilters 两个 bool 键）。

## FR

- FR-1 管理入口：侧栏「新建清单」右侧一枚设置图标按钮，点开「智能清单管理」底部弹层（对应嘀嗒 `:29` 的「添加清单右边的设置」）。
- FR-2 三态：今天 / 明天 / 未来7天 / 全部 四行支持「显示 / 隐藏 / 有内容时显示」；默认全部「显示」（9 张黄金基线里有侧栏画面，默认变了要重录）。
- FR-3 「有内容时显示」的内容判定复用侧栏徽章同一份 `TaskStats` 计数（today→stats.today 等，>0 即有内容）；计数尚未就绪（null/加载中）按「显示」处理——不能因为统计流没到就把行藏掉。
- FR-4 收集箱显式保护：管理页里收集箱行固定「显示」不可改，并展示「收集箱不可隐藏或删除」说明；仓储层 `saveSmartListState(inbox, 非 show)` 抛 `ArgumentError`（显式判据，不靠"恰好没有入口"）。
- FR-5 已完成 / 垃圾桶两行只给「显示 / 隐藏」两档：垃圾桶本端无内容载体（pane 是占位空态）、已完成无现成计数，不预支「有内容时显示」。
- FR-6 侧栏渲染：隐藏 ⇒ 行不出；有内容时显示 ⇒ 计数 >0 才出；存储读不到的清单按默认「显示」。加载中按既有导航行口径（`showFilters` 那条）：`valueOrNull ?? 默认`，宁可闪一下也不让整列跳格。

## 取舍

1. 三态存进既有 `SIDEBAR_VISIBILITY` 行的新字符串键 `smartList.<enumName>`（'show'/'hide'/'auto'），不新增表、不 bump schemaVersion，跨端走既有 viewPreference outbox。`_jsonMap` 从"只留 bool"放宽为"留 bool + String"——旧键全 bool，不受影响。
2. 选中态不跟随：被隐藏的清单若正被选中，任务面板仍显示，管理页可再改回来（不在本轮做自动跳转）。
3. 已知既有缺陷 #422（pull 整行覆盖偏好）不在本轮修，三态键同样暴露在该风险下。

## 测试

- 仓储：默认全 show；save 三态各自落库 + outbox patch 不冲掉 showTags/showFilters 与其它清单键；inbox 守卫抛错；坏 JSON 回默认。
- 管理页弹层：7 行齐、inbox 固定、两档/三档按 FR-5、改档落库。
- 侧栏：默认 7 行都在；存「隐藏」行消失；「有内容时显示」无内容不出现、有内容出现。
- 入口：点设置按钮出弹层。
- 变异探针 + 全量门禁（analyze 0 issue + 全量 flutter test）按惯例执行。
