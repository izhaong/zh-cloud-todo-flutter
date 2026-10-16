# 144 · specs 编号唯一性（治理：045 四占一、090 与 105 各二占一，原 FL #395）

## 背景

FL #395 记的是「045 被四条未合并分支各占一名」。本轮现读（2026-10-16，
`origin/develop` tip `2e00505c`）发现**已经合进 develop 的不是 1 组而是 3 组**：

| 号 | 目录名（都在 develop 上） |
| --- | --- |
| 045 | `045-filter-preview-mode`、`045-kanban-card-assign`、`045-keep-loaded-on-refresh`、`045-sort-direction` |
| 090 | `090-tag-rightclick`、`090-tag-sort` |
| 105 | `105-list-properties`、`105-task-default-reminder` |

三条都是**互不相同的规格**（逐份比对过首行标题）。原单只记 045，是因为它读数时
090/105 那几笔还没合；这印证原单第 1 条诊断的成因——**取号只看 develop**。

## 为什么这是问题而不是难看

目录名不同 ⇒ git 不冲突 ⇒ 四/两条都能合进 develop。后果在**引用层面**：
「specs/045」合完之后有四个所指，矩阵任何一格引它都可能拿别的面当证据。
本仓已有裸引用的实例（`specs/052-calendar-list-timeline/tasks.md:225`、
`specs/095-habit-stats-heatmap/spec.md:24`）。

## 处置（按原单第 2 条口径）

**先合的保号，后合的改名**。定序依据是 `--first-parent` 上该目录首次进入 develop
的合并提交时间（不是 commit author 时间，也不是目录内容日期）：

| 组 | 保号（先合） | 改名（后合）→ 新号 |
| --- | --- | --- |
| 045 | `045-keep-loaded-on-refresh`（09-28 00:40） | `045-sort-direction` → **139**（02:41）<br>`045-kanban-card-assign` → **140**（04:08）<br>`045-filter-preview-mode` → **141**（05:56） |
| 090 | `090-tag-sort`（10-11 16:06） | `090-tag-rightclick` → **142**（16:15） |
| 105 | `105-list-properties`（10-12 16:17） | `105-task-default-reminder` → **143**（10-13 04:19） |

新号按原单第 1 条新规取：扫 **develop ∪ 全部未合并分支** 的并集取空号（139–143 均空）。

## 边界：不改别的规格里的历史记录

改名那条只改**自己台账里的自引用**（标题 + `specs/<新名>` 路径）。**不**去改
其它规格里那些**历史记录**性质的旧名引用，例如：

- `specs/052-calendar-list-timeline/tasks.md:102` 里那条 `feat/320-sort-direction:` 开头的
  分支限定引用 —— 这是在陈述「某根**已删除**分支上当时那条路径」，改成 139 会让这句
  话变成假的（那根分支从来没有 139 这条路径）。该分支已删，故本条按「历史记述」
  保留原样、不当作可解析锚点。
- `specs/047-hash-tag-entry/tasks.md:8` 里「未合并分支已经占了 045（`specs/045-sort-direction`…）」
  —— 是当时取号理由的记述。

机械全仓替换会把这些一并改错，本轮踩到并已回退（见 tasks.md 教训 1）。

## 加固判据

新增 `tool/check_spec_number_unique.py`：
- 读**当前 HEAD** ∪ **各未合并分支相对自己 merge-base 新引入**的 `specs/` 目录名，
  按号聚合，出现一对多即红。
- `--selftest` 四条：① 干净基线不误判 ② 同号两目录会红 ③ 同一目录的另一版本不误判
  ④ **陈旧分支上的旧目录名不误判**（关键：`merge-tree` 实测旧名会消失，因为
  develop 一侧删除、分支一侧未改 ⇒ 删除生效）。
- 第 ④ 条是这个判据第一版的真 bug：把陈旧分支的旧名当成仍占用，会导致**改名之后
  判据永远红着**。已修并留探针。

## 验证

| 门 | 读数 |
| --- | --- |
| `--selftest` | `SELFTEST OK(① ② ③ ④)` |
| 本分支 HEAD | `specs 编号一对一：0 处撞号` |
| 反向探针：修复前 develop 树 | `撞号：3 处`（045×4、090×2、105×2） |
| 13 个改名文件自扫 | 各 `失项 0 条` |
| `flutter analyze` | `No issues found!` |
