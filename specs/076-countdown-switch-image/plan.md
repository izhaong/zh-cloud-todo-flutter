# 计划：倒数纪念日「切换图片」上传背景图

| 层 | 改动 | 位置 |
| --- | --- | --- |
| 出站 | create 与 update 的 payload 各加一条 null-aware 的 `backgroundImage` | `lib/core/api/efficiency_api.dart:932` |
| 界面 | 编辑窗口加「切换图片」按钮，外层 `Semantics(button, label: 切换背景图)` 带 key | `lib/features/countdown/countdown_page.dart:527` |
| 失败面 | 上传抛错写可见原因并保留旧值 | `lib/features/countdown/countdown_page.dart:449` |
| 预览 | 当前背景图用 `Image.network` 画出来，取不到不占位 | `lib/features/countdown/countdown_page.dart:547` |
| 送值 | 保存时把草稿里的背景图交给 create 与 update | `lib/features/countdown/countdown_page.dart:345` |

顺序：先写判据（含失败与取消两条负路径）→ 加 payload 与按钮 → 六道门禁在最终字节各跑一次 → 摘掉发送那一行做反向对照。

风险：给 `CountdownApi` 加参数会波及既有假实现的覆写签名（`test/features/countdown/countdown_manage_test.dart` 的 `_FakeCountdownApi.update` 已同步补参），漏改会让整个 countdown 测试目录以 `loading <file>` 形态判红——那是编译失败不是行为失败。
