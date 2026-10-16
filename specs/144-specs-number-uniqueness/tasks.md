# 144 台账

## T1 现读撞号（不只信原单）

- [x] 扫 develop `specs/`：撞号 **3 组**（045×4、090×2、105×2），原单只记 045。
- [x] 逐份比对首行标题，确认各组内是**互不相同的规格**。
- [x] 定序：`git rev-list --first-parent --reverse origin/develop` 找该目录首次出现的合并提交。

## T2 改名

- [x] `git mv` 五个目录 → 139/140/141/142/143（新号取自 develop ∪ 未合并分支并集空号）。
- [x] 改各自台账标题（`# 045 ·` → `# 139 ·` 等）与自引用路径。
- [x] 回退对**外部历史记录**的机械替换（5 个文件）。

## T3 加固判据

- [x] `tool/check_spec_number_unique.py`。
- [x] selftest ①–④；④ 是第一版真 bug 的探针。

## 过程教训

1. **机械全仓替换会改坏历史记录**：第一版把
   `feat/320-sort-direction:specs/045-sort-direction/tasks.md` 也换成 `139-`，
   而那根分支（已删除）上从来没有 `139-` 这条路径 ⇒ 该陈述变假。
   同类还有「未合并分支已经占了 045」这种**当时取号理由**的记述。
   ⇒ 改名只改**自己**的自引用；别人的历史引用属别人的账。
2. **判据的第一版把「陈旧分支的旧名」当占用**：改名后判据仍报 3 处撞号。
   根因是没意识到 git 的 merge 语义——develop 一侧删除、分支一侧相对 merge-base
   未改 ⇒ **删除生效**，旧名不会复活。用 `git merge-tree --write-tree` 实测确认后
   改为「只算分支相对 merge-base **新引入**的目录名」，并把这个场景补成 selftest ④。
3. **原单的建议 3 明确要求「必须拿已知有错的基线证明它会红」**：本轮反向探针
   （干净 develop 树）实测 `撞号：3 处`，不是写完就宣称有效。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `--selftest` | `SELFTEST OK(① 不误判 ② 会红 ③ 版本分叉不误判 ④ 陈旧分支不误判)` |
| 本分支 HEAD | `specs 编号一对一：0 处撞号` |
| 反向探针（修复前 develop） | `撞号：3 处` |
| 13 个改名文件 `check_spec_selfscan.py` | 各 `失项 0 条` |
| `flutter analyze` | `No issues found!` |
| `flutter test test/user_journey_simulation_test.dart` | `+16 All tests passed!` |
