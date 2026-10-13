# 规格：文件夹管理可达 + 拖动清单建文件夹（FL #627 / FL #355，矩阵 #18 面①④）

## 判据源

`zh-cloud-docs` 镜像 `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/01-用文件夹管理任务.md`：

- 「随着清单数量越来越多，可以使用文件夹来整理你的清单。」——要求「把清单放进文件夹」这条能力用户走得到。
- 「# 创建文件夹」一节 `::::tab [mobile]` 下「方式一：拖动清单到另一清单上方，松手后，在弹窗内输入名称即可创建文件夹。」——本轮面④ 的形状：起拖→落点→弹窗命名→建夹。原文把它挂在移动端 tab 下，所以只在桌面悬停出现的形状不算实现。
- 「# 解散文件夹」一节「在移动端可通过左滑、长按的方式，解散文件夹。在桌面端可通过右键，解散文件夹。」——本端已随 FL #312 落地（见矩阵 #18 行第 71 轮追加），本轮不动。

## 现状与缺口（复算命令随句）

- `FolderPage` 在 `lib` 内的引用行数：`git -C zh-cloud-todo-flutter grep -c "FolderPage" origin/develop -- lib` 求和 = 5，去掉自身定义 2 行与注释 2 行，唯一的 push 在 `list_page.dart`，而 `ListPage` 的挂载点在 `lib` 内为 0（`git -C zh-cloud-todo-flutter grep -c "ListPage" origin/develop -- lib/app.dart` 无输出）⇒ 面①「建·改·删整页不可达」。
- 侧栏清单行没有拖出源：`git -C zh-cloud-todo-flutter grep -c "LongPressDraggable\\|Draggable<" origin/develop -- lib/features/shell/sidebar.dart` 无输出 ⇒ 面④ 缺。

## 裁定

1. **入口落在清单行的动作表**（`sidebar-list-action-folders` → push `FolderPage`），不落侧栏「清单」标题行。理由：标题行已有「新建清单」+「智能清单管理」两颗，第三颗是默认渲染的新增像素，宽屏/平板/手机三档黄金基线都要重录；动作表本身已经可达（长按与左滑都起得来），入口放这里等于零新增默认视觉。复算：`git -C zh-cloud-todo-flutter grep -c "sidebar-list-action-" origin/develop -- lib/features/list/list_actions.dart` = 6（本轮加档前为 5）。
2. **手柄出现条件 = 悬停 或 视口宽度 < 700**，不读 `defaultTargetPlatform`。理由：`flutter test` 里 `defaultTargetPlatform` 默认是 android，按平台判会写出一堆需要手工摆 debug 变量的用例；而真正决定「有没有悬停可用」的是视口宽度（手机、分屏、窄 web 窗口都没有悬停）。
3. **手柄挂在行尾（`_SidebarRow.trailing`），不放进 `Dismissible` 的横向滑轨道内**。理由：既有「左滑唤出置顶/编辑/删除」是矩阵 #19 那一行已验收的能力，拖拽若吃横向手势就是倒退；手柄的点按由自己吞掉，不会顺带把侧栏切到这条清单。
4. **拖拽载荷另立类型 `SidebarListMergeDrag`**，不复用任务拖放的 `Draggable<TodoTask>`。理由：`DragTarget` 按类型接单，两条通道各走各的才不会让「把任务移入清单」与「把清单并进文件夹」互相误接。
5. **落点必须是另一条清单**：`onWillAcceptWithDetails` 以 `details.data.listId != list.id` 接单。拖到自己那行不建夹。
6. **目标清单原本已在文件夹内 ⇒ 两条一起搬进新夹**（口径钉在用例里）。理由：原文要的是「创建文件夹」并把这两条放进去，没有「目标留在原夹、只搬拖出那条」这半句；反过来读会让新夹里只有一条清单，与「用文件夹整理清单」不符。
7. **失败不留半态**：建夹成功但搬清单抛错时调用 `FolderRepository.delete` 回滚（该函数会顺带清空夹内清单的归属），并给当场可见的提示。复算：`git -C zh-cloud-todo-flutter grep -c "建文件夹失败" origin/develop -- lib/features/shell/sidebar_list_folder_merge.dart`（合并后应为 2 处文案）。

## 探针

| 编号 | 做法 | 结果 |
| --- | --- | --- |
| P1 | 把 `sidebar.dart` 与 `list_actions.dart` 暂换回 `origin/develop` 的字节，跑 `test/features/shell/sidebar_folder_management_test.dart` 与 `test/features/shell/sidebar_list_drag_create_folder_test.dart` | 12 项里 11 项红（`[E]` 行 11），唯一仍绿的是「宽屏非悬停不出现拖拽手柄」——它量的是「新视觉没漏进默认渲染」，在旧实现上本来就该绿 |
| P2 | 还原被换下的两份文件后 `cmp -s` 逐字节比对 | 两份都 `restored ok`，还原没有覆盖掉本轮实现 |
| P3 | 反向对照既有溢出用例：`flutter test test/features/list/list_share_entry_test.dart` | 加档后该用例先红（`A RenderFlex overflowed by 17 pixels on the bottom`），据此把动作表改成 `isScrollControlled` + `SingleChildScrollView`，而不是去放宽那条断言 |

## 交叉验证

`cursor-agent -p --trust`（提示词见 `tasks.md`）裁 Q1 选「小手柄单独起拖」，理由是清单行的长按与左滑都已被占用、标签分节那次「把长按让给拖拽」的做法在本行不许照搬；裁 Q2 选「入口进动作表，不新增标题行按钮」。Q1 与 Q2 的裁决都照此采纳。未采纳的是它顺带建议的「给读屏补自定义动作」——本轮只给手柄挂 `Semantics(label:)`，`CustomSemanticsAction` 需要动 `flutter/services` 导出且既有先例里 material 不导出该类，另轮处理（记在下文遗留）。

## 门禁读数

基线（本轮开工前的 develop）：`bash tool/gate_counts.sh <日志>` = `last=1978/26/5 max=1978/26/5 complete=yes`，`flutter analyze` = `No issues found!`。
本轮读数见 `tasks.md` 末尾，须满足：新增用例数 = 12，失败数不高于基线那 5 项，`analyze` rc=0。

## 遗留（本轮不做，已记账）

- 读屏只能念出手柄标签，念不到「拖」这个动作本身；要给读屏一条等价的「把这条清单并进文件夹」路径需要 `CustomSemanticsAction`。
- `ListPage` 仍是零挂载。面① 不再依赖它，但那一页自己的清单管理语义（智能清单区、上下移动按钮）还挂在那里，与侧栏并存，属于另一笔并轨。
- 智能清单行不参与拖拽建夹：`ListRepository.moveToFolder` 对 `smart:` 前缀抛 `StateError`，本轮由失败回滚路径接住并给可见提示，没有专门放宽或专门拦截。
