# 规格：文件夹筛选按子树求值（客户端那一半，与 service Issue #344 同轮）

- 来源：zh-cloud-service Issue #344（父文件夹不含子孙 ⇒ 选父文件夹而清单都在子文件夹时筛出空集）。
  服务端那一半已在 zh-cloud-service 分支 `feat/344-folder-descendants`（台账 `specs/030-folder-descendant-filter/`）。
- 零 DDL、零新列：改的是「清单 → 文件夹」这份本地索引的**语义**，`todo_lists.folder_local_id` 与
  `todo_folders.parent_id` 都照旧。

## 为什么客户端必须同一轮改

侧栏按层级渲染文件夹（`flattenSidebarHierarchy(..., parentIdOf: (folder) => folder.parentId)`），
而清单只挂在**直属**文件夹上。服务端把 `folderIds` 展开成「种子 ∪ 子孙」之后，
如果本地即时筛选还按直属算，同一个父文件夹条件就会有两套答案：

- 列表按直属算 ⇒ 空；
- 服务端 `apply` 按子树算 ⇒ 有。

这正是记在 FL 台账里那条「parse 与 evaluate 必须同轮」的同一类错，所以不能只改一边。

## 契约（客户端侧）

1. `listFolderIndexProvider` 的值由「清单 → 直属文件夹主键」改成
   **「清单 → 所在文件夹以及其全部祖先」的集合**；筛选求值只要「条件的文件夹 ∈ 这个集合」。
2. 任一来源流（清单流、文件夹流）还没发值 ⇒ 索引算**没就位**（返回 null，调用方继续等）。
   只按直属算的那张图会把父文件夹条件读成「零命中」，不许拿它当"已就位"。
   两边都发过值但清单为空 ⇒ 给空图而不是 null（否则带文件夹条件的人一直转圈）。
3. 祖先链走到未知 id 就停（未知 id 原样留在集合里，不猜也不丢）；`visited` 同时挡重访，
   所以脏数据造成的父链成环只会得到有限集合，不会转不完。
4. 「列表」与「预览命中数」共用同一份索引：两处都读 `listFolderIndexProvider`，
   复算 `git grep -n listFolderIndexProvider origin/develop -- lib` 得两处命中（列表侧与预览侧各一处）。

## 不在本轮范围

- 面板的文件夹条件仍是单选（契约 `folderIds` 是数组）。多选按 zh-cloud-docs Issue #161 的判定属增强项、
  不记为 parity 缺口，本轮不顺手改。
- 已保存过滤器的 `folderIds` 存取（FL `specs/087-saved-filter-folder-ids/`）不改形状；
  本轮改的是"这个文件夹条件在本机怎么算"，两边共用同一份索引语义。
