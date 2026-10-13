# 135 · 文件夹行左滑/右键解散入口 + 文案统一（矩阵 #18 残面）

## 背景

嘀嗒《01-用文件夹管理任务.md》:28/:30——
「解散文件夹」（:28 标题）+「在移动端可通过左滑、长按的方式，解散文件夹。
在桌面端可通过右键，解散文件夹。」（:30）。

specs/126 已闭合面①④（FolderPage 可达 + 拖清单建文件夹）；本切片补
FolderPage 文件夹行的左滑与右键入口 + tooltip 文案统一。

## 内容

- FolderPage 文件夹行套 `Dismissible`（startToEnd 左滑 → confirmDismiss
  → confirmAndDisbandFolder）；`GestureDetector.onSecondaryTapDown` 弹
  右键菜单（key `folder-context-disband`）→ confirmAndDisbandFolder。
- tooltip 统一为「解散文件夹」。
- sidebar 长按已有（specs/037/126），不重复。
