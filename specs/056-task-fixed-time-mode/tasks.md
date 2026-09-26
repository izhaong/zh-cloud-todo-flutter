# 056 执行台账

## 状态：本轮完工待复核（分支 `feat/369-fixed-time-mode-picker`，尚未开 PR）

矩阵 #12 不动：契约 PR（service !291）与本分支都未合并 ⇒ 只写「已实现待合并」，不翻状态。

## 一、17 条红的归因与处置（全部转绿）

原名单（本文件历史版本记的 17 条，全是「`fixed_timezone=true` ＝保留配置时区墙钟」这条旧语义的断言）
现已全部转绿。复算命令：

```bash
flutter test --exclude-tags 'golden || performance' --concurrency=1   # 读数见第四节
```

三条根因，每条都有独立证据：

1. **把 bool 塞进 int 位**（最大一条）：批量改签名时写出 `TaskTimeMode.fromWire(task.fixedTimezone)`，
   而当时 `fromWire` 收 `Object?` ⇒ `int.tryParse('true')` 失败后**静默回落「浮动」**，
   `flutter analyze` 一声不吭。修：26 处调用点改 `.timeMode`，并把 `fromWire` 收严成 `int?`
   ——收严后立刻又暴露 3 处真错（提醒行没有 `timeMode` 字段、两处夹具插错位置）。
2. **存/看两侧时区取错**：`_storageLocation` 只对「固定时区」按锚点区解释墙上钟点，
   「固定时间」按设备区 ⇒ 与「显示钉锚点区读数」不自洽，round-trip 断裂。
   读数：`task_time_semantics_repository_test :: fixed timezone wall clock converts through the
   active DST offset` 期望 `2026-10-31 16:00:00.000Z`，实到 `2026-10-31 09:00:00.000`。
   判据与改判过程见 `spec.md` 的「第二次交叉验证」段。
3. **控件契约改名**：`Key('task-fixed-timezone')` 这个布尔开关被三态档位取代
   ⇒ `Key('task-time-mode-1')` / `Key('task-time-mode-2')`；标签从「本地时区/IANA」两态
   变成「`<IANA> 固定时区` / `<IANA> 固定时间`」，用例里的期望串跟着改。

本轮自己写坏又撤掉的假红：`test/sidebar_due_range_test.dart` 的 `_task` 辅助函数没有 `timeMode`
参数，批量脚本给它加了一行 `timeMode: 2,` ⇒ `flutter analyze` 报 `undefined_named_parameter`。
该文件已整份还原（`git checkout --`，还原后 diff 为空）。

## 二、两列必须同源（跑测试撞出来的真缺陷）

`task_repository` 的 `create`/`update` 原来只在调用方显式给 `fixedTimezone` 时才写老位，
详情面板保存只传 `timeMode` ⇒ 落库会出现 `time_mode=2` 而 `fixed_timezone=false` 的分裂行，
老客户端与服务端派生位读法相反。现改成：给了 `timeMode` 就以它为准，两列同源写入。
判据用例：`detail saves all-day and fixed time through task repository`
（同一条里既断言 `timeMode=2` 也断言 `fixedTimezone=true`）。

## 三、四件套（R5）逐条落地情况

| 面 | 用例 | 结论 |
| -- | ---- | ---- |
| 320px + 1.3 倍字号（该 sheet 自己的 context） | `320px + 1.3 倍字号下两档固定仍可读可点` | 部分：两档控件 rect 全在 320 视口内、标题与嘀嗒原句副标题都在、读屏标签命中。**全局 no-exception 判不了** —— 撞出 `RenderFlex overflowed by 36 pixels on the right`，两次反向探针（把 `RadioGroup` 整块隐藏、把副标题换成短串）读数不变 ⇒ 溢出源是 Issue #279 已登记的存量缺陷，不是本控件；用例注释已指回 #279。 |
| 独立读屏语义 | 同上（`find.bySemanticsLabel(RegExp('^固定时间'))`） | 已验 |
| 失败保留已加载数据 | `detail keeps the chosen time mode when saving fails` | 已验：保存失败后库里的 `time_mode` 仍是 0，重开面板档位仍是用户选的「固定时间」 |
| 过期响应不覆盖新响应 | `detail keeps an unsaved time mode against a newer snapshot` | 已验：`watchById` 推来 `time_mode=1` 的新快照后，面板仍是未保存的「固定时间」，且没被写回库 |

写这三条时踩到的坑（记下来给下一个人）：时间选项面板是**懒建列表**，重开面板后不
`scrollUntilVisible` 就直接查档位控件会拿到 0 个（探针读数 `close: 1, radio: 0, label: 0`
证明面板是开着的，只是视口外还没建）。

## 四、六道门禁读数（最终字节，各跑一次）

| 门禁 | 日志 | 读数 |
| ---- | ---- | ---- |
| `git diff --check` | `g4-diffcheck.log` | rc=0，无输出 |
| `dart format --output=none --set-exit-if-changed`（本轮 20 个 .dart 文件，清单 `/tmp/fmt-final.txt`；未做全仓原地格式化） | `g4-format.log` | `Formatted 20 files (0 changed)`，rc=0 |
| `flutter analyze` | `g4-analyze.log` | `No issues found!` |
| `flutter test --tags golden` | `g4-golden.log` | `00:04 +9: All tests passed!`；跑完 `git status --porcelain` 里 png/goldens 计数 = 0 ⇒ 9 张基线未重录 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `g4-test.log` | `02:29 +922 ~26: All tests passed!`（通过 922、跳过 26、失败 0） |
| `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `g4-build.log` | `✓ Built build/web` |

日志都在 `/tmp/gates-369/`。`pubspec.lock` 未随改动提交：每道门禁跑完即
`git checkout -- pubspec.lock`，填表时 `git status --short pubspec.lock` 输出为空。

计数复算命令（读数会随分支前进漂移，别抄这里的数字，现跑现读）：

```bash
flutter test --exclude-tags 'golden || performance' --concurrency=1 2>&1 | tr '\r' '\n' | tail -2
git status --porcelain | grep -ci 'png\|goldens'   # 期望 0
git status --short pubspec.lock                     # 期望空
```

## 五、交叉验证与登记

- 第二意见通道：`cursor-agent --trust`，输出 2,956 字节、哨兵行 `CROSSCHECK: DONE`
  （提示词 `/tmp/crosscheck-369-picker.md`，原文 `/tmp/crosscheck-369-picker.out`）。
  采纳控件形状判断（`RadioListTile.toggleable` 回到未选），驳回其「固定时间的存储也按设备区」
  的结论——理由与复算见 `spec.md` 同名段落。
- Issue #279：登记本面板为第二个复现面（留言 9666，含两条反向探针的判据）。
- Issue #371（本轮新建）：「固定时间」的本地通知仍按存储瞬间触发，未按 `:64` 换算成设备当地
  墙上钟点。属矩阵 #12 第四面，不在本轮修。

## 六、下一轮入口

1. 只读复核（`claude -p` 门禁）拿 `VERDICT`，通过后 commit → push → 开 PR 指向 `develop`，
   正文 `Refs #369`，并声明它 stack 在未合并的 !370（`7126f01`）之上。
2. 台账自扫判据：本分支不含 `tool/check_spec_selfscan.py`（它在 FL PR !364 的分支上），
   复核前先从 !364 取该脚本，跑
   `python3 <该脚本路径> specs/056-task-fixed-time-mode/tasks.md`，
   现读到「失项 0 条」才算改完；!364 合并后改用仓内路径 `tool/check_spec_selfscan.py`。
3. service #292 提醒侧接 `time_mode`（队列第⑤项）与 FL Issue #371 同一口径，两端一起定。
4. 增量 SQL 两条回填 `UPDATE` 仍未在任何环境执行 —— 要人过目后才跑。
5. 本分支合并后，docs 矩阵 #12 主表行（`zh-cloud-docs` 的 `dida-parity-matrix.md` 第 79 行）
   要按代码改锚点：该行「有」段引的 `task_detail_pane.dart:406`/`:417`/`:476`/`:1514` 与
   `task_time_formatter.dart:167` 都是 develop 上「一个布尔开关」时代的行号，
   三态落地后位置已变（现按符号名引：`_timeMode`、`_timeModeSubtitle`、`RadioGroup`、`_timeZoneLabel`）。
   矩阵行翻状态的前提仍是 service !291 已合并 —— 未合并前只写「已实现待合并」。
