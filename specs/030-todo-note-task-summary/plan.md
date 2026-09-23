# 实现计划：笔记插入任务摘要

## 数据与契约

- 只读查询 `DriftSummaryRepository(AppDatabase)` 实现 `abstract interface class SummaryRepository`
  （照 `NoteRepository`/`ApiNoteRepository`、`AttachmentUploadApi`/`Dio…` 的接口+实现形状；无 outbox、无写入）。
  provider 名 `summaryRepositoryProvider`，`appDatabaseProvider == null` 时返回 `null`。
- 查询只取顶层任务（`parentTaskId.isNull()`，与 `task_repository.dart:29/40` 的列表口径一致），
  并 `orderBy(createdAt, id)`：没有排序时 SQLite 的返回顺序会抖，清单候选项跟着抖。
- 不新增 Drift 表、不改 `pubspec.yaml`、不碰 `/app-api/todo/**`。

## 纯函数生成器

`lib/features/note/task_summary.dart`：

- `TaskSummaryPreset { today, lastSevenDays, lastThirtyDays, thisMonth, custom }`
- `SummaryGroupMode { none, byList, byStatus }`、`SummarySortMode { time, title }`
- `TaskSummaryOptions`（区间、清单集合、`completed?`、分组、排序、两个开关）
- `String? buildTaskSummary(options, rows, now)` —— 无行返回 `null`；有行返回 Markdown。
  时间与标题两条排序路径，均以 `sortOrder` + UUID 兜底保证确定性。

## UI

`lib/features/note/task_summary_sheet.dart`：`showModalBottomSheet<String>` + `NoteTaskSummarySheet`
（本身是 `ConsumerStatefulWidget`，直接读 `summaryRepositoryProvider` 与 `currentDateTimeProvider`）。

- 选项区用 `SingleChildScrollView + Column`，**不用 `ListView`**：懒加载会让滚出视口的芯片与预览行根本不被构建，
  断言与点击都会假失败。预览同理走 `SingleChildScrollView`，且空行渲染成 `SizedBox` 而不是 `Text('')`。
- `_requestId` 自增守卫丢弃过期响应；取数失败保留上一次 `rows`，但 `_loadedRange` 与当前选项区间不一致时
  标题仍写上一次区间且禁用插入；本地库不可用时不给「重试」。
- 自定义档位走 `showDateRangePicker`；返回 null（用户取消）就不改区间，避免「自定义」静默退化成今天。
- `_NoteEditorDialog` **保持 `StatefulWidget`**：对话框自身不读任何 provider，弹层才是 Consumer；
  转成 `ConsumerStatefulWidget` 属无必要改动。按钮把弹层返回的文本按光标位置写入
  `TextEditingController`（光标无效时追加到末尾）。

## 落点与基线

入口在既有笔记编辑对话框内部 ⇒ 不改侧栏/dock/首页布局，`flutter test --tags golden` 9 张基线预期不变。

## 已否决方案

1. **接服务端 `/todo/summary/generate`**：内容端点返回 `[mock 摘要 type=.. style=..]` 字面量，
   按它做 UI 等于把占位符当功能交付；且其「按单任务 + AI 来源」的语义与嘀答的「时间段摘要」不同源。
2. **侧栏加「摘要」条目**：嘀嗒确有该桌面入口，但会改侧栏布局 ⇒ 需批准重录基线，违背本轮
   「优先不重录基线」的取舍；留作后续单独申请。
3. **把摘要存进 `todo_summary` 表再展示**：需要改 SQL 与服务端契约才能表达区间/分组，
   而嘀嗒摘要的持久化载体其实是**笔记正文本身**，插入即落库，无需新表。
