# 任务清单：标签条件内部的「且 / 或」两档

基准提交：分支 `feat/334-tag-logic`，起点 `origin/develop@dede0d21fab9`。
下列行号以该起点之上的本分支工作树为基准（改动前的对照一律标 `origin/develop`）。

## 红测先行（三刀各自先看不绿）

- [x] 求值面 `test/features/filter/task_filter_tag_logic_or_test.dart`（6 条 `test(`）：
      首跑红在编译层 —— `grep -c "No named parameter with the name 'tagLogic'" /tmp/w/f334_red1.log` 得 12
      （红在「档位这个入参还不存在」，不是拼写错）。补完 `TaskFilter.tagLogic` + `applyTaskFilter` 分支后
      `/tmp/w/f334_green1b.log` 尾行 `00:00 +6: All tests passed!`。
- [x] 存套面 `test/features/filter/saved_filter_tag_logic_test.dart`（8 条 `test(`）：
      实现前整份加载失败（`/tmp/w/f334_red2.log` 末段 `Failed to load ... saved_filter_tag_logic_test.dart`）
      —— 红在 `TodoFilterConditions` 没有 `tagLogic` 这个构造参数；
      补完 `filter_repository.dart` + `saved_filter_mapping.dart` 后 `/tmp/w/f334_green2.log`
      尾行 `00:04 +53: All tests passed!`（跑的是整个 `test/features/filter/`）。
- [x] 界面面 `test/features/filter/advanced_filter_tag_logic_test.dart`（3 条 `testWidgets(`）：
      实现前 3 条全红，`grep -c "Found 0 widgets with key \[<'task-filter-tag-logic'>\]" /tmp/w/f334_red3.log`
      至少 1 条明写缺失的开关 key（其余两条在同一次运行里以用例名列在 `Failing tests:`）。
      日志在 `/tmp/w/f334_red3.log`，实现后 `flutter test test/features/filter/` 尾行
      `00:04 +57: All tests passed!`。

## 中途改掉的两处自己的错

- [x] 第一版让 `taskFilterFromSaved` 把未知逻辑词折成「且」：那是替用户改条件。改成整份返回 `null`
      （调用方标「本机暂不支持套用」），与 `statuses` 只认 `done`/`todo` 同口径；
      用例「服务端历史数据里的未知逻辑词不猜：按不支持套用」钉住它。
- [x] 第一版界面断言写成 `labels.any((l) => l.contains('且') && l.contains('或'))`：
      要求一个 label 同时含两个词，永远不可能成立，是废断言。改成读每档自己节点
      （`task-filter-tag-logic-and` / `-or`）的 `label`，并另用 `ChoiceChip.selected` 断互斥与选中态。
- [x] 为量「套用后界面上还剩什么」临时写的探针 `test/features/filter/w9_probe_test.dart`
      只做诊断、不留作回归用例，量完即 `rm`，没进提交（`git status` 干净可证）。

## 面板流实测纠正的一个假设计

- [x] 「套用条件后筛选面板会关掉」是错的假设。实测（临时探针，跑完即删）：套用后对话框关闭、
      `showModalBottomSheet` 仍开着（`todo-filter-advanced` 还在树上），此时再点 header 的
      `todo-filter-menu` 会被模态遮罩吃掉并顺手把面板关掉。
      ⇒ `_openAdvanced` 改成「面板在就直奔高级条件 chip，不在才开面板」，
      并在 helper 里写明这条实测口径。

## 实现

- [x] 词表常量与档位字段：`lib/features/filter/filter_bar.dart:9-10`（`tagLogicAnd` / `tagLogicOr`）、
      `:25`（`TaskFilter` 构造缺省 `and`）、`:45`（字段）、`:80`（`copyWith`）。
- [x] 判定口：`lib/features/filter/filter_bar.dart:99-100`
      （`tagsMatchAny` = 值归小写等于 `or` **且** `tagIds.length > 1`）。
- [x] 求值分支：`lib/features/task/tasks_by_list_page.dart:2218-2220`
      （「或」走 `filter.tagIds.any(owned.contains)`，「且」保留 `owned.containsAll`；
      改动前这里是写死的 `containsAll`，见 `origin/develop` 的 `:2215`）。
- [x] 面板接线：`lib/features/filter/filter_bar.dart:851-852`（`required this.logic` /
      `required this.onLogicChanged`）、`:863-864`（两个字段）、`:969-995`（开关本体，
      key `task-filter-tag-logic`，每档自带读屏节点 `task-filter-tag-logic-{and|or}`）。
- [x] 草稿三处同轮带上档位：`lib/features/filter/filter_bar.dart:345`+`:359`（`_draftFilter` 形参与主体）、
      `:412`（预览草稿）、`:600`（「应用高级筛选」回传）、`:216`（回传写回筛选态）、
      `:688`+`:697`（`_AdvancedFilter` 的构造与字段）。
- [x] 契约对象：`lib/state/repositories/filter_repository.dart:16`（构造）、`:28`（字段 `String?`）、
      `:37`（`toJson` 只在非 null 时出键）、`:51`（`fromJson` 的 known 集加 `tagLogic`）、
      `:63`（读值原样交给映射层判词表）。
- [x] 双向映射：`lib/features/filter/saved_filter_mapping.dart:28`（只有「或」出键）、
      `:53-60`（未知词判 `null`）、`:69`（还原时 `null` 落回 `and`）。
- [x] `isEmpty`（`lib/features/filter/filter_bar.dart:102-112`）**不含** `tagLogic`：
      单有档位不构成一条条件，否则切过一次档就永远显示「有筛选」。

## 反向探针（四处各自摘一环，被测用例必须变红；每处改完 `cmp -s` 证字节还原）

- [x] R1 `if (widget.selected.length > 1)` → `if (false)` ⇒ `advanced_filter_tag_logic_test.dart` 变红。
- [x] R2 预览草稿 `tagLogic: selectedTagLogic` → `tagLogic: tagLogicAnd` ⇒ 同文件变红
      （切档不再改预览命中数，证明「命中 N 项」真的跟着档位走）。
- [x] R3 写回 `tagLogic: next.tagLogic` → `tagLogic: tagLogicAnd` ⇒ 同文件变红
      （重开对话框读不回档位，证明档位进了筛选态）。
- [x] R4 去掉 `&& tagIds.length > 1` ⇒ `saved_filter_tag_logic_test.dart` 只有
      「只有一个标签时不算「或」、也不写键」一条变红，其余 7 条仍绿（`+8 All tests passed`）。
- [x] 求值面 R0（更早一轮）：`/tmp/w/f334_probe.log` 里「或」档与大小写两条各自变红，
      证明 `applyTaskFilter` 的分支被数到。

## 门禁（跑在 commit 之后，日志 `/tmp/w9_gate.log`）

- [x] `flutter analyze` rc=0（`grep -n "No issues found" /tmp/w9_gate.log` 命中，行 73）
- [x] 全量 `flutter test` rc=0（`grep -n "All tests passed" /tmp/w9_gate.log` 命中行 1808，
      读数 `01:22 +1509 ~26: All tests passed!`；`~26` 是既有跳过项，golden 基线未重录）
- [x] 门禁跑完 `git status -s pubspec.lock` 为空 ⇒ 本机镜像没被扫进提交
- [x] 台账自扫 `python3 tool/check_spec_selfscan.py specs/085-tag-logic-filter/spec.md` rc=0、
      `python3 tool/check_spec_selfscan.py specs/085-tag-logic-filter/tasks.md` rc=0
      （两次都把输出重定向进文件再读 `$?`，不接管道 —— 接 `tail` 会把 rc=1 读成 0；
      日志 `/tmp/w9_scan_spec.log` 与 `/tmp/w9_scan_tasks2.log` 各为「失项 0 条」）
- [x] 这把尺的判别力现证：`python3 tool/check_spec_selfscan.py --selftest specs/085-tag-logic-filter/tasks.md`
      rc=0 且尾行「与期望不符的判据 = 0 条」；再往本文件开头注一条指向不存在文件的「路径:行号」锚
      （形态是 `lib/features/filter/` 下一个仓里查无此文件的名字，这里不照抄它，照抄会被自家尺判成死锚点）
      ⇒ rc=1 并报「锚点 ... 指不到 —— 绝对路径、仓库根、git 索引三处都查过」
      （日志 `/tmp/w9_scan_bad2.log`，失项 1 条），撤掉后回到 rc=0。
      所以上面那个「失项 0 条」不是恒绿的空尺

## 交叉验证与复核状态

- [x] `cursor-agent` 第二轮出了实质意见（`/tmp/w/cursor_w253b.log`，7578 字节），采纳三条：
      「只在值为 or 时写键」「档位只在 ≥2 个标签时参与一切（含落盘）」「面 ⑥ 现在就另立单，
      别被面 ⑦ 的 PR 用 `Fixes` 关掉」。
- [x] 它否掉的两条前提由我用自己可复算的命令否证：它读的是本机 `zh-cloud-service` 的
      `feat/274-habit-countdown-archive` 陈旧检出，而 `origin/develop@7bd493dd1265` 上
      `TodoFilterConditionsDO.java:43` 就是 `private String tagLogic;`（复算见 spec.md）。
- [x] 它要求核对的文档引句：`git -C zh-cloud-docs diff f53674736ace... ded8a99737ed -- '<05-过滤器路径>'`
      输出为空 ⇒ `:61`/`:71` 在 docs `origin/develop` 上同样成立，可以引。
- [ ] **未经独立复核**：claude `-p` 的 VERDICT 通道本轮仍是 0 字节（无结论），
      替代判据是上面四处反向探针 + 两道门禁。不假装复核过。

## 本轮故意不做

- [ ] 条件之间的逻辑词（`conditionLogics`）：另立 FL #524。本轮它继续留在 known 集之外，
      整份判「不支持套用」——这是现状的诚实表达，不是遗漏。
- [ ] 已保存过滤器的 folderIds 持久化：卡在 zh-cloud-service #340（契约扩 `todo_filter.conditions`），
      客户端这面维持「拒绝保存并在对话框点名」。
- [x] 矩阵翻面：#22 行的 ⑦ 记为已落 develop，⑥ 因 #524 仍缺 ⇒ 该行整体判定不变（仍「部分」），
      缺口计数不动；追记写在 docs 的里程碑格里。
