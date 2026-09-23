# 已保存过滤器可用（矩阵 #22）

- [x] T001 静态占位原样搬成 public `SavedFiltersPage` 并接进 `home_shell`（行为不变，为的是让红测落在断言层）。
- [x] T002 红测：11 条用例先失败，失败信息精确指向缺失实现。
- [x] T003 数据层：`filter_repository` 补 `dateRange`/`fromJson`/`watchAll`/`remove`；`providers` 补两个 provider。
- [x] T004 真实现：列表页渲染真数据 + 摘要 + 空态 + 错误态 + 二次确认删除；保存改道真表；套用经 `initialFilter` 落到任务面板。
- [x] T005 复核 FAIL 的必须改全部落地（两处静默错条件、lock、drive-by 格式、文档过头话、preset 命名）。
- [ ] T006 矩阵 #22 回写与状态翻转（翻转须引**已合并** SHA）。

## 执行证据

- 2026-09-23：RED。首跑（真实现之前）红在断言层，不是编译错 ——
  `本机存不住的维度…` 报 `Found 0 widgets with text "本过滤器不保存：…"`、
  列表类用例报 `Found 0 widgets with text "高优先级英语"`（页面当时还是 3 条写死条目）。
  实现后 `flutter test test/features/filter/saved_filters_test.dart` → `00:01 +11: All tests passed!`。
- 2026-09-23：为什么不用「智能清单」那条现成的路 —— 实测它是断的：
  `list_repository.dart:216` 把条件只塞进 outbox payload（本地无列可放）、
  `SmartListFilter.fromListName`（`:260-275`）在 `lib`+`test` 零调用、
  `list_page.dart:197-201` 点已存智能清单只弹 SnackBar、侧栏「智能清单」是 7 个硬编码行。
  而真表侧 `todoFilters` schema、第 13 号迁移、push 本地化、`_upsertLocalFilter`、
  tombstone、`/filter/apply` 契约全在 —— 只缺仓库两个方法与一处 UI。
- 2026-09-23：术语按嘀嗒改回「过滤器」。帮助中心那一页写的是侧栏「添加 → 过滤器」与
  「悬停过滤器点 + 号」，本仓原先叫「保存为智能清单」属自造同义词。
- 2026-09-23：只读复核 `VERDICT: FAIL`（本会话子代理，`claude` CLI 不可用），抓到两处**我写的静默 bug**，
  都是「套一半」：
  ① `statuses:["in_progress"|"cancelled"]`（服务端契约允许）只被「长度 > 1」挡住，单值会穿过映射、
  在还原分支落到 `_ => null` ⇒ 行可点、摘要还写着「进行中」，套上后**状态条件凭空消失**；
  ② 带 `tagIds` 的行可点，但 `applyTaskFilter`（`tasks_by_list_page.dart:2010-2077`，我这次亲自逐行核过）
  根本没有标签分支 ⇒ 套用结果与摘要承诺不符。
  两处都改成「标『本机暂不支持套用』且不可点」，并补用例（直插两条 pull 风格的行，
  断 `findsNWidgets(2)` + 点完页面仍在原地）。复核自己的反向探针（它把 `skipped` 回报删掉、
  把页面换回假条目、把保存改回 `saveSmart`、去掉 `Semantics`）也都逐条复现了红。
- 2026-09-23：另外三项必须改已落地：① `pubspec.lock`（本机镜像与新 SDK 重解析，整本 url/版本漂移）
  不 stage；② 还原 `tasks_by_list_page.dart` 两处与本切片无关的换行重排（我是原地 format 带出来的，
  最后用「基线文件 + 只重放 5 个本意 hunk」重建，`git diff` 从 8 个 hunk 降到 5 个）；
  ③ 文档不再声称「每处都做了反向对照」——`preset` 命名与错误态当时确实没测，现已各自补上用例；
  ④ `dueRangeChipLabel` 补齐 `tomorrow/last7days/next7days`，否则点名文案会露出兜底的「Due」。
- 2026-09-23：六项门禁（`/tmp/gate-029.log` 为改前一遍、`/tmp/gate-029-final.log` 为最终状态）：
  `git diff --check` exit=0；`dart format --output=none --set-exit-if-changed` 对 9 个显式文件
  `Formatted 9 files (0 changed)`；`flutter analyze` `No issues found!`；
  `flutter test --tags golden` `00:04 +9: All tests passed!`（9 张基线未变，`git status test/goldens` 空）；
  全量 `+721 ~26: All tests passed!`；`flutter build web --release` `✓ Built build/web`。

## 未勾项与下一步

- T006 未勾：#22 状态要等本 PR 合并后引**已合并** SHA 才翻；本轮只在矩阵里把「无本地入口」改成
  「入口已实现待合并」，并写清剩余缺口。
- **契约缺口，需先在 `zh-cloud-service` 动再回客户端**（不得由 Flutter 硬编码绕过）：
  `conditions` 现在只有 `listIds/tagIds/dateRange{preset,from,to}/priorities/statuses/keyword`，
  装不下 ①「已过期 / 将来」这类 preset（无对应字段）②文件夹维度 ③「且 / 或」布尔分组。
  ⇒ 这三类条件本轮**明确拒绝保存**并在对话框点名，不是静默丢；要支持得扩 `conditions` 与
  本地 `TodoFilterConditions` + 新迁移。
- 未覆盖：`home_shell._openFilters()` 那 5 行接线没被 pump `HomeShell` 直接验（两端各自有用例：
  页面 pop 忠实 `TaskFilter`、面板吃 `initialFilter` 真的筛）；跨端「保存→push→另一台 pull→套用结果一致」
  需 test 环境与第二台设备。
- 未做（本轮非目标）：过滤器重命名/改条件、「且/或」高级筛选、任务面板的标签维度筛选（`applyTaskFilter` 缺分支，
  这条同时是上一项 bug 的根因，应单开切片补齐）。
- `efficiency_hub_page.dart` 与「智能清单」旧链路仍在仓内无调用点，本切片只登记不删。
