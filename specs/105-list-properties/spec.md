# 规格：清单「Emoji 图标 + 背景 + 在智能清单中显示」客户端全链（FL #339/#340，矩阵 #19）

## 判据源（嘀嗒原文）

镜像 `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md`（docs 仓）：

- `:73`「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」
- `:86`「在清单编辑页面，点击名称前面的「图标」，选择需要的 Emoji 表情」（方式一）
- `:87`「清单名称最前面输入 Emoji 表情，可自动设置为清单的图标」（方式二）
- `:103-:111` 背景四样式：跟随应用主题 / 颜色背景 / 渐变背景 / 图片背景
- `:118`「已完成」「已放弃」「垃圾桶」不支持设置背景

## 契约前提（service !354 已合并，svc develop `4760c203abe2`）

- `todo_list` 四列：`icon` / `background_type`（默认 theme）/ `background_value` / `show_in_smart_list`（默认 1）。
- 增量出站 `TodoListServiceImpl` payload 带同名 camelCase 四键；camel/snake 双拼写入站都收。
- FL 侧本单补：Drift 四列 + 迁移、仓储写路径、sync pull 三态、编辑器/侧栏/背景弹层 UI、智能清单排除闸门。
- specs/102 已落「颜色」、specs/103 已落「智能清单三态管理」、specs/104 已落「指派给我」；本单收掉 :73 剩余三属性 + :86/:87 图标 + :103-:111 背景。

## 需求与裁定

1. **Drift**：`TodoLists` 加四列；schemaVersion 29→30；迁移只加列不回填（默认值=改造前真实行为：theme / 显示）。
2. **仓储**：`create` 接四参；新增 `setIcon` / `setBackground` / `setShowInSmartList`，与 `setColor` 同口径（写列 + list/upsert outbox，payload 走整行 `toJson()` 自动带四键）。`setBackground` 守卫：`inbox` 与 `smart:` 前缀清单抛 ArgumentError（:118 三例外在本端是智能清单）；type 空串归 `theme`；theme 档强制 value null。
3. **sync pull 三态**：键在场跟随对端（显式 null 即清除）；键缺席保留本地值；`backgroundType` 空串归 `theme`。
4. **编辑器**（方式一 + 方式二）：名称行前置 48px 图标钮（点它清图标=「无」）；下方 44px 横滚 Emoji 候选（24 个，取值本端裁定）；名称首 rune 命中 Emoji 区段时自动采纳为图标，**显式选过（含显式清除）时不抢用户决定**；「在智能清单中显示」SwitchListTile。
5. **背景弹层**：入口两处——① 清单详情页右上角「...」里的「背景」（嘀嗒 :96 的原始形态：内嵌变体走那枚排序菜单，独立路由变体走 AppBar 上的「…」，两处同一 item key `todo-list-background-entry`）；② 侧栏清单动作表「背景」。收集箱与未选中具体清单（智能清单浏览）两档都不出现该项。四档单选 + 色板/渐变预设/图片 URL；保存失败错误就地显示。
6. **渲染**：侧栏清单行有 `icon` 时行首显示 Emoji（无则默认图标，语义不变）；清单详情页 body 按背景装饰（theme→null、color→底色、gradient→上到下渐变、image→NetworkImage cover；无效值一律回 null 不炸）。
7. **智能清单排除闸门**：`applyTaskFilter` 加 `excludedListIds` 硬闸门（与 lockedAssigneeUserId 同层，跨条件逻辑词点不到，永远按「且」）；只在 `selectedListId == null`（智能清单浏览）时排除，点进清单本身仍全量可见；空集走 fast-path 直通。侧栏徽章计数（taskStatsProvider）同步排除。

## 诚实登记

- Emoji 候选 24 个、渐变预设 4 对：**本端裁定**，嘀嗒未公开面板内容。
- 图片背景用 URL 直存直渲（NetworkImage），嘀嗒有上传/图库，那部分不在本单谎称已对齐。
- 详情页的背景铺在「任务列表区域」上（DecoratedBox 包住 modeBody），不是嘀嗒那种含头图的整屏背景；侧栏动作表那处入口是额外的可达路径，与嘀嗒 :96 的详情页入口并存。
- 服务端 SQL（!354 两个文件）已在 test 环境执行、prod 未执行（改数据需单独批准）。

## 测试与探针

- 仓储：`test/state/list_properties_repository_test.dart` —— create 四属性 payload 键 / setIcon 双向 / setBackground theme 清值与空串归一 / setBackground 拒 inbox+smart: / setShowInSmartList 双向。
- sync：`test/sync_coordinator_list_properties_pull_test.dart` —— 四键三态（跟随/清除/保留）+ 空串归 theme。
- 编辑器：`test/features/list/list_editor_icon_smart_test.dart` —— 选 Emoji 落库带 payload / 方式二自动采纳 / 方式一优先于方式二 / 关开关落库。
- 背景：`test/features/list/list_background_sheet_test.dart` —— 选色保存 / 未选色报错不落库 / theme 清值 / 智能清单守卫错误文案。
- 入口：`test/features/task/list_background_entry_test.dart` —— 选中普通清单时「...」里有「背景」且点开进弹层 / 收集箱不给 / 智能清单浏览不给（每条负向都先证菜单已展开）。
- 闸门：`test/features/filter/excluded_list_ids_test.dart` —— 智能浏览排除 / 选中清单不排除 / 空集 same() 直通。
- 侧栏：`test/features/shell/sidebar_list_emoji_test.dart` —— 有 Emoji 渲染 Emoji 且默认图标消失 / 无 Emoji 不凭空出现。
- 迁移：`test/app_database_migration_test.dart` 新增 v29→v30 用例（四列存在、存量行默认值、行不丢）。
- 变异探针（commit 后跑，各自红、还原 `cmp -s`）：①applyTaskFilter 拆排除闸门 → excluded_list_ids 红；②setBackground 拆 smart: 守卫 → 仓储测试红；③detectLeadingEmoji 恒 null → 方式二红；④侧栏 emoji 分支拆掉 → sidebar_list_emoji 红；⑤「背景」项的渲染条件恒真 → `list_background_entry_test` 两条负向红。
