# 任务清单：高级筛选补「文件夹」这条筛选条件

基准提交：分支 `feat/333-folder-filter`，起点 `origin/develop@2ecc0f1055af`。
下列行号以该起点之上的本分支工作树为基准（改动前的对照一律标 `origin/develop`）。

## 红测先行（先看不绿，再写实现）

- [x] 求值面 `test/features/filter/folder_filter_condition_test.dart`（4 条 `test(`）：
      首跑 rc=1，失败原因是 `No named parameter with the name 'listFolderIds'`
      （红在「功能不存在」上，不是拼写错；日志 `/tmp/w/f333_redA2.log`）。
- [x] 界面面 `test/features/filter/advanced_filter_folder_condition_test.dart`（5 条 `testWidgets(`）：
      实现前 rc=1，5 条全部红在 `Found 0 widgets with key [<'task-filter-folder-section'>]`
      （干净的 finder 红，无编译错；日志 `/tmp/w/f333_redB2.log`）。
- [x] 中途否掉一个我自己的错假设：第一版把条件类型写成服务端 `int`（照抄 `TaskFilter.folderId`
      的旧声明）。核对 `lib/core/db/app_database.dart` 的 `TodoFolders` 表后改判为本地
      `String` 主键 —— `serverId` 可空，离线新建的文件夹用 int 筛不了。
      实现按 TDD 规矩撤回重来（`git restore --source=HEAD --worktree -- lib/features/task/tasks_by_list_page.dart`），
      没有留着错版本当参考。
- [x] 夹具假设立刻纠正：`TodoVisualFixtureSet.empty` 只跳过失焦任务，文件夹与清单仍会插入，
      造不出「零文件夹」态 ⇒ 改为覆盖 `foldersStreamProvider` 给空流。

## 实现

- [x] 条件类型与清空通道：`lib/features/filter/filter_bar.dart:33`（`String? folderId`）、
      `:49-50`（`copyWith` 参数含 `clearFolderId`）、`:66`（`clearFolderId ? null : folderId ?? this.folderId`）。
- [x] 草稿 → 生效条件：`lib/features/filter/filter_bar.dart:322`（`required String? folderId`）、
      `:336`（`clearFolderId: folderId == null`）。
- [x] 对话框状态与回传：`lib/features/filter/filter_bar.dart:386`（预览草稿带 folderId）、
      `:469`（`_FolderConditionSection` 插到标签小节之后）、`:568`（「应用高级筛选」回传）、
      `:665`（`_AdvancedFilter.folderId`）。
- [x] 生效判定与筛选条文案：`lib/features/filter/filter_bar.dart:673`（`_hasAdvancedFilter`）、
      `:678`（`_advancedFilterLabel` 返回「文件夹」）。
- [x] 新控件：`lib/features/filter/filter_bar.dart:761`（`_FolderConditionSection`，
      key `task-filter-folder-section`，读不出/零文件夹各有可见提示）。
- [x] 归属索引单一事实源：`lib/state/providers.dart:482`（`listFolderIndexProvider`，
      清单流没发值时返回 null 而不是空图）。
- [x] 求值分支：`lib/features/task/tasks_by_list_page.dart:2219-2221`
      （与标签同一口径：`listFolderIds == null` 是索引没就位，不在这里放行全量）。
- [x] 两个消费点同源接线：列表 `:233`+`:245`+`:254`（索引没就位且带文件夹条件时转圈，
      不画「文件夹没参与筛选」的列表）；预览 `:1706`（索引缺失给空图 ⇒ 预览报 0 项）。
- [x] `TodoFolder` 补进 `filter_bar.dart` 的 `show` 列表（该文件用 `show` 精确导入，漏了它
      analyze 会以 `non_type_as_type_argument` 报 3 处）。

## 门禁（跑在 commit 之后）

- [x] `flutter analyze` rc=0（日志 `/tmp/w/f333_full_analyze.log`）
- [x] 全量 `flutter test` 通过，golden 9 张未重录（日志 `/tmp/w/f333_full_test.log`）
- [x] 台账自扫 `python3 tool/check_spec_selfscan.py specs/084-folder-filter/spec.md`
      与 `... specs/084-folder-filter/tasks.md` 各 rc=0
      （注：这版自扫器即使 `--selftest` 也要求 positional target，漏了会 rc=2 报 usage，
      不是判据器坏）

## 本轮故意不做

- [ ] 已保存过滤器的 folderIds 持久化：要先扩 `zh-cloud-service` 的 `todo_filter.conditions`
      （现只有 `listIds/tagIds/dateRange/priorities/statuses/keyword`）。本轮维持
      `saved_filter_mapping.dart:12` 的 `skipped` 点名行为 —— 拒绝保存并说明，不静默存半个。
      ⇒ 需另立 service 契约单，客户端这面等它。
- [ ] 文件夹多选 / 跨条件「或」逻辑：属 FL #334（布尔组合），不在这一刀里顺手做。
- [x] 矩阵翻面：本轮不翻 #22 行状态 —— 该行的 ⑥（布尔组合）与 ⑦（同条件内且/或）仍缺，
      「部分」的判定不变；只把 ⑤ 的文件夹半边记为已落 develop（合并提交见 Issue #333 留言）。
