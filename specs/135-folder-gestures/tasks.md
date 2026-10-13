# 135 台账

## T1 FolderPage 文件夹行

- `Dismissible`（startToEnd 左滑，confirmDismiss → confirmAndDisbandFolder）。
- `GestureDetector.onSecondaryTapDown` 弹右键菜单。
- tooltip 统一为「解散文件夹」。
- sidebar 长按已有，不重复。

## 过程教训

- Dismissible 与 ListTile 共用同一个 ValueKey ⇒ tap miss；移除 ListTile 的 key。
- icon shape 变更会让 folder_disband_entry_test 的 byIcon 断言红。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format | 0 changed |
| 全量 | `+2051 ~26 -1`（唯一红 #569 存量） |
