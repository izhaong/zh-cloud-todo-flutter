# Todo 关联主任务与父任务跳转规格

> 对照矩阵：`zh-cloud-docs/todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 第 23 行「多级任务」缺项 ②
> 帮助中心：`zh-cloud-docs/todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/08-如何管理海量任务/06-多级任务.md`

## 目标

把嘀嗒《多级任务》里「关联主任务」这一面从**只有批量模式**补成**单个任务也能用**，
并补上「子任务详情里点主任务标题跳主任务详情」。术语照抄帮助中心，不自创同义词。

## 可验收行为

- FR-1 任务详情「更多任务操作」（`...`）里有「关联主任务」，嵌入态、窄屏全屏页与宽屏页三处入口一致。
- FR-2 点开后是「关联主任务」弹层：候选为**同清单**内任务，排除自己与自己的后代（防成环）；
  选中即写 `parentTaskId` 并入队 `task` upsert，落库与 outbox 都要被证明。
- FR-3 已关联时弹层顶部显示「当前主任务：<标题>」，右侧可「取消关联」（✖️），取消后 `parentTaskId` 归零。
- FR-4 子任务详情的**标题上方**显示主任务行，点击打开主任务详情；主任务改名后该行跟着变。
- FR-5 失败（只读清单等）要说出来：给提示、已加载的层级不变、详情面板还在；无候选时给「暂无可关联的主任务」。
- FR-6 弹层在 320px + 1.3 倍字体下自身不溢出，且档位要在**弹层自己的 context** 上自检（它走 rootNavigator）。
- FR-7 读屏能分别找到「主任务：X」独立节点、「关联主任务」菜单项与「取消关联」按钮。

## 取舍与被否方案

- **父任务跳转用 `showTaskDetailSheet`（宽屏右侧抽屉 / 窄屏底部 Sheet）**。
  否掉 `Navigator.push` 一个整页详情：嵌入态下桌面详情只是三栏中的一栏，push 整页会盖住已验收的
  工作区表面；否掉在 `TaskDetailPane` 内部自建导航栈：`widget.taskId` 被加载链路（`_bootstrap`、
  `didUpdateWidget`、`watchById`、`_isCurrentTask`）当唯一事实源，塞第二套「当前 id」等于重写已验收面板。
  `showTaskDetailSheet` 是看板/时间线/日历/四象限四个视图点开详情用的**既有**表面，复用它零新增布局。
- **失败时先关弹层再给 SnackBar**。本仓所有 Sheet 都是 `SafeArea` 直挂、内部不放 `Scaffold`，
  而 `ScaffoldMessenger` 的提示会渲染在**下层** `Scaffold` 上、被模态屏障挡住；
  与其为一条提示给弹层套一层 `Scaffold`（本仓无此先例），沿用「批量操作失败 → 关闭选择器 + 顶部提示」的既有回路。
- **候选只按「同清单 + 非自己 + 非后代」过滤**，不在 UI 侧预筛五级上限与只读清单：
  这两项规则的唯一事实源是 `TaskRepository.reparent`，UI 复制一遍就会与它漂移，改为把它的报错如实转成提示。
- 新增界面自带「读屏独立节点」用 `Semantics(container: true, label:, onTap:) + ExcludeSemantics(child:)`：
  M3 `IconButton` 只把 `tooltip` 交给 `Tooltip`（气泡出现时才有 label），按钮节点本身无 label
  （`/Users/zhonghao/development/flutter/packages/flutter/lib/src/material/icon_button.dart:838` 只给 `Semantics(button:, enabled:)`），所以「取消关联」必须显式给节点。
  反向探针：去掉这层包装，读屏用例当场红。

## 验证边界

- 证据只来自 `flutter test` 的 14 条用例（`test/features/task/link_parent_task_test.dart`）与十一组反向探针
  （摘菜单项 / 摘主任务行 / 摘后代排除 / 摘弹层存活判断，逐个必须红，恢复后 `cmp -s` 逐字节一致）。
- 桌面/手机/网页三端同一套 Flutter 代码，但**真机点击与读屏软件实测未做**：本机无第二台可登录 test 的设备。
- 清单页「展开/收起子任务」不属于本规格（它改可见列表布局 ⇒ 需先申请重录 9 张黄金基线）。
- 已知存量欠债，不在本规格内修：嵌入态详情操作头 `_buildEmbedded` 的 `Row` 在 320px + 1.3 倍字体下
  **已**溢出 36px（本轮实测定位，弹层出现之前就能拍到）。FR-6 因此只要求「弹层自身零新增溢出」，
  并在用例里先把这条既有异常吃掉记账，另开治理 Issue。
