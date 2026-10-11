# 规格：侧栏标签「桌面右键」菜单（矩阵 #21 面 ⑥ 的最后一半）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#329（留言 12824「本单不关：桌面右键半面（`:94`）仍未做」）
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径以 zh-cloud-docs `origin/develop` 为准）：
  `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md`
  - `:94`「右键单击某个标签，会出现「置顶」「编辑」和「删除」等选项，点击「编辑」选项，即可进入「标签编辑」页面。」
  - `:79`「在侧边栏左滑某个标签，会出现「置顶」「编辑」和「删除」3个选项。」（同一轮顺带补齐，见下）

## 缺口（改动前，基准 `origin/develop@d2d96bdfb254`）

- 侧栏标签行没有任何次键处理：`git grep -c "onSecondaryTap" d2d96bdfb254 -- lib/features/shell/sidebar.dart` ⇒ 0
  （正向对照：`task_row_host.dart` 与 `kanban_view.dart` 各 1 命中 ⇒ 判据非恒假）。
- 左滑动作表只有「置顶」一项：`git grep -c "sidebar-tag-action-edit" d2d96bdfb254 -- lib` ⇒ 0。
- specs/082 的裁定「动作表只放置顶、编辑/删除放进来是假档」在当时成立（两项只会跳转）；
  本轮把编辑/删除提成共享函数后，两项**就地可完成**，裁定随之更新为三项。

## 契约

1. **三个动作全部真实现、两处入口共用一份**：`tag_actions.dart` 新增
   `promptEditTag`（编辑对话框 + `TagRepository.update`）、`confirmAndDeleteTag`
   （确认框 + `TagRepository.delete`，直接子标签 reparent 到顶层——语义由既有同步测试钉住）、
   `promptTagFields`（名称/颜色/父标签弹窗本体，TagPage 新建/编辑同源）。TagPage 的
   `_edit`/`_delete` 改调共享函数，行为零变化。
2. **右键载体**：`showTagContextMenu(context, ref, tag, globalPosition)` 用
   `showMenu` 在光标处弹位置菜单，三项 key `sidebar-tag-menu-pin/edit/delete`；
   与任务行（`task_row_host.dart`）、看板卡片（`kanban_view.dart`）同一写法。
   「置顶」就地切换（复用 `setPinned`）；失败时菜单已关、SnackBar
   「置顶失败：…，标签列表仍是原来的」——与左滑表内错误**就地可见**同一口径，载体不同。
3. **手势位置**：`GestureDetector.onSecondaryTapDown` 包在 `Semantics` **外层**
   （`_TagRow` 根部）。包在内层会把读屏节点形状改掉（首轮实测：`focus`/`isFocusable`
   从合并节点上消失，`sidebar_tag_pin_test` 的语义断言红）；触屏不发出次键，
   无需 desktopMode 门。
4. **左滑表补「编辑」「删除」**（key `sidebar-tag-action-edit/delete`）：先关表再弹
   对话框/确认框；「置顶」保留表内就地错误显示不变。
5. **不做的事**：右键菜单不放「重命名/层级」之类嘀嗒没写的项；TagPage 既有入口不动；
   任务行右键（#331）不在本轮。
6. **本端与嘀嗒的差别记法**：嘀嗒「点击编辑即进入标签编辑页面」——本端编辑面是
   与 TagPage 同一份的对话框（可保存、可取消），矩阵说明格写「编辑打开编辑对话框」，
   **不写**「进入页面」。

## 红测（先写后实现，基线 `d2d96bdfb254` 上 5 条全红）

`test/features/shell/sidebar_tag_rightclick_test.dart`：
1. 右键标签行弹出三项菜单（三个 key 各 1）；
2. 菜单「编辑」打开「编辑标签」对话框（`tag-parent-picker` 在场），改名保存后侧栏行更新、旧名消失；
3. 菜单「删除」走确认框：取消行还在，确认后行消失；
4. 菜单「置顶」失败时 SnackBar「置顶失败」可见且标签行还在；
5. 左滑动作表含「编辑」「删除」三个 key。

测试手势：`createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton)`
+ `addPointer/moveTo/down/up`（照 `task_focus_entry_test.dart` 的
`_openDesktopContextMenu`）；同一用例右键多次时**先 `removePointer` 再发起下一次**
（MouseTracker 断言 `PointerAddedEvent/PointerRemovedEvent` 必须配对）。夹具需要
`Scaffold` 承接 SnackBar（裸 `Material` 下 `_scaffolds.isNotEmpty` 断言炸）。

## 反向探针（跑在 commit 之后的字节上，变异前 cp 备份、还原后 `cmp -s`）

- P1 删掉右键菜单「编辑」项 ⇒ 用例 1、2 红（菜单缺项 + 编辑不可达）；
- P2 摘掉 `onSecondaryTapDown` 包裹 ⇒ 右键 4 条全红、左滑用例仍绿（归因到右键通道）；
- P3 删掉左滑表「删除」项 ⇒ 用例 5 红（只红这一条）。
