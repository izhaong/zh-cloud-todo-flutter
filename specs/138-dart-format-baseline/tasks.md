# 138 台账

## T1 复读

- [x] 欠债规模：`dart format --output=none --set-exit-if-changed lib test` ⇒ 42 文件
      （lib 13 + test 29）；FL #430 原记 11 个，随 Dart 3.12 tall-style 变大。
- [x] 该门禁无自动化执行：CI / Jenkinsfile / git hooks 均无 `dart format` 调用。
- [x] 原因确认：Dart 3.12 格式化器把多行构造参数重新合到一行（示例见 lib/app.dart
      的 `labelStyle: TextStyle(fontSize: 13, color: ...)`）。

## T2 执行

- [x] `dart format lib test` ⇒ `Formatted 482 files (42 changed)`。
- [x] 无手工改动、无 `--line-length` 等自定义参数（用仓库默认）。

## T3 验证（三重）

| 门 | 改前 | 改后 |
| --- | --- | --- |
| `flutter analyze` | 0 issue | `No issues found!` |
| `dart format --set-exit-if-changed lib test` | `rc=1`（42 changed） | `rc=0` |
| 全量（exclude golden/performance） | `+2075 ~26` 0 失败 | `+2075 ~26` 0 失败 |
| `flutter test --tags golden` | 9 过（未单独量，但改前为绿） | `+9 All tests passed!`，未重录基线 |

### 语义中性证明（关键）

逐文件比对 `HEAD:<file>` 与格式化后内容的 token 流，忽略空白与逗号：

```
files: 42 | differing after ignoring whitespace+commas: 0
```

⇒ 42 个文件**全部**只有空白/换行/尾逗号的差异，没有任何标识符、字面量或结构变化。
这也是「golden 无需重录」的底气。

## 教训

- **清单会随工具链漂移而变大**：同一棵树，SDK 从旧版升到 Dart 3.12 后欠债
  11 → 42。所以「存量欠债」类单子要在处理时**现读**规模，不能沿用旧读数。
- **先问「这条门禁有没有人跑」**：本条红着不会拦任何 PR（CI/钩子都不跑它），
  与「会拦 PR 的红」优先级不同。清理它主要是省掉每轮的自查噪声。
- 清理批量格式化必须出「语义中性」证明：只看 `git diff` 会觉得 653/742 行变动很吓人，
  逐文件 token 比对才能一句话说清「0 语义差异」。
