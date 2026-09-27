# 057 · 任务与日历同时显示 — 执行台账

基准：`zh-cloud-todo-flutter` `origin/develop@90320057c836841bf6e4dce2f2923e0725cf275d`
分支：`feat/379-task-calendar-side-by-side`（工作树 `/tmp/wt-fl-379`）
Gitea：Issue #379 · 判据源见 `spec.md` §一

## 一、本轮范围（只做开关 + 并列布局）

源页 `:17`/`:21`/`:27`/`:31`/`:39` 五句 = 三个菜单项 + 两条排布 + 一条关闭路径。
`:45-63`「拖动排期」四面**不在本轮**，另立单（见 §八）。

改动落点四件事：`lib/features/home/workspace_companion.dart`（新增：三态枚举 + 存储 +
`NotifierProvider`）、`todo_workspace.dart`（模块图标右键 + 副栏槽位）、
`home_shell.dart`（菜单与方向决策、`_buildContent` 拆成 `_buildPane(Section)` 让主副两栏共用一份渲染）、
`test/features/home/workspace_companion_test.dart`（新增）。

## 二、六道门禁读数（都在最终字节上各跑一次）

日志目录 `/tmp/r109/`，跑法 `bash /tmp/r109/gates.sh`，每条 rc 单独落 `/tmp/r109/rc.txt`。

| 门禁 | 命令 | 读数 | 日志 |
| ---- | ---- | ---- | ---- |
| g1 | `git diff --check` | rc=0、0 行 | `/tmp/r109/g1-diffcheck.log` |
| g2 | `dart format --output=none --set-exit-if-changed <本轮 4 个文件>` | rc=0 | `/tmp/r109/g2-format.log` |
| g3 | `flutter analyze --no-pub` | rc=0、`No issues found!` | `/tmp/r109/g3-analyze.log` |
| g4 | `flutter test --tags golden` | rc=0、`+9: All tests passed!` 在 `/tmp/r109/g4-golden.log:72`（全文 72 行） | `/tmp/r109/g4-golden.log` |
| g5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | rc=0、`+915 ~26: All tests passed!` 在 `/tmp/r109/g5-test.log:1170`（全文 1170 行） | `/tmp/r109/g5-test.log` |
| g6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0、`✓ Built build/web` | `/tmp/r109/g6-build.log` |

用例数不是靠减法推出来的：基线在**被测对象副本**上直接跑
（`/private/tmp/r68-baseline` 检出 `origin/develop@90320057`、`git status --porcelain` 0 行），
统计行 `+898 ~26: All tests passed!` 在 `/tmp/r109/baseline-develop.log:1152`（全文 1153 行）；
本分支同一命令 ⇒ `+915 ~26`（`/tmp/r109/g5-test.log:1170`）。
两边**各自实测**，再对上 `898 + 17（本轮实跑用例）= 915`；`~26` 跳过数两边相同 ⇒ 本轮没动任何 skip。

基线承诺的可验读数（V5）：`ls test/goldens/todo_workspace/*.png | wc -l` ⇒ **9**
（`/tmp/r109/g4-golden-png-count.txt`），且 `git status --short test/goldens` ⇒ **0 行**
（`/tmp/r109/g4-golden-drift.txt`）⇒ 9 张基线一张没重录、也没被改写。
⇒ 矩阵 #32 旧格那句「属会改可见布局的一档（动 9 张黄金基线要先申请）」被实测否掉：
默认态不动基线，因此本轮**不需要**请示重录。

用例数两个口径别混：`grep -c "  testWidgets(\\|  test(" test/features/home/workspace_companion_test.dart`
⇒ 声明 **12** 处；`flutter test <本文件>` 的统计行 `+17: All tests passed!` 在 `/tmp/r109/green-2.log:80`（全文 80 行）⇒ 实跑 **17**（循环展开出来的 5 条只在运行时成为用例）。
对账用 **17**。

## 三、反向探针（证明方向断言不是恒绿）

把 `_contentWithCompanion` 里的副栏从右侧挪到左侧（`todo_workspace.dart`，一次互换）后跑本文件
⇒ 统计行 `+12 -5: Some tests failed.` 在 `/tmp/r109/probe-left.log:205`（全文 212 行）：**5 条红**，正是三条"副栏必须在主区右侧"的几何断言加两条还原用例。
还原：`cp /tmp/r109/todo_workspace.dart.orig` 回来并 `cmp -s` ⇒ `RESTORE_IDENTICAL`，
复跑 ⇒ `+17: All tests passed!` 在 `/tmp/r109/after-restore.log:80`（全文 80 行）。⇒ 这把尺子开过火。

## 四、交叉验证（cursor-agent，第二个意见真的改写了结论）

`cd /tmp/wt-fl-379 && cursor-agent --trust -p "$(/bin/cat /tmp/crosscheck-379-anchor.md)"`
⇒ 输出 **4972 字节**、`grep -c "CROSSCHECK:"` ⇒ 1（`/tmp/crosscheck-379-anchor.out`）。

- **它推翻了我的一条前提**：我写 Issue 正文时只查了 `sidebar.dart`，据此断言
  「源页的『模块图标』在现有 IA 里没有字面对应物」，并准备了 A/B/C 三条候选锚点。
  它指出 `todo_workspace.dart:395` 的 `for (final item in Section.values) _RailButton(...)`
  就是任务/日历/习惯/我的四个模块图标。我回源复验为**真**（同一命令形态可自行复算，见 `spec.md` §三 1）
  ⇒ 锚点问题不存在，不改 IA，A/B/C 三条连同它给的 C>A>B 名次一起作废。
- **采用的两条**是它独立成立的部分：① 方向要进偏好枚举（只存布尔还原不出主从）；
  ② 窄屏按"布局档位降级"处理，静默降级、不清空偏好——它引的先例我复算过：
  详情容器在 宽栏/endDrawer/全屏路由 间静默切换（`home_shell.dart` 的 `_syncLayoutProfile`、
  `_MobileTaskDetailRoute`），而"能力不可用"才给可见提示。
- 它有一处**没验**：说 `todo_workspace.dart:395-404` 的 `item.label` 含「任务」——这条我复算为真；
  但它同时说侧栏行区间是 `:90-350`，我实测侧栏 13 行的 `label:` 在 `:94..:348`，
  区间写法不同不影响结论，不再纠。

## 五、本轮自己写错、并当场改掉的两条

1. **两条"窄屏不给并列菜单"的用例前提就是错的**：我按"窄屏也有模块图标、只是不给右键"来写，
   实测 `find.byKey(Key('todo-rail-item-tasks'))` 在 mobile/mobile-min 下 **0 个** ⇒
   报 `could not find any matching widgets`。真实现状是窄屏连左轨都不渲染（模块切换走底部导航），
   "不给菜单"不是一条守卫而是没有这个入口。用例已改成断言"轨道不存在 + 无副栏 + 不写偏好"，
   并在 `spec.md` §三 4 记实测。
2. **一次 format 判据被管道尾部的 rc 顶替**：我先跑
   `dart format ... | tail -6; echo rc=$?`，读到的 0 是 `tail` 的 rc；
   而 `dart format --set-exit-if-changed` 对未格式化文件该回 **1**。
   把 4 个文件真格式化后再量，`g2` 才是真的 rc=0。（同族坑：zsh 不切词，
   用 `$F` 传文件列表会得到 "No file or directory found"，两次读数都作废。）

## 六、台账结构自检

判据是 FL !364 带的 `tool/check_spec_selfscan.py`（**develop 上还没有这个文件**，
故用其分支副本跑：`/tmp/wt-fl-361/tool/check_spec_selfscan.py`，md5 `45ba425aeb561edb7d6403763b94e6fa`）。
复算命令：`python3 /tmp/wt-fl-361/tool/check_spec_selfscan.py specs/057-task-calendar-side-by-side/tasks.md`
⇒ 读数记在 §七 之后（改完当场回填，不凭记忆写"0 失项"）。

## 七、只读复核 VERDICT

**尚未取得**。派单提示词与日志路径写在这里，结论回来才填：

- 第 1 轮：提示词 `/tmp/verdict-379-r1-prompt.md`，日志 `/tmp/verdict-379-r1.log`，
  被审基准 = 本分支 head（提交后回填 SHA）。
- 派单前不动被审 ref；两轮无新结论就停下请示，不刷循环求绿。

## 八、下一轮入口

- 源页 `:45-63`「拖动排期」四面（拖进日历 / 拖进清单详情 / 拖到清单或标签 / 拖到智能清单）
  另立 Issue；`calendar_view.dart`、`timeline_view.dart` 已有 Draggable，先判定现有拖拽覆盖面再动手。
- 矩阵 #32 在合进 develop 前保持「无」，说明列可写「已实现、未合并」（校验器拒「待合并」字样）。
- 本单没碰后端契约：并列是纯客户端布局，`todo_list`/`todo_task` 都不需要新列。
