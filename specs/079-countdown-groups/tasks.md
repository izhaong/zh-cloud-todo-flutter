# 任务清单

## 第 202 轮（显示分组，未收口）

- [x] 契约核对：后端 `AppTodoCountdownRespVO` 已透出 `type`，本轮纯读侧接线
- [x] 取号：FL develop 到 078，扫全部远端分支后 079 未被占
- [x] 红测：实现前编译挂 `Error: No named parameter with the name 'type'`
- [x] 实现：`CountdownDto.type`、`_showGroups`、「显示分组」菜单项、四档渲染与 `_tileFor` 抽公共卡片
- [x] 单文件读数：`flutter test test/features/countdown/countdown_group_test.dart` 现读 `00:01 +8: All tests passed!`
- [x] 四件套的「独立读屏语义」按 FL #455 的改法立住了：分组标题改成 key、label、header 同在 `Semantics` 外层包壳，内层 `Text` 用 `ExcludeSemantics` 包住；断言读该节点自己的 `SemanticsController.label`。
  两条踩过的写法记在这：`find.descendant(of: byKey, matching: bySemanticsLabel)` 恒 0（label 不在子孙上），整屏 `bySemanticsLabel('倒数日')` 会被 AppBar 标题满足。
  反向对照跑过：把 `label: entry.value` 摘掉后该用例红（报「第 1 档标题的 label 不对」），还原后 `cmp` 与备份逐字节相同。
- [x] 六道门禁在最终字节上各跑一次（日志 `/tmp/gates-455.log`）：`git diff --check` rc=0；`dart format --output=none --set-exit-if-changed` 本轮 3 个文件 `Formatted 3 files (0 changed)` rc=0；`flutter analyze` `No issues found!`；`flutter test --tags golden` `00:05 +9: All tests passed!`（基线 9 张未重录）；`flutter test --exclude-tags 'golden || performance' --concurrency=1` `03:41 +1373 ~26: All tests passed!`；`flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` `✓ Built build/web`
- [ ] 只读复核：`claude -p` 本日多次派单 0 字节，本轮未取到 VERDICT，按「六道门禁＋merge-tree 试算」推进并登记未复核
- [x] 台账自扫：`python3 tool/check_spec_selfscan.py specs/079-countdown-groups/tasks.md` 输出 `失项 0 条`
- [ ] 矩阵 #50 的分组面等本 PR 合并后按合并 SHA 改判
- [ ] 同页 :13 的顶部分组名点击与左右滑切换仍未做（改可见布局，按约定先申请重录 9 张黄金图）
