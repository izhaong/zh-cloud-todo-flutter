# 任务：清单「Emoji 图标 + 背景 + 在智能清单中显示」客户端全链（FL #339/#340）

- [x] T001 落 specs/105 台账（本文件 + spec.md；判据源镜像 `02-用清单管理任务.md` :73/:86/:87/:103-:111/:118 现读确认）
- [x] T002 实现：Drift 四列 + 迁移 v29→v30 → 仓储 create 四参 + setIcon/setBackground/setShowInSmartList → sync pull 四键三态 → list_properties.dart（候选/检测/渐变/装饰/背景弹层）→ 编辑器 Emoji + 开关 → 动作表「背景」入口 → 侧栏行首 Emoji → applyTaskFilter excludedListIds 闸门 → taskStatsProvider 排除
- [x] T003 测试 7 文件（仓储 6 用例 / sync 1 用例 / 编辑器 4 用例 / 背景 4 用例 / 闸门 3 用例 / 侧栏 2 用例 / 迁移 1 用例），analyze 0 issue
- [x] T004 变异探针 4 条各自红、还原 `cmp -s`（见 spec「测试与探针」）
- [x] T005 门禁：`dart format`、analyze 0 issue、全量 `flutter test`（commit 后跑，日志 /tmp/fl-gate-282.log）
- [x] T006 收口：push → PR（Refs #339 #340）→ 合并 → #339/#340 留言 → docs 矩阵 #19 追记（含「所属文件夹」格订正）→ 父仓 bump
- [x] T007 入口形态补齐（嘀嗒 `:96` 详情页右上角「...」-「背景」）：`task_workspace_header.dart` 菜单项 + 独立路由 AppBar「…」，收集箱与未选中清单不出该项；`test/features/task/list_background_entry_test.dart` 3 例；探针 ⑤ 恒真 → 两条负向红
