# 任务台账：倒数纪念日消费背景图（FL Issue #445 消费面）

基准：分支 `feat/445-countdown-background-image`，起点 FL `origin/develop`。矩阵行：zh-cloud-docs 对照矩阵第 49 行 ③ 面。

## 已完成

- [x] 行体套 `Stack`，非空 `backgroundImage` 才铺网络图。锚点 `lib/features/countdown/countdown_page.dart:89`（取值）与 `lib/features/countdown/countdown_page.dart:96`（分支）
- [x] 读屏标签「<标题> 的背景图」。锚点 `lib/features/countdown/countdown_page.dart:100`
- [x] 取图失败经 `errorBuilder` 收敛、不吞同层文字。锚点 `lib/features/countdown/countdown_page.dart:103`
- [x] 判据用例都在 `test/features/countdown/countdown_background_image_test.dart`：有图必须画 `test/features/countdown/countdown_background_image_test.dart:61`，空值不许冒名 `test/features/countdown/countdown_background_image_test.dart:85`，取不到不吞数据 `test/features/countdown/countdown_background_image_test.dart:92`，窄屏放大字号 `test/features/countdown/countdown_background_image_test.dart:111`

## 反向对照

摘掉 `lib/features/countdown/countdown_page.dart:96` 那条 `if` 分支后现跑 `flutter test test/features/countdown/countdown_background_image_test.dart --concurrency=1` 读回 `+2 -2`，红的是「带背景图的卡片渲染那张网络图」与窄屏那条（失败原因写着「服务端给了 backgroundImage 却不画 = 这列是摆设」）；还原后同一条命令读回 `+4: All tests passed!`。「取不到不吞数据」那条在没有图分支时也会绿，它判的是文字保留而不是图存在，别把它当图存在的证据。

## 四件套

- 窄屏与字号：320×640 加 1.3 倍字号下背景图节点在、行宽不超 320 且不抛异常，判据 `test/features/countdown/countdown_background_image_test.dart:111`
- 失败保留已加载数据：取图失败仍见标题与天数，判据 `test/features/countdown/countdown_background_image_test.dart:92`
- 独立读屏语义：`semanticLabel` 已给（锚点 `lib/features/countdown/countdown_page.dart:100`），但本轮没写量读屏节点的用例 ⇒ 这一件按无证据处理，不得声称已过
- 过期响应不覆盖新响应：本面只消费列表已有的 DTO、不引入异步回包，未立判据

## 六道门禁（最终字节上各跑一次）

| 序 | 命令 | 现读 |
| --- | --- | --- |
| 1 | `git diff --check` | rc=0、无输出 |
| 2 | `dart format --output=none --set-exit-if-changed` 后接本轮 2 个显式文件 | rc=0、`Formatted 2 files (0 changed)` |
| 3 | `flutter analyze` | rc=0、`No issues found!` |
| 4 | `flutter test --tags golden` | rc=0、`+9: All tests passed!`，`test/goldens` 无改动（基线未重录） |
| 5 | `flutter test --exclude-tags 'golden   performance' --concurrency=1` | rc=0、`+1341 ~26: All tests passed!`；复算请用 shell 原文 "golden || performance"，表格里那对竖线会被当单元格分隔符 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0、`✓ Built build/web` |

## 复核与合并前置

只读复核（`claude -p`）本轮未取到结论：该通道近期持续 0 字节，属故障而非「无意见」⇒ 不声称复核通过，只报门禁实测与反向对照。合并试算见 PR 正文。

## 遗留

上传面（嘀嗒「切换图片 / 上传背景图」）仍缺，判据与候选修法写在 FL Issue #445；矩阵第 49 行因此仍「部分」。
