# Todo 侧栏清单管理入口（重命名与删除可达）

状态：进行中（2026-09-23 立项）
来源：嘀嗒《01-任务/08-如何管理海量任务/02-用清单管理任务》「编辑清单」；对照矩阵 #19、#18。

## 现状（实地核对，2026-09-23）
`ListRepository.rename`（`lib/state/repositories/list_repository.dart:95`）、`delete` 与
`ListEditorSheet(existing:)`（`lib/features/list/list_editor_sheet.dart:13`）都已实现且有测试，
但**没有任何可达入口**：`ListPage` 在 `lib/` 内零引用（`grep -rn "ListPage" lib` 除自身声明外只命中
`TasksByListPage`；`app.dart:33` 路由表只有 `/login` 与 `/`），而
`ListEditorSheet(existing:)` 的唯一传参方就是 `list_page.dart:32`，侧栏只以无参构造调用它
（`sidebar.dart:897` 的 `_CreateListSheet`，仅新建）。
净效果：**用户创建的清单改不了名、删不掉**；文件夹管理（`FolderPage` 只被 `list_page.dart:103` push）同样不可达。

## 需求
- FR-001 侧栏的每个清单行支持长按打开动作表，条目用嘀嗒术语「编辑」「删除」。
- FR-002 「编辑」复用 `ListEditorSheet(existing: list)`，改名后落库并即时反映在侧栏；失败时保留原清单与列表。
- FR-003 「删除」先二次确认；清单仍有未完成任务时按既有 `ListPage` 口径拦截提示（ `"名称" 仍有 N 项未完成。` ），
  确认后才 `delete`；取消不得产生任何写入。
- FR-004 动作表两个条目各自具备独立可读屏语义；320px 宽 + 1.3 倍字体下无溢出。
- FR-005 智能清单与收集箱不出现该入口（`watchAll` 已排除 `smart:` 与 `inbox`，不得绕过这层判断）。

## 边界（不在本切片）
- 「置顶」不做：`todo_list` 无 pinned 字段、`ListRepository` 无对应写方法 —— 属后端契约缺口，
  须先在 `zh-cloud-service` 加字段与端点，不得由 Flutter 侧本地表绕过。
- 文件夹管理入口（#18）不做：`FolderPage` 需要可见的「管理」入口，那会在侧栏分组标题上加图标，
  可能改动已批准的黄金图基线 —— 按目标约定**重录基线先申请**，故本切片只做无布局变化的长按手势。
- 「左滑」是嘀嗒移动端的主手势（左滑出「置顶 / 编辑 / 删除」）。本切片用**不改布局**的长按先交付能力：
  滑动动作条要改行的命中区与视觉，可能触发黄金图变化，按约定先申请重录再做。
- 键盘/桌面的等价入口（聚焦后按键或右键菜单）本切片未做。`_SidebarRow` 本身可聚焦，
  但长按在键鼠下不可达 —— 这是本切片的已知可及性缺口，登记于此，不得当作已完成。
- 不改后端、不新增接口、不动 `ListPage` 自身的行内 hover 交互。
