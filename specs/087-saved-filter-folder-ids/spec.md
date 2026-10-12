# 规格：已保存过滤器存得下「文件夹」这一维（矩阵 #22 面 ⑤ 第 2 面的客户端半）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#527。前置：zh-cloud-service #340 已合并
  （service `origin/develop@cedbf31eb0f4`，PR !343，台账 `specs/029-filter-folder-conditions/`）⇒ 契约吃得下 `folderIds`；
  FL #333 第 1 面（按文件夹筛任务）已在 develop（`specs/084-folder-filter/`，PR !523）。
- 判据源：嘀嗒《01-任务/09-如何管理海量任务/05-过滤器》全文不出现「文件夹」（复算
  `git -C zh-cloud-docs show 'origin/develop:todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md' | grep -c 文件夹` 得 0），
  所以这一面是「客户端已有的能力不该在持久化时丢掉」，不是照抄嘀嗒某句主张。

## 改动前的缺口（基准 `origin/develop@eeeccd6f80d4`）

- `lib/features/filter/saved_filter_mapping.dart:12` 是 `if (filter.folderId != null) skipped.add('文件夹');`
  ⇒ 带文件夹条件的过滤器被**整份拒绝保存**并在对话框点名（那是契约没就位时刻意的诚实降级）。
  复算改动前：`git -C zh-cloud-todo-flutter grep -c "skipped.add('文件夹')" origin/develop -- lib` 得 1 个文件；
  本分支同一命令得 0（正对照：同一条尺在 develop 上量得出「有」）。
- `TodoFilterConditions` 没有 `folderIds` 字段、`fromJson` 的 known 集也没有 ⇒ 别的端存来的文件夹条件
  整份落进 `unsupportedKeys`，UI 标「本机暂不支持套用」。
- `conditionOrder` 只有六条 ⇒ 面板的「条件之间」小节不知道 `folderIds` 是一条可挂词的条件，
  与服务端新的七条 `CONDITION_ORDER` 分家（挂错位置的词会被服务端整份拒绝）。

## 契约

1. `folderIds` 的值是**服务端文件夹 id**（与 service 侧 `TodoFilterConditionsDO.folderIds` 同口径），
   不是本地主键。本地主键 ↔ 服务端 id 的换算只发生在映射层（`savedFilterOf` / `taskFilterFromSaved`），
   求值层继续用本地主键（`specs/084-folder-filter/` 的口径不变）。
2. **缺省不写键**：`toJson` 只在 `folderIds` 非空时出这个键 ⇒ 改动前已存在的过滤器 JSON 逐字节不变
   （用例直接比字符串，形状与 `tagLogic` / `conditionLogics` 那两条同规格）。
3. **索引没就绪 ≠ 查不到**：`folderServerIdIndexProvider` 在文件夹流还没发值时返回 null（不给空表）。
   两种情况的文案必须不同 —— 把「本机索引没到位」说成「这个文件夹还没同步上去」是一句假话。
4. **映射不到就拒绝保存并点名**（点名到具体是哪个本地主键），沿用 `skipped` 这条既有通道；
   既不静默丢掉这一维，也不把本地主键写进契约（别的端读不懂，服务端还会按未知 id 交集为空筛出空集）。
5. **读侧只认「数组 + 每项都是整数」**：形状不对退回 `unsupportedKeys`（读成空表等于丢掉一条真实存在的条件）。
   这里刻意不用现成的 `_ints` 宽容读法 —— 它会把 `"41"`、`41.5` 折算成 41，等于替用户换一个文件夹。
6. **还原不出忠实条件就返回 null**（调用方标「本机暂不支持套用」）：`folderIds` 多于一项（本机文件夹条件是单选）、
   或服务端 id 在本机反查不到，都整份不套。
7. **条件顺序表与服务端同源**：`conditionOrder` = `listIds, folderIds, tagIds, priorities, statuses, dateRange, keyword`；
   面板条件行、求值 pieces、放置校验三处共用 `activeConditionKeys()`（第 254 轮立的规矩，本轮只是把新条件接进去）。

## 已知边界（不算已验证）

- 面板的文件夹条件仍是**单选**，而契约是数组 ⇒ 「同时按两个文件夹筛」要另改面板（`#527` 里那条第 3 项，本轮没做，
  因此 #527 用 `Refs` 不用 `Fixes`）。
- 本端与服务端都**不展开子文件夹**（虽然 `todo_folders` 有 `parentId` 可嵌套）⇒ 选父文件夹而清单都在子文件夹里会筛空。
  该口径待定，记在 zh-cloud-service #344；若将来定成「含子孙」，服务端展开与本地 `listFolderIndexProvider`
  必须**同一轮**改（否则两套答案），这条已在两个仓的单子里写明。
- 真后端（test 环境）的「带文件夹条件存 → 换端套」还没跑过；本轮只证客户端两侧形状与文案。

## 验收

- 单元：`test/features/filter/saved_filter_folder_ids_test.dart`（14 条 `test(`）。
- 界面：`test/features/filter/saved_filters_test.dart` 由 11 条 `testWidgets(` 增至 12 条
  （新增「有服务端 id 时存得下、不点名」，并把原「文件夹一律不保存」的整句期望改成新点名文案 ——
  仍断言「不静默丢弃」，只是理由从「存不下」变成「这个文件夹还没同步上去」）。
- 门禁：`flutter analyze` rc=0 + 全量 `flutter test`（读数见 `tasks.md`）。
- 台账自扫：`python3 tool/check_spec_selfscan.py specs/087-saved-filter-folder-ids/{spec,tasks}.md` 失项 0。
- 复核：**未经独立复核**（claude `-p` 的 VERDICT 通道 0 字节）。替代判据 = 红测先行 + 反向探针 + 两道门禁。
