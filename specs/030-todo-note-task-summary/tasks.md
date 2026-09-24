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

## 下一轮入口

- #89 剩余：标签/指派人/优先级筛选（嘀嗒「显示内容」）、专注数据入摘要（需本地专注记录表）、
  摘要筛选条件「保存为模板」（嘀嗒仅桌面 tab 描述）、导出摘要为图片、侧栏「摘要」条目（需批准重录 9 张基线）。
- 队列里的核心缺口：多级子任务/清单内分组、看板与时间线可操作闭环、#67 导入收口、#22 余债
  （`applyTaskFilter` 补标签维度、过滤器重命名、扩 Service `conditions`）。

## 第 28 轮追加切片：笔记「使用模板」—— 复核 FAIL，已整体回滚

提交 `38dcb0d`（`TemplateApi` + `NoteTemplateSheet` + 入口 + 8 条用例）与 `b23e002`（specs 回写）
已由 `f17aa62`、`97239a4` 两条 revert 撤销；本 PR 回到只含摘要切片的状态。
复核手段替换同前（`claude` CLI 不可用 ⇒ 本会话只读子代理），`VERDICT: FAIL`（2 条 BLOCKER）。

### B1 接受 —— 笔记模板这个域在服务端根本不存在（不是"客户端没接"）

复核的因果我逐条自己复现了，而且**它说的比报告里更严重**：

| 事实 | 我自己跑的命令与原文 |
| --- | --- |
| 模板域只有两种类型，且内容就是 JSON 预设 | `git show origin/develop:…/content/TodoTemplateDO.java` → `:26 * 模板类型：1-任务模板、2-清单模板`、`:31 * 模板内容（JSON格式的任务/清单预设）` |
| 同步落库恒写"任务模板" | `git show origin/develop:…/sync/TodoSyncServiceImpl.java`（`upsertTemplate`）→ `bean.setTemplateType(1);` `bean.setIsPublic(false);` `bean.setContent(stringValue(payload.get("content")));` |
| app-api **没有**造笔记模板的能力 | `git show origin/develop:…/app/content/vo/AppTodoTemplateCreateReqVO.java` → 整个 VO 只有一个字段 `:12 private String clientMutationId;`（`RespVO` 才暴露 name/content/templateType） |
| 「预设模板」在生产里也无数据 | `git grep -n -iE "todo_template" origin/develop -- 'sql/**'` 只有 `todo-baseline-2026-09-18.sql:943 CREATE TABLE` 与索引行，**没有 INSERT 种子** |

⇒ 我那 8 条用例里 `templateType: 2` 是**我编的**（DO 注释里 2 = 清单模板，与笔记无关），
"我的模板"分组在服务端就是任务快照 JSON，`_insertBlock` 会把 `{"title":…,"priority":…}` 原样插进 Markdown 笔记。
我在 spec 里写的否证理由（「本地表形状不是笔记正文 ⇒ 所以读服务端」）**被服务端代码证伪**：
本地 Drift `todo_templates` 就是 `todo_template` 的镜像（`template_repository.dart:44` `jsonEncode({title,description,priority})`，
经同步以 `content` 原样上行），两边形状完全一样。**换一个源解决不了形状问题**。

结论：这一面属**契约缺口**，按规则 5 要先在 `zh-cloud-service` 建"笔记模板"（类型 + 纯文本 content +
可编辑入口 + 预设内容字面串由产品给，不许我自己造），客户端不得用任务模板域凑数。
已开 `zh-cloud-service` Issue（见本文件末尾"下一轮入口"与本 PR 的 `Refs`）。

### B2 接受 —— gate1 我记了个没有日志支撑的结论

`head -3 /tmp/r28_gates_a.log` 首段就是 `=== gate2 format ===`：我把 `git diff --check` 的
`exit=0` 写在正文里，但**那次跑的裸 `git diff --check` 只扫工作树**，当时工作树只剩不提交的 `pubspec.lock`
⇒ 对本轮任何改动恒真。按区间重跑才是真相：

```
git diff --check b23e002~1 b23e002  →  specs/030-todo-note-task-summary/spec.md:72: new blank line at EOF.   exit=2
git diff --check 38dcb0d~1 38dcb0d  →  exit=0
```

⇒ 修法：① gate1 从此写成**区间命令**（`git diff --check <base> <head>`）并把原文进日志；
② 本条 BLOCKER 随 `b23e002` 一起被 revert，空行已不在最终状态里。

### NIT 的处置（4 接受 / 1 不适用，逐条）

- 接受：「空组不渲染标题」是实现里唯一没被断言的验收口径 —— 随切片一起消失，重做时要写进用例。
- 接受但降级：320px+1.3 用例没像 `note_task_summary_test.dart:522` 那样在弹层自身 context 自检档位=13。
  复核核了 SDK `bottom_sheet.dart:1301` 的 `useRootNavigator = false`  ⇒ 机制成立、只是断言不敏感，属测试质量而非缺陷。
- 接受：「使用模板」与「插入摘要」是两个上下堆叠的 `Align(centerLeft)`，我写成了"并列"。
- 接受：tasks.md 里的 `TodoApi.templates` 应为 `TodoRestApi.templates`（仓内无 `TodoApi` 符号）。
- 不适用：`listPublic` 恒空 —— 已并入 B1 的契约缺口，不单列。

### 本切片留下的、值得记住的两条方法错

1. **换一个数据源来解决"形状不对"之前，先看那个源的真实形状**：我当时是"本地表不合适用服务端"，
   但没有读 `TodoTemplateDO` 的类型注释与 `RespVO` 的来源，服务端与本地是同一份镜像。
2. **门禁要跑在可复现的对象上**：`git diff --check` 不带区间 = 只扫工作树，对本轮改动恒真 ——
   和"探针跑在没被污染的文件上"是同一类假阳性。

### 回滚后的六项门禁（最终状态，日志 /tmp/r28_gates_revert.log）

- gate1 改成**区间**跑：`git diff --check f17aa62~1 f17aa62` → `exit=0`；
  `git diff --check 97239a4~1 97239a4` → `exit=0`；工作树 `git diff --check` → `exit=0`
- gate2 `dart format --output=none --set-exit-if-changed lib/features/note/ lib/core/api/todo_api.dart`（回滚后本轮**不再改 Dart 文件**，此处按目录只做检查、不原地格式化）
- gate3 `flutter analyze` → `No issues found! (ran in 2.0s)`
- gate4 `flutter test --tags golden` → `00:03 +9: All tests passed!`
- gate5 `flutter test --exclude-tags 'golden || performance' --concurrency=1` → `01:57 +731 ~26: All tests passed!`
  （回到摘要切片的 `+731` ⇒ 那 8 条用例确实整体退场，没留尾巴）
- gate6 `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` → `✓ Built build/web`

### 下一轮入口（本切片不重做，等契约）

- **笔记模板要先改契约**：`zh-cloud-service` Issue **#278**——`todo_template.template_type` 只有 1-任务/2-清单、
  `content` 注释即「JSON格式的任务/清单预设」、app-api 的 `AppTodoTemplateCreateReqVO` 只有 `clientMutationId`、
  `todo_template` 无 `is_public` 种子。#278 落定（类型 + 纯文本 content + 创建端点 + 预设正文由产品给）之后，
  本切片按那份契约重做，**不许再用任务模板凑笔记模板**。
