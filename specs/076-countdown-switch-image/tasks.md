# 任务台账：倒数纪念日「切换图片」上传背景图（FL Issue #445 上传面）

基准：分支 `feat/445-countdown-switch-image`，起点 FL `origin/develop`。矩阵行：zh-cloud-docs 对照矩阵第 49 行 ③ 面。

## 已完成

- [x] 编辑窗口有「切换图片」入口，key 与读屏语义在同一个节点：`lib/features/countdown/countdown_page.dart:527`
- [x] 上传失败给可见原因且保留旧背景图：`lib/features/countdown/countdown_page.dart:449`
- [x] 当前背景图预览：`lib/features/countdown/countdown_page.dart:547`
- [x] 保存时草稿值送进写库调用：`lib/features/countdown/countdown_page.dart:345`
- [x] 出站 payload 带这一键（null-aware，不写空值）：`lib/core/api/efficiency_api.dart:932`

## 判据

`test/features/countdown/countdown_switch_image_test.dart` 现读：送值与上传成功 107、失败保留旧值 150、取消不改不报错 183、读屏语义 204、窄屏与 1.3 倍字号 220。

## 六道门禁（最终字节上各跑一次）

| 序 | 命令 | 现读 |
| --- | --- | --- |
| 1 | `git diff --check` | rc=0、无输出 |
| 2 | `dart format --output=none --set-exit-if-changed` 后接本轮 4 个显式文件 | rc=0、`Formatted 4 files (0 changed)` |
| 3 | `flutter analyze` | rc=0、`No issues found!` |
| 4 | `flutter test --tags golden` | rc=0、`+9: All tests passed!`，`test/goldens` 无改动（基线未重录） |
| 5 | `flutter test --exclude-tags 'golden   performance' --concurrency=1` | rc=0、`+1347 ~26: All tests passed!`（复算请用 shell 原文 "golden \|\| performance"，表格里那对竖线会被当单元格分隔符） |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | rc=0、`✓ Built build/web` |

## 四件套

- 窄屏与字号：320×640 加 1.3 倍字号下入口 rect 全在视口内且点得动，判据 `test/features/countdown/countdown_switch_image_test.dart:220`
- 失败保留已加载数据：上传抛错时旧背景图仍在、保存仍送旧值，判据 `test/features/countdown/countdown_switch_image_test.dart:150`
- 独立读屏语义：`lib/features/countdown/countdown_page.dart:527` 那个节点量 `label` 含「切换背景图」且 `flagsCollection.isButton` 为真，判据 `test/features/countdown/countdown_switch_image_test.dart:204`
- 过期响应不覆盖新响应：本面是「选一次传一次」的同步写，没有并发回包覆盖路径，未立判据

## 归因（不是本轮引入的缺陷）

窄屏用例里另有一行打印 `NARROW_BASELINE_EXCEPTION`：在 320 宽与 1.3 倍字号下，编辑器**未点本次新入口之前**就现读到 `A RenderFlex overflowed by 44 pixels on the right.` ⇒ 溢出源是既有「目标日期」那一行（同 FL Issue #279 一族），本轮没顺手改它，只把新入口自己的 rect 判进视口。

## 复核与合并前置

`claude -p` 通道本轮未取到结论（输出 0 字节）⇒ 不声称复核通过；合并依据是上面六道门禁、判据用例与合并试算。
