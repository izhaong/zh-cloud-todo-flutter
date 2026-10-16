# 148 台账

## T1 取证（改动前）

- [x] 现读：`resolve()` 三处查、`bare_matches()` 查本仓 `git ls-files` ⇒ 跨仓引用结构上不可解析。
- [x] 现读：死锚点只在 `\.(log|md|dart|txt|py)$` 成立时报 ⇒ `.sql` 锚点被**静默跳过**。

## T2 改动

- [x] `CROSS_AT` / `SIBLING_NAME` / `ANCHOR_STATS` / `reset_anchor_stats()`。
- [x] `sibling_repo_root()`（`../<name>`，再 `$ZH_CLOUD_ROOT/<name>`）。
- [x] `cross_blob_lines()`（显式 ref 优先，退 `origin/develop` → `develop` → `HEAD` → 工作树）。
- [x] 两趟锚点扫描：`CROSS_AT` 在前、`BRANCH_REF` 其次、`REF` 最后；三者共用 `scan` 打码。
- [x] 分类计数在 `main()` 打印。

## T3 判据

- [x] `--selftest` 新增 5 条语料（跨仓绿 / 去仓名红 / 缺仓红 / 越界红 / `@ref` 绿）。
- [x] `--selftest` 全量：与期望不符的判据 **0 条**（复跑：`python3 tool/check_spec_selfscan.py specs/148-cross-repo-anchor-resolution/tasks.md --selftest`）。
- [x] **回归对照**：新老脚本对标准布局下 139 份 FL 台账逐份比对 ⇒ 失项数有变 **0 份**（只增不改）。
      复跑：`ls zh-cloud-todo-flutter/specs/*/tasks.md | wc -l` ⇒ 139
- [x] 真数据验证：以 `zh-cloud-service` 作仓库根，对同一条**真路径**跑五种形态（命令可复跑）：
      `git -C ../zh-cloud-todo-flutter show origin/develop:lib/features/habit/habit_month_grid.dart | sed -n '110p'`
      ⇒ 跨仓形态**失项 0**、去掉仓名**1 条红**、`@ref` 形态**0**、缺仓**1**、越界**1**。
      注：这条要兄弟仓在场（或设 `ZH_CLOUD_ROOT`）才跑得出绿 —— 这正是要求 2 的行为。
- [x] FL `specs/026-todo-sidebar-list-management/tasks.md` 里那条真实的跨仓 `.sql` 锚点：
      标准布局 / 设 `ZH_CLOUD_ROOT` ⇒ 失项 0
      （分类计数 `跨仓可比对 1`）；不设 env 且在非标准布局 ⇒ 判红（要求 2 生效）。
- [x] 本轮新增的 6 份台账（137/138/144/145/146/147）各文件 `失项 0 条`。

## 过程教训

1. **两趟扫描共用一个 `scan` 时，每趟都必须迭代 `scan`**：`BRANCH_REF` 原来迭代 `line`，
   不尊重前面打过的码。它以前排第一所以没暴露；新加的 `@ref` 语料一跑就抓到
   （期望绿、实际红）。**新加的判据会照亮老代码里一直存在但从未被触发的耦合。**
2. **判据的顺序是语义的一部分**：`仓@ref:路径:行` 与 `ref:路径:行` 前缀重叠，
   谁先扫描决定了「这一串到底是什么」。这不是实现细节，是契约 —— 所以写进了注释。
3. **fail-closed 要有出口**：要求 2 让缺兄弟仓判红（对），但在非标准布局里这会让整份台账恒红。
   加 `ZH_CLOUD_ROOT` 是给「正确的红」一个可解的口子，而不是把红放宽成绿 ——
   两者的区别在于：口子没指对时**仍然红**。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `--selftest` | `与期望不符的判据 = 0 条`（含新增 5 条跨仓语料） |
| 139 份 FL 台账新老对照 | 失项数有变 **0 份** |
| 真数据 5 种形态 | 跨仓绿 / 去仓名红 / 缺仓红 / 越界红 / `@ref` 绿 |
| 本轮 6 份新台账 | 各 `失项 0 条` |
| `python3 -c "ast.parse(...)"` | 语法 OK |
