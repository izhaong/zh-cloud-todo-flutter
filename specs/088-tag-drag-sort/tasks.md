# 任务清单：侧栏标签「长按拖拽」自定义排序（specs/088）

基准提交：分支 `feat/329-tag-drag-sort`，起点 `origin/develop@22d8012bd83d`（FL 现读，开工与提交前各核一次，
`git merge-base HEAD origin/develop` 仍等于起点 ⇒ 本轮没有踩过别人的合并）。
前置：specs/082 置顶半面已在 develop；服务端排序 `TodoTagMapper`（`is_pinned DESC, sort_order DESC, id DESC`）
无需服务端改动（`todo_tag.sort_order` 列与 payload 字段已存在）。

## 实现

- [x] 本地列 `TodoTags.sortOrder`（默认 0）：`lib/core/db/app_database.dart:39`（标签表；同文件另 4 处是清单/任务分节既有列）
- [x] `schemaVersion` 26 → 27：同文件 `:453`；`onUpgrade` 的 `from < 27` + `_columnExists('todo_tags','sort_order')` 守卫，**不回填**：`:716`
- [x] Drift 生成物：`lib/core/db/app_database.g.dart`（`dart run build_runner build --delete-conflicting-outputs` 重生成）
- [x] 写路径 `TagRepository.reorder`（事务内逐行写位次 + 登记 `tag`/`upsert` outbox，payload 整行 `toJson()`；
      不存在的 id 先滤掉再连续分配；失败整批回滚）：`lib/state/repositories/tag_repository.dart:139`
- [x] 读路径两处排序改成 `isPinned DESC, sortOrder DESC, createdAt ASC`：同文件 `:34-36`（`watchAll`）、`:43-45`（`getAll`）
- [x] 入站同步认 `sortOrder`，缺键时保留本地值：`lib/core/sync/sync_coordinator.dart:1752`（`_upsertLocalTag`）
- [x] 侧栏标签分节包 `ReorderableListView`（shrinkWrap + 默认长按拖拽手柄）：`lib/features/shell/sidebar.dart:258`；
      组内判定 + 调 `reorder` 的 `_onTagsReordered`：同文件 `:643`（`onReorderItem` 的 newIndex 已做过删位调整，不再 -1）
- [x] 手势变更补偿：`_TagRow` 移除 `onLongPress`（长按给拖拽），动作表保留左滑；读屏通道挂
      `CustomSemanticsAction('置顶')`：`lib/features/shell/sidebar.dart:692`
- [x] 新增/改写用例：`test/state/tag_sort_repository_test.dart` 8 条 +
      `test/features/shell/sidebar_tag_reorder_test.dart` 3 条 +
      `test/app_database_migration_test.dart` 的 `v26→v27` 那条（`:1007`，含降档探针 `:1390`）+
      `test/features/shell/sidebar_tag_pin_test.dart` 长按用例改写为读屏 custom action 断言，合计 13 条

## 本轮改动拉长出来的既有债（认账，不是"不适用"）

- [x] 加列使 `TodoTag` 生成构造多出必填参数，`test/features/filter/advanced_filter_tag_condition_test.dart`
      的三处字面量当场编译红 ⇒ 已在三处补 `sortOrder: 0,` 后 analyze 回到 rc=0。

## 红测证据

- [x] 红测先行：`/tmp/w14_red1.log` RC=1，红在编译层 `No named parameter with the name 'sortOrder'`
      与 `The method 'reorder' isn't defined for the type 'TagRepository'` —— 列与方法都不存在，
      与 specs/082 的红测同形态，属合法红测。

## 四件套（新 UI 逐条量，不写"不适用"）

- [x] 320px + 1.3 倍字号：拖拽入口是长按手势 + 左滑动作表，两者均已在 specs/082 的 320px 用例与本轮
      `sidebar_tag_reorder_test.dart` 的窄屏 runner（`TodoVisualViewports` 同一 harness）下覆盖。
- [x] 读屏：`sidebar_tag_reorder_test.dart`「读屏：标签行自带「置顶」自定义动作」+
      `sidebar_tag_pin_test.dart` 改写后的同名通道用例（`matchesSemantics(customActions: [...])`）。
- [x] 失败可见性：reorder 登记失败 ⇒ 整批回滚（`tag_sort_repository_test.dart` 的 `_ThrowingQueue` 用例）。
- [x] 空态/边界：空列表不出事不登记、传入已删 id 不留空洞（两条仓储用例钉死）。

## 验收门禁

- [x] `flutter analyze` rc=0（`No issues found!`，2026-10-11 本 worktree 实跑）
- [x] 全量 `flutter test` rc=0：`+1563 ~26: All tests passed!`（日志 `/tmp/w14_full_test.log`，
      `grep -c "All tests passed"` = 1；期间抓出并修掉 3 处被本轮改动顶红的存量用例，见上节）
- [x] 反向探针：把 `reorder` 位次翻成「0 = 第一位」（清单那套方向）后
      `flutter test test/state/tag_sort_repository_test.dart test/features/shell/sidebar_tag_reorder_test.dart` rc=1，
      红在「reorder 后第一位拿组内最大值」与「长按「协作」拖到最上」两例；还原后文件零残留（`git status` 干净）。
- [x] `python3 tool/check_spec_selfscan.py specs/088-tag-drag-sort/spec.md` 与 `tasks.md` 均 rc=0、失项 0 条。
