# 任务清单：笔记插入任务摘要（specs/030）

基线：`origin/develop@a1d7733`，分支 `feat/todo-note-summary-insert`。每项只在**实际命令输出**支持时勾选。

- [x] T1 `task_summary.dart` 纯生成器：区间、三种分组、两种排序、两个显示开关、空集返回 `null`、
      确定性排序（选定字段 → `sortOrder` → UUID）。
      已证实：`摘要文本` 7 条用例，默认口径那条是逐字节整段断言。
- [x] T2 `DriftSummaryRepository`（接口 `SummaryRepository`）只读查询：带清单名、检查事项与子任务进度；
      只取顶层任务（`parentTaskId.isNull()`）；`orderBy(createdAt,id)`；provider 在无库时给 `null`。
      已证实：真 Drift 内存库用例 2 条（区间归属 + 未登录降级）。
- [x] T3 `task_summary_sheet.dart`：选项即时重算预览；`_requestId` 丢过期响应；
      `_loadedRange` 与所选区间不一致时标题仍写旧区间且禁止插入；空档禁用插入；自定义走日期范围选择器，
      取消选择就不换区间。
- [x] T4 笔记编辑器 `插入摘要`：按光标位置写入草稿（光标无效时追加末尾）；取消不改草稿。
      `_NoteEditorDialog` 保持 `StatefulWidget`（不读 provider），未做 Consumer 转换。
- [x] T5 四件套：320px + 1.3 倍（在弹层自身 context 自检档位=13）、读屏语义（`插入摘要` / `按清单` / `插入`）、
      失败保留已加载数据、过期响应不覆盖新响应。
- [x] T6 六项门禁（见下）。golden 9 张基线未变。
- [x] T7 只读复核拿到 `VERDICT`（见「复核」段），必须改项全部落地。
- [ ] T8 回写 `dida-parity-matrix.md` #89 行 —— 属 `zh-cloud-docs` 仓，见该仓 PR；本仓不做。

## 验证记录（2026-09-23，日志 /tmp/gate-030-final.log）

- `git diff --check` → exit=0
- `dart format --output=none --set-exit-if-changed <6 个显式文件>` → `Formatted 6 files (0 changed)`,`exit=0`
- `flutter analyze` → `No issues found!`
- `flutter test --tags golden` → `00:03 +9: All tests passed!`（基线未变，未申请重录）
- `flutter test --exclude-tags 'golden || performance' --concurrency=1` → `01:54 +731 ~26: All tests passed!`
- `flutter build web --release --dart-define=TODO_API_BASE_URL=... --dart-define=TODO_TENANT_ID=1` → `✓ Built build/web`
- 本 FR 单文件 `flutter test test/features/note/note_task_summary_test.dart` → `00:02 +22: All tests passed!`

红测起点（未实现前）：`flutter test` 直接报
`Error when reading 'lib/features/note/task_summary.dart': No such file or directory` /
`Type 'SummaryTaskRow' not found`（日志 /tmp/red-030.log）——新符号只能红在编译层。

### 反向探针（摘掉生产代码必须红，恢复后 `cmp -s` 逐字节一致）

| 摘掉的代码 | 结果 |
| --- | --- |
| `sheet` 的 `requestId != _requestId` 守卫 | 「过期响应不得覆盖新响应」红 |
| `repo` 的 `task.parentTaskId.isNull()` | 22 条里红 2 条（区间归属 + 口径接线） |
| `repo` 的 `task.completed.equals(false) &` | 「区间归属」红（`sum-out-done` 带区间内 dueAt 混进来） |
| `canInsert` 的 `_rowsMatchSelectedRange` | 「刷新失败保留上一次摘要」红 |

四次探针后均 `RESTORE byte-identical OK`。

## 复核

手段替换：`claude` CLI 本机不可用（`unrecognized_model: Top1`），改用**本会话只读子代理**审本轮 FR，
要求给出 `VERDICT`。结果：**FAIL**（4 项必须改 + 5 项假阳性 + 次要若干）。逐条处置：

已照改：

1. 自定义档位只有芯片没有日期选择器 → 接 `showDateRangePicker`，取消即不改区间（红→绿）。
2. 子任务既单独成行又计入父任务进度（双算）→ 查询加 `parentTaskId.isNull()`，与 `task_repository.dart:29/40` 同口径。
3. 取数失败保留旧数据后仍可插入，标题却写新区间 → 加 `_loadedRange` 配对，区间不匹配时禁插入。
4. 「未登录」用例自我循环（同时 override 被测 provider）→ 改为只 override `appDatabaseProvider` 并断言界面文案 + 禁插入。
5. 缺变异杀手数据 → `sum-out-done` 补区间内 `dueAt`；新增 `sum-child` 子任务。
6. UI 口径接线零覆盖 → 新增「清单/分组/排序/状态四个口径都真的驱动预览」（含 `_toggleList`）。
7. 光标分支未测 → 新增「光标落在文字前部时插在光标处」。
8. 空行 `Text('')` 产生空语义节点 → 改 `SizedBox`；读屏断言扩到 `按清单` / `插入`。
9. 无本地库仍给「重试」→ 只有仓库可用时才给；选项区 `ListView` → `SingleChildScrollView`（懒加载会让控件不被构建）。

未采纳（附理由）：

- 「`pubspec.lock` 须还原」：本机新 SDK 会把整树重解析写脏（镜像 url + 包版本 + sha256），
  约定是**不随功能 PR 提交**——这是目标里给 human 的约定，不是本仓文档条文。本轮未 stage 该文件。
- 「plan.md 的 Consumer 转换」：复核判「改文档」，已按此改 `plan.md`（对话框不读 provider，无需 Consumer）。

## 追加切片（第 28 轮）：笔记「使用模板」

基线同上（`feat/todo-note-summary-insert`，栈在本 PR 的摘要切片之上）。

- [x] T9 `TemplateApi`（`core/api/todo_api.dart`）：`listMy()` / `listPublic()` 打既有
      `/app-api/todo/template/list-my`、`/template/list-public`，`NoteTemplateDto.fromJson` 按 wire 形状解包，
      `code != 0` 抛出并带服务端文案。挂到 `TodoApi.templates`。
- [x] T10 `note_template_sheet.dart`：并列取两组、按「我的模板 / 预设模板」分组（空组不渲染标题）、
      `_requestId` 丢过期响应、失败保留已加载列表并给出原因。
- [x] T11 笔记编辑器 `使用模板` 入口与 `插入摘要` 共用 `_insertBlock`（同一套光标/换行拼接逻辑）。
- [x] T12 四件套：320px + 1.3 倍不溢出、入口/分组名/模板名独立读屏语义、失败保留、过期不覆盖。
- [ ] T13 回写矩阵 #89（属 `zh-cloud-docs`，见 docs !83；摘要与模板都写「已实现待合并 !275」）。

### 验证记录（2026-09-24，日志 /tmp/r28_gates_a.log 与 /tmp/r28_gates_b.log）

- `git diff --check` → `gate1 exit=0`
- `dart format --output=none --set-exit-if-changed <4 个显式文件>` → `Formatted 4 files (0 changed)`，`gate2 exit=0`
- `flutter analyze` → `No issues found! (ran in 3.4s)`
- `flutter test --tags golden` → `00:03 +9: All tests passed!`（基线未变，未申请重录）
- `flutter test --exclude-tags 'golden || performance' --concurrency=1` → `02:06 +739 ~26: All tests passed!`
  本分支上一条记录是 `+731 ~26`，本轮新增用例全在**新文件** `test/features/note/note_template_insert_test.dart` 里
  （8 条）⇒ 731 + 8 = 739 对得上。
- `flutter build web --release --dart-define=TODO_API_BASE_URL=... --dart-define=TODO_TENANT_ID=1` → `✓ Built build/web`
- 单文件 `flutter test test/features/note/note_template_insert_test.dart` → `00:01 +8: All tests passed!`

红测起点：新符号只能红在编译层 ——
`Error when reading 'lib/features/note/note_template_sheet.dart': No such file or directory`。

反向探针（摘掉生产代码必须红，恢复后 `cmp -s` 逐字节一致）：

| 摘掉的代码 | 结果 |
| --- | --- |
| `note_template_sheet.dart` 两处 `requestId != _requestId` 守卫 | 「后到的旧响应不得覆盖新结果」红：`Found 2 widgets with text "过期模板"` |

（本切片只做了一次探针，其余三条断言——入口存在、分组与光标插入、320px 不溢出——
在实现前就是红的，属新文件整体红，不是切片级判据。）

测试脚手架自身的两处假阴性（都记下来，别再犯）：

1. 「后到的旧响应」用例第一次红在 `Offset(288.0, 756.0) is outside the bounds of the render tree`：
   弹层入场动画没走完就 `tap` 重新加载按钮 ⇒ 点到屏幕外。`pumpAndSettle` 又永远不返回
   （第一轮挂起、`CircularProgressIndicator` 是无限动画）⇒ 换成 `pump()` + `pump(400ms)`。
2. 修完动画问题后变成 `Found 2 widgets with text "最新模板"`：假 `_FakeApiClient` 对
   `list-my` 与 `list-public` 返回了同一份数据，于是一个模板在两个分组里各渲染一次。
   生产代码没问题 ⇒ 按路径分别返回。

## 下一轮入口

- #89 剩余：标签/指派人/优先级筛选（嘀嗒「显示内容」）、专注数据入摘要（需本地专注记录表）、
  摘要筛选条件「保存为模板」（嘀嗒仅桌面 tab 描述）、导出摘要为图片、侧栏「摘要」条目（需批准重录 9 张基线）。
- 队列里的核心缺口：多级子任务/清单内分组、看板与时间线可操作闭环、#67 导入收口、#22 余债
  （`applyTaskFilter` 补标签维度、过滤器重命名、扩 Service `conditions`）。
