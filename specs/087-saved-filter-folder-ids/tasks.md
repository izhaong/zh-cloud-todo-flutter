# 任务清单：已保存过滤器接上 folderIds

基准提交：分支 `feat/527-saved-filter-folder-ids`，起点 `origin/develop@eeeccd6f80d4`。
行号以该起点之上的本分支工作树为基准（改动前的对照一律标 `origin/develop`）。
契约侧基准 zh-cloud-service `origin/develop@cedbf31eb0f4`（`specs/029-filter-folder-conditions/`）。

## 红测先行

- [x] 单元 + 界面一起先写，首跑红在编译层：`/tmp/w13_red2.log` 报
      `No named parameter with the name 'folderServerIds'`（第 13 行）、
      `No named parameter with the name 'folderLocalByServerId'`（第 103 行）、
      `The getter 'folderIds' isn't defined for the type 'TodoFilterConditions'`（第 119/138 行）——
      即「映射层还不认这一维」，不是断言不成立。
- [x] 第一次红跑（`/tmp/w13_red1.log`）红在**我自己写错的 import** 上：包名是 `zh_cloud_todo_flutter`，
      我按别的仓的习惯写了 `package:todo/…` ⇒ `Couldn't resolve the package`。
      那条读数不算红测证据，换掉 import 后重跑才拿到上面那三条。
- [x] 实现后 `flutter test test/features/filter/` 尾行 `00:05 +98: All tests passed!`
      （`/tmp/w13_green3.log`；起点 develop 上同一目录是 83 条 ⇒ 差 15 = 本轮新增 14 单元 + 1 界面）。

## 反向探针（六处各自摘一环，全部要红）

逐处读数在 `/tmp/w13_probes.log` 与 `/tmp/w13_t6.log`。包装脚本一律先 `assert 锚点命中 1 次`，
不满足就 `exit 7`（第 255 轮立的规矩）。

- [x] T1 映射得到也不写、退回「一律点名文件夹」⇒ 红（存得下这条被作废）。
- [x] T2 `toJson` 去掉「非空才出键」⇒ 红（老过滤器重新落库时 JSON 形状会变）。
- [x] T3 形状校验从「每项都是 int」放宽到「每项都是 num」⇒ 红（`[41.5]` 被折算成 41 = 替用户换文件夹）。
- [x] T4 去掉「多于一条就不套」并把 `.single` 换成 `.first`⇒ 红（两条文件夹时挑第一个是替用户改条件）。
- [x] T5 `activeConditionKeys` 不把 folderIds 算进条件行 ⇒ 红（面板位置判定与服务端放置校验分家）。
- [x] T6 provider 未发值时返回空表而不是 null ⇒ **第一版是 GREEN，读数作废**：
      上面那批用例把映射表当**参数**传进 `savedFilterOf`，够不到 provider，
      所以「null vs 空表」这个分支一条断言都没量到。补一条直接 `container.read(folderServerIdIndexProvider)`
      （override `foldersStreamProvider` 成永不发值的流）后重跑，T6 恰红在新增那条
      （`/tmp/w13_t6.log`：只有 `摘要与连接词位置 文件夹流还没发值时索引是 null，不是空表` 一条），
      还原后 `00:00 +15: All tests passed!`。与「时序/读屏断言要做灵敏度对照，否则绿测是恒真」同族。

## 中途改掉的四处自己的错

- [x] 批量补调用点参数的脚本写了死循环：`text.find(call + '(', i)` 每次都从头找 ⇒ 同一处反复插参，
      脚本被超时挂到后台。**没有任何文件被写坏**（写盘在两个 assert 之后，`git status` 证当时只有我的 5 个 lib 改动）。
      改成带游标的版本（每次从上一次闭括号之后继续找）后一次跑通 23 个调用点。
      规矩：脚本里的"找下一个"必须推进游标；批量写盘一律放所有断言之后。
- [x] 第一版插入没看闭括号前是否已有尾逗号 ⇒ 生成 `, ,` 语法错（三个测试文件红在
      `Expected an identifier, but got ','`）。从 git 还原后改成「尾逗号风格就不再补逗号」，
      并加 `assert ', ,' not in s`。
- [x] 一个 provider 测试的写法踩到自己：先前那些用例只测映射层，量不到 provider（见 T6 那条）。
- [x] **台账把校验和提交串在同一条命令链里，结果把红放行成了提交**：这一段第一次写完后 selfscan 报 rc=1
      （我在散文里逐字引了那条"假锚点"，而尺子分不清"引用旧错"和"提出证据"，一律按死锚点判红），
      但命令是 `scan ; git commit && git push` 的形态 ⇒ 提交与推送照跑，红读数被吞掉。
      两条一起改：散文里不再出现「假文件路径 + 冒号行号」这种形状（改成中文描述），
      并且校验与写操作分成两步 —— 只有 `if scan; then` 才允许提交。
      已推出去的那一笔（`30b94fb`）不 amend，用本笔修正覆盖，PR 正文与这里都写明经过。

## 实现

- [x] 契约对象：`lib/state/repositories/filter_repository.dart:30`（`List<int> folderIds`）、
      `:49`（`toJson` 非空才出键）、`:66`（known 集）、`:94-101`（形状校验：数组且每项 `is int`，
      否则退回 `unsupportedKeys`，刻意不复用宽容的 `_ints`）。
- [x] 映射：`lib/features/filter/saved_filter_mapping.dart:14`（`folderServerIds` 必传，可为 null）、
      `:19-31`（就绪/查不到/索引没到位三种形状各自一条文案，缺服务端 id 那条点名到本地主键）、
      `:69`（写侧出键）、`:89-105`（读侧：多于一项或反查不到就整份不套）、`:136`、`:187`（摘要出「文件夹 N 个」）。
- [x] 与服务端同源的条件顺序：`lib/features/filter/filter_bar.dart:18`（`conditionOrder` 第七条位）、
      `:45`（`activeConditionKeys` 把文件夹算成 `folderIds`）、`:708`（保存时现取索引）。
- [x] provider：`lib/state/providers.dart:509-516`（本地主键→服务端 id，未发值返回 null）、
      `:520-524`（反向索引，同样 null）；套用侧接线在 `lib/features/filter/saved_filters_page.dart:42`。
- [x] 摘掉旧的整维拒绝：`lib/features/filter/saved_filter_mapping.dart` 里原
      `if (filter.folderId != null) skipped.add('文件夹');` 已不在本分支
      （复算 `grep -c "skipped.add('文件夹')" lib/features/filter/saved_filter_mapping.dart` 得 0；
      develop 上同一模式经 `git -C zh-cloud-todo-flutter grep -c "skipped.add('文件夹')" origin/develop -- lib` 得 1 个文件）。

## 门禁实跑读数

两次都跑在提交之后（`pub get` 会重写 `pubspec.lock`，先跑后提交会把本机镜像扫进 PR）：

- [x] 第一次（`d7f79e2` 实现提交之后）：`flutter analyze` rc=0（`/tmp/w13_gate.log:74`），
      全量 `flutter test` 尾行 `01:28 +1550 ~26: All tests passed!`、`TEST_RC=0`（`/tmp/w13_gate_test.log`）
      —— 与上一轮 `+1535 ~26` 差 15 = 当时新增的 14 条单元 + 1 条界面，`~26` 没动 ⇒ 没碰到别的测试。
- [x] 第二次（`c68f88f` 补 provider 用例之后）：`/tmp/w13_gate2.log:74` `ANALYZE_RC=0`，
      `/tmp/w13_gate2_test.log` 尾行 `+1551 ~26: All tests passed!`、`TEST_RC=0` —— 比第一次多 1 条，
      正是 T6 补的那条 provider 用例。
- [x] 台账自扫两份都失项 0（`python3 tool/check_spec_selfscan.py specs/087-saved-filter-folder-ids/spec.md`
      与 `…/tasks.md`，rc=0）。反向对照各跑一次：往 `spec.md` 末尾追加一条死锚点
      （往 `spec.md` 末尾追加一条指向不存在文件的锚：一个 `lib/features/filter/` 下的假文件名带行号）⇒ 报 `失项 1 条`、rc=1；
      还原后 `cmp -s` 通过、两份各自回到 `失项 0 条`。
      注：第一次跑这个对照时它报"没红"，那次没有打印行数差，**归因不出来**（可能是 append 没生效，也可能是别的）；
      重跑时先打印 `wc -l` 前后差再判色，两次都真变红。仍是「计划跑对照 ≠ 跑过对照」那一族。
- [x] 本台账（markdown）提交后不再重跑门禁：这条规矩防的是 `pub get` 把 `pubspec.lock` 里的镜像地址扫进 PR，
      纯文档提交动不了代码；两次跑都覆盖了当笔代码提交的字节。
      复算 `git diff --name-only d7f79e2..HEAD | grep -c pubspec.lock` = 0（两笔提交都没碰锁文件）。

## 已知未做

- 面板的文件夹条件仍是**单选** ⇒ 契约那一条数组只吃得下 1 项。#527 的第 3 项没做完，
  所以 PR 用 `Refs #527` 不用 `Fixes`（写 `Fixes` 就是一句不实的完成声明）。
- 真后端（test 环境）「存带文件夹条件的过滤器 → 换端套用」没跑；本轮只证客户端两侧形状与文案。
- 子文件夹展开：本端与服务端都按"直接挂在其中的清单"，口径待 zh-cloud-service #344 定。
