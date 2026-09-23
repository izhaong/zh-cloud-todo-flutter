# 计划：快速添加弹窗的「从模板添加」

基准 `origin/develop@a1d7733`，分支 `feat/todo-quick-add-from-template`。规格见 [`spec.md`](spec.md)。

## 落点与复用（不新造链路）

| 面 | 落点 | 为什么落这里 |
| -- | ---- | ------------ |
| 入口 | `lib/features/task/task_quick_add_sheet.dart` 下方那一行行首的 `PopupMenuButton`（key `todo-quick-add-more`） | 嘀嗒原话「任务输入弹窗**下方**的「...」按钮，选择「模板」」；同一行右侧已有 取消/保存，插在行首不改既有顺序 |
| 模板列表 | `_QuickAddTemplatePicker`（同文件，root key `todo-quick-add-template-sheet`）由 `showModalBottomSheet` 打开 | 与任务详情已有的模板区**同源**：`repo.watchAll()` + `已同步/等待同步` + 空态「暂无本地模板」，措辞保持一致。**第 1 轮复核更正本行的措辞**：这里写「不再实现第二份列表逻辑」不准确——弹层确实又写了一份 `watchAll()`+状态文案+空态的渲染（`task_detail_pane.dart:3628-3651` 那份没被抽成共用 widget），只是**数据链路与措辞同源**，渲染是第二份。抽公共组件属重构、不在本切片范围；`已同步/等待同步` 两个词在 `test/` 里 0 命中＝措辞目前无人钉（见 tasks.md 仍缺） |
| 建任务 | `templates.taskSeed(t)` → `taskRepository.create(listId, parentTaskId, title, description, priority)` | 这一对是任务详情「应用」按钮已验收的链路（`task_detail_pane.dart:3573-3580`），本切片只是把它接进添加流程 |
| 上传/同步 | 完全不动 | 模板与任务的 outbox 由既有 `SyncChangeQueue` / `sync_coordinator` 承担；服务端模板 app-api 已齐，无契约改动 |

## 关键取舍（含被否）

- **即刻建任务，不预填表单**：本弹窗没有「说明」输入，而模板一定带 `description` ⇒ 预填要么新增一个嘀嗒弹窗里没有的字段（改可见布局），要么静默丢数据。
  嘀嗒写的是「选择「模板」**即可**从模板添加任务」⇒ 即刻添加。
- **移动端 IA 优先**：桌面端「输入框下拉」与「/」斜杠菜单不在本切片（斜杠菜单全仓 0 命中，属 #7 的独立一面）。
- **`_applyingTemplate` 早退守卫**：`showModalBottomSheet` 的回调在等待 `create` 期间仍可被再次点中 ⇒ 同帧双 tap 会建两条重复任务。守卫必须被探针咬住，不能只靠「看起来会拦住」。**第 1 轮复核抓到复位缺失**：复位必须写在 `finally` 里，否则任何抛在 `try` 之前的异常都会把入口永久锁死（探针 PB：删掉复位那行，「连挑两次」用例红）。`taskSeed` 因此也必须留在 `try` 内——它对服务端原样落库的 `contentJson` 做 `as Map<String, dynamic>`，非对象 JSON 抛 `_TypeError`（探针 PC 复现原文：`type 'Null' is not a subtype of type 'Map<String, dynamic>' in type cast`）。
- **pop 判据不是 `mounted`**：上一版这里写「pop 只需 `sheetContext.mounted` 判定」——**错的**（第 1 轮复核第 3 条）。用户可以在 `create` 在飞时自己滑掉弹层：路由已经 pop，但元素要等反向动画跑完才 dispose，这期间 `mounted` 仍是 `true`，于是 `Navigator.of(sheetContext).pop()` 打到**下一层路由**＝宿主快速添加弹窗，用户刚打的标题随之丢掉。现改为「`ModalRoute.of(sheetContext)` 捕获路由 + `isCurrent` 才 pop」。用例「用户先把模板弹层滑掉…」用一把挂起的假 `TaskRepository` 把窗口钉死（点「添加」→点遮罩→**不 pump**→complete→再 settle），摘掉 `isCurrent` 判定必红（探针 PD）。
- **反馈落在弹窗自己的行内，不用 SnackBar**（第 1 轮复核第 4 条）：本弹窗是 `showModalBottomSheet` 的一层路由，`ScaffoldMessenger.of(context)` 会一路走到**根** messenger，SnackBar 画在根 Scaffold 底部＝被弹窗自己盖住。复核员实测的 rect：SnackBar `[0,552,800,600]`、宿主弹窗 `[80,340,720,600]`；手机宽度下弹窗是全宽的，等于三条提示（已应用 / 请先登录 / 失败原因）一条都看不见。⇒ `_report()` 改成 `setState` 一行 `Text`（key `todo-quick-add-feedback`），并在自己 context 上复检 320px+1.3。探针 PE 把 `_report` 换回 SnackBar，四条用例齐红。
  ✅ **同源缺陷 `_save()` 已由 #289 收掉**（本分支第 3 轮）：两条 catch 改为 `_report(...)`（`task_quick_add_sheet.dart:66-69`），全文件已无 `ScaffoldMessenger` 调用。同时量出并修掉一处更硬的问题——反馈行是 `Column` 的最后一个子节点，`320×568 + 键盘 260 + 1.3 倍字体`下弹窗被裁 `8.2px`，正好裁在它身上，所以「在子树里」≠「看得见」⇒ 内容包一层 `SingleChildScrollView(reverse: true)`（`:138-142`，底部对齐，本仓 `:291` 的模板弹层已用同一手法）。
  ⚠️ **仍缺**：`_save()` 的 `repo == null`（未登录）与 `text.isEmpty` 两个出口仍静默 `return`（`:51`、`:53`，改动之前就存在），不属「SnackBar 被盖住」这一类，另单跟。
- **「...」按钮的读屏标签要显式给**（第 1 轮复核第 5 条）：`child: Icon(...)` 时 `tooltip` 完全进不了语义节点（复核员 dump 到的是 `label: ""` 带 tap action）；**改成 `icon:` 也仍然 0 命中**（本会话两次实测：`child:` 版与 `icon:` 版都拿不到 `'更多'`）⇒ 复核员建议的「走 IconButton 那条路径」在这个组合下不成立。最终用显式 `Semantics(label:'更多', button:true, container:true)` 包裹，措辞与 `tooltip` 同源。用例里 `ensureSemantics()` 之后**必须再 pump 一帧**，否则语义节点还没生成、`bySemanticsLabel` 恒 0 命中＝空转。
- **动作措辞「添加」而非详情页的「应用」**：嘀嗒那句原文是「选择「模板」**即可从模板添加任务**」，本弹层紧贴该流程用「添加」；任务详情的模板区用「应用」。同一个动作在两个表面两个词，是**有意按嘀嗒措辞**而非笔误——若后续人工核到嘀嗒两处用词一致，则统一到那一处。
- **不引入 `picking` 之类的额外状态**：路由当前性由 `ModalRoute.isCurrent` 直接给出，比再挂一个布尔更不容易与真实路由栈漂移。

## 测试设计（`test/features/task/quick_add_from_template_test.dart`，12 例）

第 1～8 例是第 18 轮的原始覆盖面；第 9～12 例是第 1 轮复核 `FAIL` 后按 blocker 补的。

1. 下方「...」存在、展开后有「模板」，且该项是独立语义节点。**第 1 轮复核补**：还要断 `bySemanticsLabel('更多')` 命中入口按钮本身。
2. 挑一条即建任务：`listId` = 弹窗清单、`description`/`priority` 来自模板、提示「已应用模板“X”」。**提示改为「必须落在弹窗自己的子树里」**。
3. 子任务弹窗里选模板 ⇒ 新任务 `parentTaskId` 仍是同一父任务。
4. 无模板 ⇒ 「暂无本地模板」，且没有「添加」可点、不建任何任务、outbox 不留半条。
5. 模板仓储 `null`（未登录）⇒ 提示「请先登录」，不是点了没反应。**第 1 轮复核补**：还要断弹层没被打开。
6. 建任务失败（父任务跨清单被拒）⇒ 弹窗不关、已输入标题不丢、给**原因**而不是通用文案。
7. 同帧连点两次「添加」⇒ 只建一条。
8. 320px + 1.3 倍字体：弹窗与模板弹层**各自 context** 的 scaler 档位传到位且无溢出异常。**改后**：反馈行出现之后再复量一次（多一行才是真排版态）。
9. **坏模板（`contentJson` 不是对象）⇒ 给可见原因、异常不逃到框架，且入口不被锁死**（复核 blocker 2）。
10. **用户先滑掉模板弹层、请求随后才回来 ⇒ 宿主快速添加弹窗不被误关**（复核 blocker 3，用挂起的假 `TaskRepository` 制造窗口）。
11. **弹窗开在非收集箱清单 ⇒ 任务落在该清单**（复核 blocker 6：原 8 例全 pump 收集箱，把生产里的 `listId` 换成字面量 `'inbox'` 也能全绿）。
12. **同一个弹窗里连挑两次 ⇒ 两条都建出来**（复核 blocker 7：只测了守卫「挡住」，没测它「复位」）。

写用例时踩到的三处自伤（记下来防重犯）：

- 第 2/3/7 例最初按标题查新建任务 ⇒ 命中 **2 条**，因为**模板的来源任务本身就叫这个名字**。必须 `exceptId: source.id` 排除，否则断言自己造假阳性。
- 第 5 例原本 seed 了模板，而 `saveTask` 会往 outbox 写一条 ⇒ 「outbox 为空」成了假断言。改为该例不 seed，并把它降级为「只能挡住未来往这条路径加写库」的弱断言（写进 reason，别当正向证据）。
- 第 9～12 例的 `ensureSemantics()` 之后**必须再 `pump()` 一帧**才拿得到语义节点；否则 `bySemanticsLabel` 恒 0 命中、断言空转——这一点连复核员的修复建议都没覆盖到（它建议「改用 `icon:` 走 IconButton 路径」，本会话实测 `child:` 与 `icon:` 两种写法都拿不到 `'更多'`，最后只能显式 `Semantics` 包裹）。

## 反向探针（第 1 轮，判据：摘掉生产代码必须看到对应红，恢复后 `cmp -s` 一致）

> ⚠️ 本表是**第 1 轮**的探针编号；修复后在最终字节上重排的 9 条（PA~PI）在
> `tasks.md` 的「反向探针（第 2 次，最终字节）」一节，**同字母不同含义**。
> 用例注释里引用的编号以 `tasks.md` 第 2 次表为准。

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
