# 规格：侧栏标签「置顶」接线（矩阵 #21 面 ⑥ 的置顶半面）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#329（面 ⑥ 的另半面「长按拖拽自定义排序」不在本轮）
- 前置契约：izhaong/zh-cloud-service #318 已合并，`todo_tag.is_pinned` 与服务端排序在 service `origin/develop@944ae83b9019`
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径以 zh-cloud-docs `origin/develop` 为准）：
  `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md`
  - `:79`「在侧边栏左滑某个标签，会出现「置顶」「编辑」和「删除」3个选项。」
  - `:94`「右键单击某个标签，会出现「置顶」「编辑」和「删除」等选项，点击「编辑」选项，即可进入「标签编辑」页面。」

## 缺口（改动前，基准 `origin/develop@b7802f684b70`）

- 本地库与模型没有标签置顶位：`grep -c isPinned` 在 `TodoTags` 表定义处为 0，`lib/state/repositories/tag_repository.dart` 的
  `watchAll`/`getAll` 只按 `createdAt` 升序排，没有任何置顶项。
- 侧栏标签行没有唤出动作的入口：`lib/features/shell/sidebar.dart` 的 `_TagRow` 只有 `SidebarDropZone` + `_SidebarRow(onTap:)`，
  既没有清单行那样的 `Dismissible`，也没有 `onLongPress`。
- 复算（在 FL 仓根跑，两条都要跑，只跑第一条会漏掉「有名字没接线」这一类）：
  - `git grep -c isPinned origin/develop -- lib/state/repositories/tag_repository.dart` ⇒ 无该 ref 命中即 0（本轮改动后为 6）
  - `git grep -n "todo-sidebar-tag-swipe" origin/develop -- lib` ⇒ 0 命中（同一条命令把串换成 `todo-sidebar-list-swipe` 得 1 命中，
    证明判据本身不是恒假，只是标签侧确实没做）

## 契约

1. **本地列**：`TodoTags` 加 `isPinned`，默认 `false`；`schemaVersion` 25 → 26，`onUpgrade` 里 `from < 26` 且
   `_columnExists('todo_tags','is_pinned')` 为假时 `addColumn`。加列不回填：存量标签本来没有置顶位，
   未置顶就是它们的真实状态（与清单 `is_pinned` 同一口径，见 specs/081）。
2. **写路径**：`TagRepository.setPinned(tagId, pinned)` 一次事务内落本地列并登记一条 `tag`/`upsert` outbox，
   payload 走整行 `toJson()` ⇒ 字段名与服务端 `AppTodoTagBaseVO.isPinned` 对齐。
3. **读路径**：`watchAll` 与 `getAll` 都改成「`isPinned` 降序领头 + `createdAt` 升序」，
      复算 `grep -c "t.isPinned, mode: OrderingMode.desc" lib/state/repositories/tag_repository.dart` ⇒ 2
   （侧栏树与筛选器共用同一份读法，顺序一旦不一致，用户点一下就看到列表跳变）
4. **入站同步**：`SyncCoordinator._upsertLocalTag` 认 payload 里的 `isPinned`；**没带这个键时保留本地值**，
   不能静默把已置顶的标签刷成未置顶。
5. **入口形态**：侧栏标签行左滑（`DismissDirection.endToStart`）唤出动作表，长按唤出同一张表；
   动作表里**只放「置顶」一项**。「编辑」「删除」在点标签行即到的那一层
   （`home_shell.dart` 的 `onSelectTag: (tagId) => _openTags(initialTagId: tagId)` 落到 `TagPage` 的
   `Icons.edit_outlined` / `Icons.delete_outline`），在侧栏这张表里再放两个只会跳转的磁贴，
   就是「菜单里有、点了不做事」的假档 —— 本端与嘀嗒的差别记成**交互层级不同**，不写成"一字不差"。
6. **失败要可见且不丢数据**：置顶写失败时动作表不关、错误文案就在磁贴上方（key `sidebar-tag-pin-error`），
   已加载的标签列表不得被冲掉、本地置顶位不得被改脏。
7. **不做独占置顶**：服务端与本地都允许多个标签同时置顶（标签这页原文没有「只支持置顶一个」那种话，
   那句只在《03-管理倒数纪念日.md:204`，倒数纪念日因此才在 `TodoCountdownServiceImpl.java:92` 做互斥归一）。

## 范围外

- 面 ⑥ 的拖拽半面（`:118`「通过在侧边栏「长按标签」即可进行拖拽，可以对清单进行自由排序」）仍缺，留在 #329。
- 桌面端「右键标签」手势（`:94`）不在本轮：本端侧栏右键未实现，走的是左滑/长按同一张表。
- `TagPage` 里那套「编辑标签」弹窗（名称/颜色/父标签）不搬动、不改文案。
- 矩阵 `#21` 行的翻面：等本轮 PR 合并后按合并 SHA 写，且只翻「置顶半面」，不整行改判。
