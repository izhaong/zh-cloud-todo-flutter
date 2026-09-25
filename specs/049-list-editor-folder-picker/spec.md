# 049 · 清单编辑器的「所属文件夹」（Issue #339 的第一子面 / 矩阵 #19）

基准 `origin/develop@9032005`；分支 `feat/339-list-editor-folder-picker`。
specs 编号 049：`develop` 上最大 044，未合并分支已占 045（`!347`、`!319` 同号）、046（`!322`）、047（`!350`）、048（`!351`）。

## 判据源（逐字，`zh-cloud-docs` **`origin/develop`**）

`todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md`（`wc -l` = 119）

| 行 | 原文 |
| -- | ---- |
| `:73` | 「你可以设置清单的「名称」、「颜色」、「所属文件夹」及「在智能清单中显示/隐藏」。」 |

⇒ 编辑器是**四个字段**：名称 / 颜色 / 所属文件夹 / 显示隐藏。本单（#339）列的是缺的三个：颜色、所属文件夹、Emoji 图标。

## 本轮范围（只做「所属文件夹」，其余照实挂账）

`所属文件夹` 是三者里唯一**不需要动数据模型**的：本地 `todo_lists.folderLocalId` + `folderId` 已存在
（`lib/core/db/app_database.dart:35/:38`），仓库层已有 `ListRepository.create(folderLocalId:)`（`:60-64`）
与 `ListRepository.moveToFolder(listId, folderLocalId)`（`:113-149`，含 `list/upsert` outbox），
服务端契约也在（`AppTodoFolderMoveListReqVO.folderId`、`TodoListDO.folderId`、`TodoListMapper.countByFolderId`）
⇒ **纯客户端接线**。
「颜色」与「Emoji 图标」要新增列（本地 `schemaVersion` 22 与后端 `TodoListDO` 都没有），
属"先修后端契约再动前端"的那类，本轮不碰，保持 Issue #339 open 并记进 tasks.md 的下一轮入口。

## 现状判据（`origin/develop@9032005` 实读）

- `git grep -n "所属文件夹" origin/develop -- lib` **0 命中**（正向对照：同命令查 `清单名` 命中 `list_editor_sheet.dart:73`）。
- `lib/features/list/list_editor_sheet.dart` 全文 101 行：输入面只有 `:70-77` 一个「清单名」`TextField`，
  `folderLocalId` 是**构造参数**（`:10`）⇒ 只有"从文件夹里点新建"这一条路能带上文件夹；
  三个调用点里 `list_actions.dart:98`（左滑/长按编辑）与 `sidebar.dart:902`（侧栏新建）都传 `null`
  ⇒ 用户在编辑器里既看不到也改不了归属。

## 需求

- **FR-1** 编辑器里出现「所属文件夹」，取值 = 「无」+ 每一个已有文件夹（嵌套文件夹显示成 `父 / 子` 路径，与侧栏同一套父子关系）。
- **FR-2 新建**：选中的文件夹就是新清单的归属；没选 ⇒ 「无」（顶层），与今天侧栏入口的行为一致。
- **FR-3 编辑**：打开时必须预选清单**当前**的归属；改选后保存要真的移入/移出（`moveToFolder`），并留下 `list/upsert` outbox 记录 ⇒ 另一台设备 pull 后组织关系一致。
- **FR-4** 只改名不动文件夹 ⇒ 不多打一条移动记录（不产生"看着没动却同步了一次"的假变更）。
- **FR-5** 从文件夹里点「新建」进来时，预选那个文件夹（今天的隐式行为不能被这次改动弄丢）。
- **FR-6** 四件套（新增可见控件）：320px + 1.3 倍字号在**弹层自己的 context** 上实测；读屏念得出「所属文件夹 + 当前值」；保存失败（仓库为 null / 移动抛错）时弹层不关、已填的清单名与已选归属都还在，并给可见提示；归属以"点中的字面值"写入，不由异步回读推导。

## 取舍

1. **控件用受控 `DropdownButton` 包在 `InputDecorator` 里，不用 `DropdownButtonFormField`，也不用嘀嗒的"点开一层列表"**：
   `DropdownButtonFormField` 把值交给 `FormFieldState` 自己持有，我传的 `value` 只在首帧生效
   （"选完界面不更新"就是这么来的）⇒ 本轮受控字段在 `_ListEditorSheetState` 里。
   帮助页 `:73` 只承诺"能设置所属文件夹"，没写控件形状；离线镜像取不到配图 ⇒ 不猜交互，选最省的一种，
   并把"控件形状未经核对"写进矩阵备注（不宣称"一字不差"）。
2. **不显示「收集箱」**：收集箱不是清单（`inbox` 是虚拟归属），列出来等于给用户一个选不动的选项。
3. **智能清单不出现在这里**：编辑器只服务普通清单；`moveToFolder` 自己会抛「智能清单不支持移动到文件夹」，本轮不让用户有机会点进去。
4. **顺手不加"新建文件夹"入口**：那是 #312（文件夹管理入口）的范围，塞进本单会把两个 Issue 的证据搅在一起。
