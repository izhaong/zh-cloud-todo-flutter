# 128 台账

## T1 仓储

- `TaskWorkspacePreference.quadrantOrder`（List q1..q4，valueJson 编解码
  对称，非法排列读侧降级默认）；`saveQuadrantOrder(sourceKey, order)`：
  四元排列白名单校验（ArgumentError）。

## T2 视图

- `eisenhower_view.dart`：`quadrantOrder`/`onQuadrantOrderChanged` 参数；
  2×2 按 `widget.quadrantOrder` 铺（take(2)/skip(2)，palette 按 quadrant 现算）；
  `_QuadrantTile.onOrderSwap`（desktop 拖头换位：外层
  `DragTarget<Quadrant>` + 象限头 `Draggable<Quadrant>`）与
  `onOrderMove`/`orderedPosition`（mobile「…」上移/下移，边界禁用）；
  排序菜单升级 `PopupMenuButton<Object>`（int=上移下移、TaskSort=排序档）。

## T3 页面

- `tasks_by_list_page.dart`：`_quadrantOrder` 状态 + restore（非法排列
  降级）+ `_changeQuadrantOrder`（失败回退排列 + 可见 SnackBar，
  ArgumentError 单独提示）。

## T4 用例（test/features/task/quadrant_order_test.dart，7 条）

- widget 5：默认排列现状锁 / 排列驱动渲染 / 拖头换位回调 / 上移下移换位
  + 边界禁用 / 无回调无入口。
- 仓储 1：非法排列被拒 + 合法落库回读。
- 页面 1：拖换后偏好落库。

## T5 探针（各自红后还原）

- PI orderSwapWrap 摘掉（swap=null）⇒ 2 红（拖头回调 + 无回调入口相关）。
- PK 上移边界禁用摘掉（enabled: true）⇒ 1 红。
- （PJ 探针无效已废弃：无回调时整个菜单本就不渲染。）

## 测试基础设施教训

- 多轮 python 行级编辑失败于缩进/字符串界定，最终以「脚本文件 + 行索引 +
  无三引号」方式落刀——大文件多处插入时应优先整段读取后重写。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +7（2 探针各自红后还原） |
| 全量 | `+2014 ~26 -1`（基线 `+2007 ~26 -1` + 本切片 7；唯一红 #569 存量） |

## 附带修复（组合运行暴露的真缺陷）

三文件连跑时 quadrant_task_sort 页面级用例复现失败：`_restoreViewPreference`
的在途回读会把用户刚选的排序档覆盖回去——`_changeQuadrantTaskSort` /
`_changeQuadrantOrder` 缺 `_viewRestoreRevision` 守卫（同 `_changeTimelineZoom`
先例）。已补 revision 守卫（含 ArgumentError/catch 两分支），组合运行转稳定全绿。
单独跑不复现属时序差，非 flake。
