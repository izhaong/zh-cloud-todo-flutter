# 规格：侧栏标签「长按拖拽」自定义排序（矩阵 #21 面 ⑥ 的拖拽半面）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#329（置顶半面已由 specs/082 落地）
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径以 zh-cloud-docs `origin/develop` 为准）：
  `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md`
  - `:118`「通过在侧边栏「长按标签」即可进行拖拽，可以对清单进行自由排序」

## 缺口（改动前，基准 `origin/develop@22d8012bd83d`）

- 本地库没有标签位次列：`TodoTags` 表定义处 `grep -c sortOrder` 为 0，
  `lib/state/repositories/tag_repository.dart` 的排序只有 `isPinned DESC, createdAt ASC`，
  拖完的顺序没有任何字段可落。
- 复算（在 FL 仓根跑）：
  - `git grep -c sortOrder origin/develop -- lib/core/db/app_database.dart` ⇒ 无该 ref 命中即 0
    （本轮改动后 ≥1，且 `lib/state/repositories/tag_repository.dart` 出现 `sortOrder DESC`）
  - `git grep -n "ReorderableListView" origin/develop -- lib/features/shell/sidebar.dart` ⇒ 0 命中
    （同一条命令把串换成 `Dismissible` 得非 0 命中，证明判据本身不是恒假）

## 契约

1. **本地列**：`TodoTags` 加 `sortOrder`，默认 `0`；`schemaVersion` 26 → 27，`onUpgrade` 里 `from < 27` 且
   `_columnExists('todo_tags','sort_order')` 为假时 `addColumn`。**加列不回填**：存量全 0 时并列塌到
   `createdAt ASC`，升级前后界面顺序零变化；也避免迁移即向服务端推出全量 upsert。
2. **排序语义与服务端同源不同向**：服务端 `TodoTagMapper` 是 `is_pinned DESC, sort_order DESC, id DESC`
   —— **值大在前** ⇒ 本仓 `reorder` 传入顺序的第一位拿组内**最大**值。与 `ListRepository.reorder`
   （specs/054，0 = 第一位）**同形不同向**，两处不许互相抄。
3. **本地读路径三键**：`watchAll`/`getAll` 改成 `isPinned DESC, sortOrder DESC, createdAt ASC`。
   本地主键是 UUID 无序，tie-break 用 `createdAt ASC` 对齐服务端 `id DESC` 的「先建在前」直觉。
4. **写路径**：`TagRepository.reorder(orderedIds)` 一个事务内改位次并逐行登记 `tag`/`upsert` outbox
   （与 `ListRepository.reorder` 同口径：组内每行都登记，payload 走整行 `toJson()`）；
   传入的 id 有已删除的 ⇒ 先滤掉再给幸存行连续位次（不留空洞）；空列表不出事、不登记；
   任一条登记失败 ⇒ 整批位次回滚、outbox 不留半条。
5. **入站同步**：`SyncCoordinator._upsertLocalTag` 认 payload 里的 `sortOrder`；**没带这个键时保留本地值**，
   不替用户归零（与 isPinned 同族）。
6. **入口形态**：标签分节包 `ReorderableListView`（`shrinkWrap` 嵌侧栏滚动、默认长按拖拽手柄，外观不变）；
   **只允许 `(isPinned, parentId)` 相同的组内换位**，跨组拖拽 no-op（置顶区领头 + 树平铺连续，跨界必拒）。
7. **手势变更要补偿读屏**：标签行长按已改给拖拽手柄，specs/082 的「长按唤出动作表」随之失效 ⇒
   动作表保留左滑通道，并给标签行挂 `CustomSemanticsAction('置顶')` 读屏通道 —— 可达性承诺不回退。

## 范围外

- 桌面端「右键标签」手势（`:94`）不在本轮，留在 #329。
- 矩阵 `#21` 行的翻面：等本轮 PR 合并后按合并 SHA 写，只翻「拖拽半面」，不整行改判。
- 清单（`ListRepository.reorder`）与任务的拖拽排序不动。
