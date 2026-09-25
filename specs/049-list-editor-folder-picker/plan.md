# 049 · 计划（Issue #339 第一子面）

基准 `origin/develop@9032005`；分支 `feat/339-list-editor-folder-picker`。判据与取舍见同目录 `spec.md`。

## 落点

| 文件 | 动什么 |
| ---- | ------ |
| `lib/features/list/list_editor_sheet.dart` | 唯一的实现文件：State 多持有 `_folderLocalId` 与 `_error`；`build` 里加一格 `InputDecorator(labelText: '所属文件夹')` 包受控 `DropdownButton<String?>`；`_save` 改成"先移动后改名"，失败写可见提示且不关弹层 |
| `test/features/list/list_editor_folder_picker_test.dart` | 新增 14 条用例（归属读写 4 + 四件套 4 + 负路径/降级 5 + 嵌套命名 1）；最终数字见 `tasks.md` 探针表 |
| `specs/049-list-editor-folder-picker/*.md` | 本规格 |

**不改**：数据模型（`folderLocalId`/`folderId` 列已在 `app_database.dart`）、`ListRepository`（`create` 已收 `folderLocalId`，`moveToFolder` 已含 `list/upsert` outbox）、`providers.dart`、路由、侧栏、`schemaVersion`（仍 22）。
⇒ 后端契约不缺，本轮没有 service 侧改动。

## 实现上三个"必须先想清楚"的点

1. **受控而不是 FormField**：`DropdownButtonFormField` 的值归 `FormFieldState`，外部传入的 `value` 首帧后失效
   ⇒ 用 `DropdownButton` + 自己 State 里的 `_folderLocalId`。
2. **候选里必须始终有"当前值"那一格**：`DropdownButton` 会断言"恰好一项与 value 相同"。
   文件夹来自异步 stream，首帧没数据、或归属指向已删除的文件夹时都会踩这条断言
   ⇒ 补一格占位（`加载中…` / `（已删除）`）。
3. **失败顺序**：先 `moveToFolder` 后 `rename`。反过来会出现"名字改了、移动失败"的半改状态，
   而弹层里用户看到的还是自己刚填的名字 ⇒ 重试时已经分不清改没改成。

## 验证计划

- 用例本身即红测：`PA`（develop 字节）下 15 条里 14 条红（唯一绿的是「只改名不动文件夹」，理由见 `tasks.md`）。
- 反向探针 `PB…PQ` + `PR`/`PS`/`PU`：每条只抽掉一个行为（不传归属 / 不移动 / 无脑移动 / 失败不给提示 / 失败也关弹层 /
  不预选 / 去掉语义合并 / 去掉占位候选 / 改成非受控 / 先改名后移动 / 失败清空已选 / 菜单永不展开 /
  丢父链 / 仓库为 null 静默 / 新建失败文案 / 候选超大），要求**各自红在该红的那条用例上**；
  红不了的探针（`PR`/`PS`/`PU` 证明展开态没有溢出判据）如实写进 `tasks.md`，不假装覆盖。
- 读屏：以实测语义树为准（探针输出与两版对照见 `tasks.md`），不用"应该有 label"这种推断。
- 六门禁跑在最终字节上，日志原文抄进 `tasks.md`。

## 相撞面

`lib/features/list/list_editor_sheet.dart` 与 `test/features/list/` 在 8 条 open PR（!351 !350 !347 !346 !322 !319 !314 !311）
的改动文件表里**均无命中**（逐条 `/pulls/N/files` 对过）⇒ 无同文件相撞，不需要 merge-tree。
