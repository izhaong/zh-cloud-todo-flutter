# 规格：清单作用域视图偏好的跨设备键归一（FL #619）

## 判据源（嘀嗒原文逐字，docs 镜像 `origin/develop`）

`todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/08-不同的视图查看任务/01-列表视图.md`：

- `:110-111`「# 视图多端独立配置：你可以为手机端和桌面端分别设置清单视图，不同设备的视图设置互不影响。」
- `:117` / `:126`「进入对应清单 → 「显示设置」 → 「视图跨设备同步」」

## 本轮动的是哪一块

`:110-126` 整面要的是两件事：**能跨设备同步**（开关 ON 那一档）与**能各端独立**（开关 OFF 那一档）。
本轮做的是前一件的地基：`TASK_SORT`/`TASK_GROUP` 这两类"每清单偏好"过去**根本没跨设备同步成功过**——
`sourceKey` 发的是本设备生成的清单 UUID，同步层只对 `task_view` 做 `list:<本地id>` ⇄ `list-server:<serverId>` 归一。
两台设备对同一个服务端清单各写一行，读侧按自己的本地 id 查 ⇒ 对端那行永远对不上。
开关建在这条脏通道上，拨到"开"也是落空的，所以先归一、后开关。

## 需求与裁定

1. **归一放在同步层，仓储的存法一字不改。**
   新增 `lib/core/sync/list_view_preference_scope.dart` 承载"三种类型各自的本地形状"这一件事；
   出站把本地键换成 `list-server:<serverId>`，入站再换回该类型的形状（`task_view` 带 `list:` 前缀，
   `TASK_SORT`/`TASK_GROUP` 用裸 id）。
   复算（数的是同步层两处块里对这个类的调用行数，不写行号以免漂移）：
   `git -C zh-cloud-todo-flutter grep -c "ListViewPreferenceScope" origin/develop -- lib/core/sync/sync_coordinator.dart` ⇒ 7
   （出站块 3 行、入站块 4 行 ⇒ 两处都走同一个类，没有第二份实现）。
2. **键形状不认识 ⇒ 按原样发送，不许当成"清单还没上服务端"。**
   `task_view` 的历史遗留键 `tasks_by_list` 没有 `list:` 前缀，它不是某台设备的清单 id；
   若误判，出站会整条丢掉这条偏好（比发脏键更糟：偏好再也不上传）。
   `localListId` 对它返回 `null`，钉住它的用例是「形状不认识的键按原样发送…」。
3. **清单还没上服务端时本轮不发，但留在出箱里等下一次。**
   这里沿用 `task_view` 既有口径：`_resolvePayloadRefs` 返回 null 的含义是"这一轮延后、下次再试"，
   不是"丢弃"。⇒ 新用例只断"这一轮 payload 里没有它"，不断"队里没了它"。
4. **与设备无关的键一律不动。** 收集箱在两类里都是固定字面量 `inbox`（`task_view` 侧是 `list:inbox`），
   本来两端撞同一行；`smart:*` 之类的稳定字面量同理。
5. **作用域只有这三类。** `WEEK_START`/`TASK_SWIPE`/`TASK_CAPTURE`/时区/侧栏都不是"清单视图"，
   `quadrant_view`/`calendar_view` 用的是全局键（`task_quadrant`/`task_calendar`），看板列宽在另一张表
   `TodoBoardPreferences`——都归另一条线管。钉住它的用例是「作用域集合只含这三类…」（含 5 个越界类型）。

## 不在本轮做的两件事（各自有去处）

- **开关本身**（`:117` 那句「视图跨设备同步」）：另起一轮。裁定要点是"开关只留本机、不入 outbox"——
  服务端唯一键没有设备维度，把 OFF 同步出去会让它变成账号级的一位，两端的开关就不再独立。
- **服务端存量脏键**：已经积累的那些"本地 UUID 键"的行不会自动归一。本轮**不写迁移 SQL**，
  理由：那些行在任何设备的读取侧都查不到（读取按自己的本地 id），是无消费者的死行；
  改法生效后各端各自重写一次即落到规范键上。判据：该仓储里 `TASK_SORT` 只出现在两处——
  常量 `_sourceType` 与查询条件 `preference.sourceType.equals(_sourceType)`，读取路径没有任何"旧 UUID 行"兜底
  （复算 `git -C zh-cloud-todo-flutter grep -c "TASK_SORT" origin/develop -- lib/state/repositories/task_sort_preference_repository.dart` ⇒ 2）。

## 交叉验证（cursor-agent，10251 字节，结尾 `CROSSCHECK: DONE`）

采纳：判 A（纯本地开关，服务端零改动）；`TASK_SORT`/`TASK_GROUP` **不该被那个开关管**
（原文的对象是「清单视图」，排序/分组是同一篇里别的标题）；黄金基线只画收起态
（9 张的名字与流程它逐张核过 ⇒ 放进关闭的菜单/对话框 = 0 张重录）；
`_resolvePayloadRefs` 的 null 是"延后"不是"丢弃"（本台账第 3 条就是照这条写的）。

它另给两条我没看到的事实，我都对着字节复验过才写进 Issue #619：
① 收集箱那份排序/分组**是**同步了的（两端都撞字面量 `inbox`）；
② 智能清单页面把 `_selectedListId` 原样传成 null（`tasks_by_list_page.dart:798`
`await repository?.get(_selectedListId)`）⇒ 落到同一个 `inbox` 行，
即"智能清单的排序档位现在写进了收集箱那一行"。这两条是独立缺陷，本轮不改，已并进 #619。

它建议"本轮不要顺手改 `TASK_SORT`/`TASK_GROUP` 的归一"——**不采纳**：
归一是开关的前置（开关拨到 ON 要走的就是这条通道），而且它已经有独立 Issue #619 与独立 PR，
不是塞进开关那一笔里改。
