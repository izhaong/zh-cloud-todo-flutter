# 138 · `dart format` 存量欠债清零（原 FL #430）

## 背景

FL #430 记录：`dart format --output=none --set-exit-if-changed lib test` 在 develop 上
`rc=1`、11 个文件未格式化。属存量欠债，不是某一轮引入。

本轮复读（2026-10-16，`origin/develop` tip `2e00505c`）已扩大到 **42 个文件**
（lib 13 + test 29）—— Dart 3.12 的格式化器（Flutter 3.44.8 自带）改用新的
「tall style」排版，对既有代码的换行判定更紧，于是欠债随 SDK 升级自然变大。

## 关键读数（先量后改）

- **该门禁目前没有任何自动化在执行**：`.github/workflows/*.yml`（CI 只跑
  `flutter analyze` + `flutter test`）、`Jenkinsfile`、以及本仓均无 `dart format`
  调用，也没有 git hooks。所以它是一条「约定门禁」，红着不会拦任何东西，
  但会让每个按约定自查的人每次都看到 42 个文件 —— 判定成本转嫁给每轮。
- 格式化器只动空白与尾逗号：对 42 个文件逐一对 HEAD 与格式化后做 token 流比对
  （忽略空白与逗号）⇒ **0 个文件有语义差异**。
- 全量 `flutter test --exclude-tags "golden || performance"` 前后同为 `+2075 ~26`
  （0 失败）；`--tags golden` 9 张全过、**无需重录基线**。
  即 FL #430 担心的「重跑 golden 前先量基线覆不覆盖那块表面」已有答案：不覆盖差异。

## 内容

- `dart format lib test`（42 个文件），无手工改动。
- 结果：`dart format --output=none --set-exit-if-changed lib test` ⇒ `rc=0`。

## 边界

- 不改任何业务语义；不顺手重构。
- 不把 `dart format` 加进 CI：那会改变门禁强度，属独立决策，本切片只清欠债
  （见下方「后续建议」）。

## 后续建议（未做）

若要让它成为真门禁，最小改法是在 `.github/workflows/ci.yml` 的 analyze 之前加
一步 `dart format --output=none --set-exit-if-changed lib test`。本切片不擅自加，
因为「红着但没人跑」与「会拦 PR」是两种强度，且 Dart 格式化器随 SDK 升级会改判定，
一旦进 CI 可能因 SDK 版本漂移误红。
