# 规格：清单「颜色」属性端到端（FL #339，矩阵 #19 ⑦）

## 判据源（嘀嗒原文）

镜像 `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md`（docs 仓）：

- `:73`「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」

 Issue izhaong/zh-cloud-todo-flutter#339 的范围订正留言（2026-09-28）：三面里「所属文件夹」已落地，剩「颜色」与「Emoji 图标」两面；**本规格只做「颜色」，Emoji 图标不在此单**。

## 契约前提（已就绪，本单零 SQL）

- 服务端 `todo_list.color` 已合并 develop：`TodoListDO.color`、`AppTodoListBaseVO.color`、增量出站 `TodoListServiceImpl:251` `payload.put("color", …)`、回归 `TodoListColorSyncPayloadTest`（svc origin/develop 现读）。
- FL 侧既有：Drift 列 `TodoLists.color`（`app_database.dart:137`，nullable text）、生成类 `toJson()` 含 `'color'` 键、pull 侧 `sync_coordinator.dart:1746` `color: Value(payload['color']?.toString())`。
- 缺口：FL 仓储写路径（create/update）不接 color、编辑器无选择器、侧栏不渲染色。

## 需求与裁定

1. 编辑器色板：新建与重命名弹层各给一排色板（10 色 + 「无」），存 `#RRGGBB` 字符串进 `TodoLists.color`。**色板具体取值本端裁定**（嘀嗒未公开色值）；「无」= 清除颜色（写 null）。
2. 仓储：`create` 接 `String? color` 落列；新增 `setColor(listId, color)`（更新 + list/upsert outbox，payload 走 `toJson()` 自动带 `'color'` 键，与 `rename`/`setPinned` 同口径）。
3. 渲染：侧栏清单行（`_ListRow`）在 `list.color` 非空时把行首图标着成该色；清空色回退默认色。
4. 形态差异不算缺：嘀嗒没有公开色板交互截图细节，本端用 Wrap 圆点色板；「在智能清单中显示/隐藏」格不在本单。

## 诚实登记

- 色板取值、圆点视觉均为本端裁定，嘀嗒原文只约束「有颜色这个属性」。
- 色只影响侧栏行首图标；嘀嗒里颜色还影响清单详情页头图等表现，那部分跟随后续轮次（不在本单谎称已对齐）。
- 服务端增量 SQL `todo-m14-list-color-2026-09-28.sql` 未在任何环境执行（改数据需单独批准）；代码层契约完整，不影响本单客户端接线。

## 测试与探针

- 页面级（恰红起点）：`test/features/list/list_editor_color_test.dart` —— 色板行渲染、选色新建落库、编辑改色走 setColor。
- 仓储：`test/state/list_color_repository_test.dart` —— create(color) 写列且 payload['color'] 同步、setColor 更新且 payload['color'] 同步、setColor(null) 清色。
- 渲染：`test/features/shell/sidebar_list_color_test.dart` —— 有色清单行首图标颜色 == 解析值、无色回退默认。
- 变异探针：①create 不落 color 列 → 仓储测试红；②setColor 不 enqueue → 仓储测试红；③编辑器色板 key 删掉 → 页面测试红；④侧栏解析函数返回恒 null → 渲染测试红。
