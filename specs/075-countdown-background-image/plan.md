# 计划：倒数纪念日消费背景图

| 层 | 改动 | 位置 |
| --- | --- | --- |
| 界面 | 行体外套 `Stack(fit: StackFit.passthrough)`，先取该条记录自己的 `backgroundImage`，非空才铺 `Image.network` | `lib/features/countdown/countdown_page.dart:89`（取值）、`lib/features/countdown/countdown_page.dart:96`（分支） |
| 读屏 | `semanticLabel` 写成「<标题> 的背景图」 | `lib/features/countdown/countdown_page.dart:100` |
| 失败面 | `errorBuilder` 收成空尺寸，保住同层标题与天数 | `lib/features/countdown/countdown_page.dart:103` |

顺序：写判据用例（有图必须画、空值不许冒名、取不到不吞数据、窄屏放大字号不炸）→ 加 `Stack` 与图分支 → 六道门禁在最终字节各跑一次 → 摘掉那条 `if` 分支做反向对照。

风险：`StackFit` 选错会改掉既有行高，`test/visual` 的基线会红 ⇒ 门禁第 4 道要看是否仍然 `+9`。
