# 计划：快速添加弹窗的「从模板添加」

基准 `origin/develop@a1d7733`，分支 `feat/todo-quick-add-from-template`。规格见 [`spec.md`](spec.md)。

## 落点与复用（不新造链路）

| 面 | 落点 | 为什么落这里 |
| -- | ---- | ------------ |
| 入口 | `lib/features/task/task_quick_add_sheet.dart` 下方那一行行首的 `PopupMenuButton`（key `todo-quick-add-more`） | 嘀嗒原话「任务输入弹窗**下方**的「...」按钮，选择「模板」」；同一行右侧已有 取消/保存，插在行首不改既有顺序 |
| 模板列表 | `_QuickAddTemplatePicker`（同文件，root key `todo-quick-add-template-sheet`）由 `showModalBottomSheet` 打开 | 与任务详情已有的模板区同源：`repo.watchAll()` + `已同步/等待同步` + 空态「暂无本地模板」，措辞与判据保持一致，不再实现第二份列表逻辑 |
| 建任务 | `templates.taskSeed(t)` → `taskRepository.create(listId, parentTaskId, title, description, priority)` | 这一对是任务详情「应用」按钮已验收的链路（`task_detail_pane.dart:3573-3580`），本切片只是把它接进添加流程 |
| 上传/同步 | 完全不动 | 模板与任务的 outbox 由既有 `SyncChangeQueue` / `sync_coordinator` 承担；服务端模板 app-api 已齐，无契约改动 |

## 关键取舍（含被否）

- **即刻建任务，不预填表单**：本弹窗没有「说明」输入，而模板一定带 `description` ⇒ 预填要么新增一个嘀嗒弹窗里没有的字段（改可见布局），要么静默丢数据。
  嘀嗒写的是「选择「模板」**即可**从模板添加任务」⇒ 即刻添加。
- **移动端 IA 优先**：桌面端「输入框下拉」与「/」斜杠菜单不在本切片（斜杠菜单全仓 0 命中，属 #6 的独立一面）。
- **`_applyingTemplate` 早退守卫**：`showModalBottomSheet` 的回调在等待 `create` 期间仍可被再次点中 ⇒ 同帧双 tap 会建两条重复任务。守卫必须被探针咬住，不能只靠「看起来会拦住」。
- **不引入 `picking` 之类的额外状态**：pop 只需 `sheetContext.mounted` 判定；先前写的 `picking` 布尔与守卫重复，已删。

## 测试设计（`test/features/task/quick_add_from_template_test.dart`，8 例）

1. 下方「...」存在、展开后有「模板」，且该项是独立语义节点。
2. 挑一条即建任务：`listId` = 弹窗清单、`description`/`priority` 来自模板、提示「已应用模板“X”」。
3. 子任务弹窗里选模板 ⇒ 新任务 `parentTaskId` 仍是同一父任务。
4. 无模板 ⇒ 「暂无本地模板」，且没有「添加」可点、不建任何任务、outbox 不留半条。
5. 模板仓储 `null`（未登录）⇒ 提示「请先登录」，不是点了没反应。
6. 建任务失败（父任务跨清单被拒）⇒ 弹窗不关、已输入标题不丢、给**原因**而不是通用文案。
7. 同帧连点两次「添加」⇒ 只建一条。
8. 320px + 1.3 倍字体：弹窗与模板弹层**各自 context** 的 scaler 档位传到位且无溢出异常。

写用例时踩到的两处自伤（记下来防重犯）：

- 第 2/3/7 例最初按标题查新建任务 ⇒ 命中 **2 条**，因为**模板的来源任务本身就叫这个名字**。必须 `exceptId: source.id` 排除，否则断言自己造假阳性。
- 第 5 例原本 seed 了模板，而 `saveTask` 会往 outbox 写一条 ⇒ 「outbox 为空」成了假断言。改为该例不 seed。

## 反向探针（判据：摘掉生产代码必须看到对应红，恢复后 `cmp -s` 一致）

| 探针 | 摘掉什么 | 期望 |
| ---- | -------- | ---- |
| PA | 整个 `PopupMenuButton` | 入口不存在 ⇒ 8 例全红 |
| PB | `parentTaskId: widget.parentTaskId,` | 第 3 例红；第 6 例也应红（失败路径本身经由 parent 归属校验） |
| PC | `description: seed.description,` | 第 2 例红（丢数据） |
| PD | `if (_applyingTemplate) return;` | 第 7 例红（重复建） |
| PE | 未登录分支的 `_toast('请先登录')` | 第 5 例红（静默无响应） |
| PF | `on StateError catch` 那一支 | 第 6 例红（只剩通用文案） |

## 门禁

六项一次跑完，日志 `/tmp/gate-036.log`；`dart format` 只作用于本轮两个显式文件（禁止整仓原地格式化）。
基线复算：`develop@a1d7733` 非 golden = 709（`/tmp/base-034.log`），本切片 +8 ⇒ 期望 717；golden 仍 9 张、`test/goldens` 改动数 0。
