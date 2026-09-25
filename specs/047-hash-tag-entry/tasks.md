# 047 · 输入「#」快速创建标签 · 任务与验收记录

基准 `origin/develop@9032005`。分支 `feat/327-hash-tag-entry`。Issue **#327**（矩阵 **#21**）。

## 编号为什么是 047

`develop` 上最大是 `specs/044-kanban-groups`。未合并分支已经占了 **045**（`!347` 的
`specs/045-sort-direction` 与 `!319` 的 `specs/045-kanban-card-assign`，两个 045 已经互相撞号）
和 **046**（`!322`）。⇒ 本轮取 **047**，避免第三个同号目录。

## 勾选（只勾真满足的）

- [x] FR-1 `:48`/`:61` 前半：快速添加的两个输入认 `#`（标题里没有井号原文、标签进 `request.tagIds`）
- [x] FR-2 `:46` 的另一半：标签弹层内可直接「新建标签」，建完自动选中；空列表不再只回死路提示
- [x] FR-3 不改页面提交分支与 `createBatch` 签名（`home_shell._quickAdd`、`tasks_by_list_page._submitQuickAdd` 零改动）
- [x] FR-4 标题被 `#` 吃空 ⇒ 可见提示（弹层 `errorText`／桌面条 SnackBar），且不建"挂在空气上"的标签
- [x] FR-5 四件套（见下节，含一条实测出来的溢出修复）
- [x] 反向探针 PA–PK 11 条，每条都有未打补丁的对照组
- [ ] FR-5 的第四维「过期响应不覆盖新响应」——本轮判定为不适用，理由写在四件套表里，**不空勾**（复核 F4 指出这里串号了：FR-6 是"不 bump schemaVersion"那条）
- [ ] `#327` 的另一半（任务详情输入 `#`、看板/子任务 `TaskQuickAddSheet`）——本轮没做，见「下一轮入口」
- [ ] 只读复核 `VERDICT` —— 待派
- [ ] 矩阵 #21 回写 —— 合并后才动状态与证据列，本轮只能写「已实现待合并」

## 四件套（新增可见界面：# 计数、「新建标签」行、可换行的操作行）

| 条 | 落点 | 用例 |
| -- | ---- | ---- |
| 320px + 1.3 倍 | 在 `_MobileQuickAddSheet` 自己的 context 上实测 `MediaQuery.textScalerOf(...).scale(10)≈13` | `320px + 1.3 倍：新建标签行与「标签 N」都排得下、可命中、读屏分得清` |
| 独立读屏语义 | 标签入口给 `todo_mobile_quick_add_tags`，计数用**可见文案**「标签 N」承载（tooltip 进不了读屏，实测记录见 `task_quick_add_sheet.dart:203`） | 同上一条 + `桌面：# 让标签工具图标带出数量角标与读屏标签` |
| 失败保留已加载数据 | 建标签失败：弹层不关、已勾的「专注」仍在、可重试、不摆出没建成的那一行 | `创建标签失败：sheet 不关、已选保留、给可见提示` |
| 过期响应不覆盖新响应 | **本面不适用**：`#` 的名字列表是从输入框同步派生的（无异步回写），唯一异步点是提交时/表内建行时的 ensurer，而它回来后只往 `_selected`/`tagIds` **追加**，不覆盖别的状态；关弹层后的迟到回调用 `if (!mounted) return` 拦住 | 见探针 PF（去掉同步闸门 ⇒ 迟到那次的副作用被第二次点击接走，红在 `连点两次「确定」只建一个标签`） |

### 实测抓到的一个真缺陷（不是本轮引入的写法问题，是本轮把文案变长后暴露的）

移动弹层的操作行原来是 `Row` + `Spacer`：320px + 1.3 倍字号下 `「标签 N」` 把右端加长，
实测 **RenderFlex overflowed by 31 pixels on the right**。
⇒ 改 `Wrap(spacing: 8, runSpacing: 4)`。
对照实验（同一棵树、develop 字节的 `quick_add_bar.dart`、**不输** `#`）分两种状态各量一次：
- 未勾任何标签 ⇒ 异常 `null`；
- **勾上 1 个标签 ⇒ 同样溢出 31px**（复核 F3 补做：`/tmp/rv350-probe/test/rv350_dev_overflow_test.dart` 跑 develop 字节）。
⇒ 更正：**develop 上勾任意一个标签就已经在漏**，不是"本轮把文案变长才暴露"。
本轮的 `Wrap` 顺手修掉了这条既有缺陷——原来那句"不是弹层本来就在漏"只对照了 develop 唯一不漏的那个状态，判错了。

## 反向探针（每条先跑"未打补丁"的对照组）

对照组 = 干净字节两文件 `+26: All tests passed!`（`/tmp/g69/CONTROL2.log`）。
`flutter test` 在命中 0 条用例时也报绿，所以没有对照组就分不清"用例不会红"和"根本没跑到"。

| 探针 | 抽掉什么 | 打补丁后 | 红在哪条 |
| ---- | -------- | -------- | -------- |
| PA | 词法整个退回"不认 #" | `-16` | 词法 **5** 条 + 界面 11 条（复核 F4 更正：原表写"8 条词法单测"是错的，`进度 50#`、`##草稿`、`C#` 这三条 PA 打不红 ⇒ 另立 PL）|
| PB | 未接 ensurer 时也剥 token | `-1` | `没接线 ensureTagIds 时 # 就是普通文字` |
| PC | 不按名字去重（按钮所选与 # 各算各的） | `-2` | `按钮所选标签与「#」标签合并去重后一起提交`（desktop+mobile） |
| PD | 空标题时静默 `return null`（不给提示） | `-1` | `整段只有「#周会」⇒ 不静默早退` |
| PE | 弹层里没有「新建标签」行 | `-4` | 创建成功/创建失败/连点两次/320px |
| PF | 去掉 `_busy` 的同步闸门 | `-1` | `连点两次「确定」只建一个标签` |
| PG | 「标签 N」只数按钮所选、不含 `#` | `-3` | 计数那条 + 桌面那条 + 320px 那条 |
| PH | `Wrap` 退回 `Row + children` | `-1` | `320px + 1.3 倍…`（真溢出，非断言写法问题） |
| PI | 失败时清空已选 | `-1` | `创建标签失败：sheet 不关、已选保留、给可见提示` |
| PJ | 同名匹配用**未 trim** 的原串比 | `-1` | `首尾空白不参与匹配…` |
| PK | 完全不查已有、每次都建 | `-3` | `已有同名就用它`、`首尾空白…`、`库里已有重名两行时取最早创建的那条` |
| PL | 词法改成"见到 # 就算 token"（过度贪婪） | `-3` | `单独一个 # 不是标签`、`## 开头不算标签`、`井号在词中间不算标签`（复核 F4 要求补的探针：这三条排除项 PA 永远打不红） |
| PM | 桌面 `_report` 的 body 清空 | `-2` | `desktop 复核 F5…`、`桌面：整段只有「#周会」⇒ SnackBar…`（复核 F5(a)：原 26 条全绿 ⇒ 本轮补的断言把它钉住了） |
| PN | 提交时建标签的 `catch` 摘掉 | `-2` | `desktop 复核 F5…`、`mobile 复核 F5…`（复核 F5(b)） |

### PJ 第一次是绿的 —— 记下来以免重犯

第一版「首尾空白」用例只喂了一次带空白的名字（库里还没有它），建完再喂**已经 trim 过**的名字。
于是把匹配改成 `tag.name == raw`（不 trim）也照样绿：用例只证了"存进去的名字被清过"，
没证"带空白能命中已有的那条"。⇒ 补第三段：已有 `周会` 时再喂 `'  周会  '`，PJ 才红在该红处。
⇒ 结论同第 64 轮：**一条断言只走"新建"这一支时，"命中已有"那一支是没人看的**。

## 门禁原文记录（跑在最终字节 `112d8b3`，日志 `/tmp/g69/gates/final.log`）

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check origin/develop...HEAD` 与工作区 | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed <本轮 5 个显式文件>` | `Formatted 5 files (0 changed)`，`rc=0` |
| `flutter analyze` | `No issues found! (ran in 2.0s)`，`rc=0` |
| `flutter test --tags golden` | `00:05 +9: All tests passed!`，`rc=0`；`git status --short test/goldens` 为空 ⇒ 9 张基线未重录 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:55 +924 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web`，`rc=0` |

**第一遍是 5/6**：门禁 2 在 `a5078c9` 上 `rc=1`（两个测试文件不合 `dart format`）⇒ 单提一个
`style(test)` 提交 `112d8b3` 后**六条全部重跑**，本表就是重跑后的字节。

计数对账（诚实记法）：`+924 = 898 + 26`。其中 **898 不是本轮实测的**——它来自第 64 轮在
同一基线 `origin/develop@9032005` 上实跑干净 worktree 记下的 `+898 ~26`（记录在**尚未合并的 `!347` 分支**的`specs/045-sort-direction/tasks.md` ⇒ 本分支 HEAD `git cat-file -e` 取不到该文件，复核已指出；复核员另在同一基线自行重跑，独立复算出 898），
本轮没有重跑基线；26 = 本轮新增（词法 8 + 落地 6 + 界面 12）。`~26` 跳过数与基线一致，未新增 skip。
`pubspec.lock` 未进提交（门禁跑完后 `git status --short` 为空）。

## 相撞面（在 tip 上重测）

`quick_add_bar.dart` 不在任何 open PR 的改动文件表里（!347 !346 !322 !319 !314 !311 逐一核对）。
`tasks_by_list_page.dart`：!347 改 39 行、!314 改 29 行，与本轮动过的两处（`QuickAddBar(...)`、
`MobileQuickAddButton(...)` 两个调用点 + 新增 `_ensureTagIdsByName`）**逐行交集为空**；
merge-tree 复测结果见下节。

## 复核（VERDICT: FAIL ⇒ 逐条回源复验后修复）

复核员在 tip `727da2f` 上重跑六道门禁全绿，并给出 5 条阻塞项 + 8 条非阻塞项。**全部接受**，无驳回：
每条我都自己回源复跑过（下表"我怎么验的"一列写的是实际执行的命令/脚本，不是复核员的说法）。

| 条 | 复核结论 | 我怎么验的 | 处置 |
| -- | -------- | ---------- | ---- |
| F1 | 「标签 N」把同名标签数两次（界面 2、实挂 1），且这是本轮新引入的回归（develop 上恒等于 `_tagIds.length`） | 先把复核员的 `rv350_count_test.dart` 抄进本 worktree 跑 ⇒ desktop/mobile 都红在 `标签 1` 找不到；读代码确认 `_tagCount = _tagIds.length + _pendingTagNames.length` 而 `_pendingTagNames` 未按已勾同名去重 | 计数与提交改走**同一个** `unresolvedHashTagNames(...)`；勾选返回后重算一次；新增 `desktop/mobile 复核 F1` 两条断言"显示数 == 实际 tagIds" |
| F2 | 同一会话二次建同名 ⇒ `_created` 长出两个同 key 的行 ⇒ `Duplicate keys found.` | 抄 `rv350_dupkey_real_test.dart`（真 Drift）跑 ⇒ 红；读 `_confirmNewTag` 确认 `for (id in ids) _created.add(...)` 无判重 | `if (_created.any((tag) => tag.id == id)) continue;` + 新增「连建两次同名只多一行、不炸」 |
| F3 | 「不是弹层本来就在漏」这句归因是错的：develop 的 `Row + Spacer` 勾一个标签就溢出同样的 31px | 独立复跑 `rv350_dev_overflow_test.dart`（develop 字节）⇒ `未勾=null`、`勾1个=overflowed by 31 pixels` | 更正那一节为"develop 上勾任意标签就已漏，本轮 `Wrap` 顺手修掉这条既有缺陷"，并写进 PR 正文 |
| F4 | PA 表写"8 条词法单测"不实（只有 5 条会被 PA 打红）；三条排除项缺探针 | 用脚本对词法做两处变异分别跑：PA ⇒ 词法 5 条红；新 PL（`isToken = line[index] == '#'`）⇒ 正好红 `单独一个 #`、`## 开头`、`C#` 三条 | PA 行改 `-16`（词法 5 + 界面 11）并写明原因；新增 PL 行 |
| F5 | 桌面 `_report` 与提交时的 `catch` 两条已上线分支没有任何"能失败"的用例 | 变异复跑：清空 `_report` body ⇒ 红 2 条；摘掉 `catch` ⇒ 红 2 条（这两条正是本轮新增的用例，见 PM/PN） | 新增 3 条用例（桌面空标题 SnackBar、桌面/mobile 提交时建标签失败） |
| 非阻塞 | 门禁记录指向 `112d8b3` 而 tip 已移动 | — | 见下节"门禁原文记录（复核修复轮）" |
| 非阻塞 | `specs/045-sort-direction/tasks.md` 在本分支 HEAD 不存在 | `git cat-file -e HEAD:specs/045-sort-direction/tasks.md` ⇒ 不存在 | 已在计数对账处标明它在**未合并的 `!347` 分支**上，且 898 由复核员独立复算 |
| 非阻塞 | 取舍 5 承诺"列出这批将添加的标签"，实装只有计数 | 读 `quick_add_bar.dart` 确认只有 `标签 N` | 以代码为准改 spec.md：只报数、不列名，列名与否待有图后校正 |
| 非阻塞 | `:144-186` / `:368-411` 行号量得不准 | `git show origin/develop:…` 再过滤 `_pickTags` ⇒ `:144`、`:369` | 改引起始行，不再引区间（区间会随下一轮漂移） |
| 非阻塞 | `tasks.md` 把"过期响应"写成 FR-6，FR-6 实为"不 bump schemaVersion" | 读 spec.md 的 FR 表 | 改挂到 FR-5 第四维 |
| 非阻塞 | 词法注释声称"没井号的行一个字都不该被改动"，实则每行都 `trim()` | `parseHashTagInput('  明天见').title == '明天见'` | 改注释说清"只去首尾空白，连续空白收拢仅对剥过 token 的行" |
| 非阻塞 | 读屏证据停在 widget 树；标识符节点自身 label 为空 | 复核员的语义 dump ⇒ `SemanticsNode#17 identifier 空 label`、子节点 `#18 label='标签 1'` | 320px 那条补 `find.bySemanticsLabel('标签 1')`，并在注释里写明"标识符节点本身 label 是空的" |
| 非阻塞 | 「确定」是本 sheet 里第三个确认动词（sheet 用「完成」、tag_page 用「保存」） | 读 `quick_add_bar.dart:292` 与 `tag_page.dart:219` | 建标签的确认按钮改「保存」，与 `tag_page` 同词 |

## 门禁原文记录（复核修复轮）

跑在提交后的最终字节 `bc9e68c` 上，日志 `/tmp/r66-gates.log`（对照：修复前的 tip 是 `727da2f`）。

| 门禁 | 结果 |
| ---- | ---- |
| `git diff --check 9032005..HEAD` + 工作区 | `rc=0`，无输出 |
| `dart format --output=none --set-exit-if-changed <本轮 5 个 dart 文件>` | `Formatted 5 files (0 changed)`，`rc=0`（第一遍 `rc=1`：新补的用例里有 4 行没合格式 ⇒ 单提 `style(test) bc9e68c` 后六条全部重跑） |
| `flutter analyze` | `No issues found!`，`rc=0` |
| `flutter test --tags golden` | `+9: All tests passed!`，`rc=0`；`git diff --name-only 9032005..HEAD -- test/goldens` 为空 ⇒ 9 张基线未重录 |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:57 +930 ~26: All tests passed!`，`rc=0` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web`，`rc=0` |

计数对账：`+930 = 924 + 6`——924 是本 PR 修复前 tip 上刚跑过的数（见上一节），6 = 复核修复轮新增用例（F1 两条、F5 三条、F2 一条）。未新增 skip。
`pubspec.lock` 未进提交：门禁跑完 `git status --short` 为空。
