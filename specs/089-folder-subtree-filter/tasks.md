# 任务清单：文件夹筛选按子树求值（客户端）

基准：分支 `feat/344-folder-subtree-filter`，起点 `origin/develop@165bb36`（并行会话刚合掉 FL !529/!530，
本分支切在 `4cb2ac1` 后又被那次合并顶起来，已 `git rebase origin/develop` 重跑门禁）。
改动前对照一律标 `origin/develop`。零 DDL、零新列。

## 红测先行（先看不绿）

- [x] 索引语义先写红：临时摘掉 `folderAndAncestors` 那三条例象用例、只留 provider 用例，跑当前 develop ⇒
      `+2 -2`，两条红在语义上：
      ① 「清单挂在子文件夹：索引要同时带上子与父」报 `Expected: Set:['leaf','mid','root'] / Actual: 'leaf'`
      —— 这就是"只算直属"的字节证据；
      ② 「清单发过值、文件夹还没发值 ⇒ 索引算没就位」红在它返回 `{}` 而不是 null。
      日志 `/tmp/w15_fl_P0`… 之前的那一次独立运行（临时文件 `w15_probe_only_test.dart`，跑完即删，
      现读 `ls test/features/filter | grep -c w15_probe` 得 0，不把探针留在仓里）。
- [x] `folderAndAncestors` 那三条例象用例首跑红在**编译层**（函数还不存在），
      这条红只证"还没有这个函数"，不证语义 —— 语义由下面 P3 量。

## 反向探针（五条各自摘一环；备份取在变异之前，跑完立刻还原并 cmp -s）

逐处读数在 `/tmp/w15_fl_probe.log`（P1/P3）与 `/tmp/w15_fl_probe2.nohup`（P2/P4/P5）。
包装脚本先断言锚点命中 1 次、改动确实落地，否则 `exit 7` 不跑 —— 这条纪律本轮真的挡住了一次：
P2 第一版的锚（`final folders = …valueOrNull;` + `if (folders == null) return null;`）在 providers.dart 里
**命中 2 次**（256 轮那条 folderServerIdIndexProvider 同形），脚本直接停在 `ANCHOR_HITS=2`，
没有把"根本没变异"的绿灯当成探针结果。换成四行锚后才落地。

- [x] P1 索引退回「只算直属」（`{list.folderLocalId!}`）⇒ 红 1 条（provider 那条内容用例）。
- [x] P2 去掉「文件夹图没就位就算没就位」的守卫 ⇒ 红 1 条（null 那条），证明"等"是被量的而不是装饰。
- [x] P3 祖先链只走一层 ⇒ 红 2 条（`folderAndAncestors` 三层链 + provider 内容用例）。
- [x] P4 文件夹条件恒放行 ⇒ 红 4 条，逐条点名：
      「文件夹条件参与求值：只留所属清单挂在该文件夹下的任务」
      「未归类的清单不命中任何文件夹条件（不是「放行」）」
      「清单挂在子文件夹时，选父文件夹也要命中（Issue #344 的子树口径）」
      「离线建、还没有服务端 id 的文件夹同样能筛（条件不依赖 serverId）」
      —— 这四条都靠同一个排除式，恒放行就把它们一起放开。
- [x] P5 「只认集合里第一个」＝只认直属 ⇒ **精确红 1 条**（面板祖先用例），
      这条把 applyTaskFilter 那一半的 membership 也量到了（P1 只量到 provider）。
- [x] 还原后复跑 `VERIFY` ⇒ `+12: All tests passed!`，`cmp -s` 两份备份都证字节回来，
      `git status --porcelain` 只剩本轮新增的 specs 目录。

## 门禁读数（都跑在 commit 之后的最终字节上）

- [x] `flutter analyze` ⇒ rc=0，`No issues found!`（rebase 到 `165bb36` 之后重跑，日志 `/tmp/w15_analyze.log`）。
- [x] 全量 `flutter test` ⇒ rc=0，尾行 `01:31 +1571 ~26: All tests passed!`（日志 `/tmp/w15_fl_full.log`）。
- [x] 两个被改测试文件现读 `^\s*test(` 计数：`folder_filter_condition_test.dart` 5 条、
      `list_folder_subtree_index_test.dart` 7 条；`git diff HEAD~1 -- test` 累加新增声明 8 条、删除 0 条 ⇒ 与 5+7 对得上。
- [x] `pub get` 之后 `git status --porcelain` 无 pubspec.lock 漂移（本机镜像没被顺手写进 PR）。

## 服务端那一半

契约与求值在 zh-cloud-service 分支 `feat/344-folder-descendants`，台账 `specs/030-folder-descendant-filter/`
（全模块 465 / 失败 0 / 错误 0，基线同尺实测 459 ⇒ 净增 6 条）。两边同轮落，
否则同一个父文件夹条件会有一套"按直属算"和一套"按子树算"的答案。

## 台账自扫

- [x] 自扫各跑一次，并与 commit 分成两条命令跑（256 轮的教训：判据 rc 串进 commit 链会把红放行）：
      `python3 tool/check_spec_selfscan.py specs/089-folder-subtree-filter/spec.md` ⇒ 失项 0 条、rc=0；
      `python3 tool/check_spec_selfscan.py specs/089-folder-subtree-filter/tasks.md` ⇒ **首跑失项 1 条**
      （`:30 写「4条」，紧跟的括号里却枚举了 2 项`），按它给的修法把四条用例逐条点名后复跑 ⇒ 失项 0 条、rc=0。

## 复核

- [ ] claude VERDICT 通道本轮仍回 0 字节 ⇒ **未做独立复核**。替代判据：五条反向探针 + analyze rc=0 +
      全量 test 尾行 + 基线自读，已写进 PR 正文。

## 已知未做

- 面板的文件夹条件仍是单选（契约 `folderIds` 是数组）。按 zh-cloud-docs Issue #161 的判定属增强项、不记 parity 缺口。
- test 环境真后端往返：建一个"父文件夹"条件、在另一台设备套用后结果集一致，这一条两边都还欠着实测（本轮只到单元/接口级）。
