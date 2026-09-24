# Todo 倒数纪念日编辑与样式任务

- [x] T001 为 `CountdownApi.update`/`delete` 建立请求契约红绿测试。
- [x] T002 实现编辑对话框（名称、目标日期、样式、显示已过天数）与删除确认，失败保留列表。
- [x] T003 列表消费 `style` 与 `showAge`，消除硬编码底色与负数文案。
- [x] T004 补 320px 与读屏语义 Widget 用例。
- [ ] T005 通过格式、静态分析、全量测试、Web 与 Claude CLI 门禁，并回写矩阵 #49。

## 执行证据

- 2026-09-22：第 0 轮矩阵校对把 #49 的具体缺口从「样式/颜色/图片/备注」收窄为可验证事实 —— `CountdownApi` 只有 `list()`/`create()`，而服务端 `AppTodoCountdownController.java:35/41` 的 `update`/`delete` 端点、`AppTodoCountdownUpdateReqVO` 与 `todo_countdown` 表都已存在，属纯客户端接线断裂。T001 红测先以编译错误准确缺失实现：`Error: The method 'update' isn't defined for the type 'CountdownApi'` 与 `The method 'delete' isn't defined`（`test/countdown_manage_contract_test.dart`）。
- 2026-09-22：T001 GREEN。`update` 发 `PUT /app-api/todo/countdown/update`，载荷用 `expect(request.data, {...})` **精确等值**断言为 `{id,name,targetDate,style,showAge}`，不多发 `backgroundImage`/`sortOrder`/`archived`；`delete` 断言 `DELETE` 且 `queryParameters['id'] == 7`。顺带纠正 `create` 的参数名 `isCountUp` → `showAge`：它本来就在发送 `showAge` 字段，且全仓无任何调用方（旧参数名是死名字），改名零行为变化，`test/efficiency_api_contract_test.dart` 既有断言仍通过。
- 2026-09-22：T002/T003 实现。页面由 `ConsumerWidget` 改为 `ConsumerStatefulWidget`；新建与编辑共用同一个表单体（`_CountdownEditor`），避免两套字段漂移；保存/删除只在 API 成功后 `ref.invalidate(countdownsProvider)`，失败仅提示且不刷新列表。样式取服务端 `AppTodoCountdownBaseVO` 注释的 `1=默认 2=翻页 3=圆环`，三档呈现为互不相同的结构（`CircleAvatar` 方向标记／圆角块带下边框+天数／描边圆环+天数），并消费 `showAge`：过期项开启时显示「已过 N 天」，关闭时只显示目标日期，消除原先可能出现的负数文案。
- 2026-09-22：第一轮 Claude CLI 只读复核（`plan` 模式，仅 `Read`/`Grep`/`Glob`）返回 **`VERDICT: FAIL`**，两条成立结论已按其结论修正：① **FR-006 不成立** —— 320px 用例只设了视口未设 1.3 倍字体，且「删除」语义断言写成 `find.descendant(of: 按钮自身, matching: byTooltip)` 的永真 no-op，编辑入口根本没有语义标签却在用例名里宣称有；② **并发写会造成旧列表覆盖新结果**（`countdownsProvider` 是 `autoDispose` FutureProvider，无请求序号，编辑与删除同时在飞时后到的旧 `list()` 响应会让刚删除的条目复活）。
- 2026-09-22：按上述结论重做。交互改为自建行布局（`InkWell` + `Row`）而非 `ListTile`，原因是实测 `ListTile` 会把 `trailing` 的语义合并进整行节点，导致编辑与删除不再是独立可播报目标 —— 第一版用 `Semantics(label:)` 包整行时，`find.bySemanticsLabel('删除 …')` 命中 0 个，正是该缺陷的复现证据；现两个动作各自是 `Semantics(container+button+label+onTap)` 包 `ExcludeSemantics(IconButton)`（与本仓搜索页读屏标签同一套路）。320px 用例补 `TextScaler.linear(1.3)` 并把断言改为按完整语义标签命中。并发写新增 `_writePending` 单飞闸。
- 2026-09-22：新用例的 RED 有效性已单独验证 —— 把 `setState(() => _writePending = true)` 单行改为 `false`（语法安全的等价撤销）后，「写请求在途时不再放行第二个写」用例立即失败；恢复后 `cmp -s` 确认文件与验证前逐字节一致。故该用例确实依赖这个闸，不是恒真断言。
- 2026-09-22：T004 与全部门禁在最终状态复跑：`git diff --check` 干净；`dart format --output=none --set-exit-if-changed` 对本切片 4 个文件 `Formatted 4 files (0 changed)`；`flutter analyze` `No issues found!`；`flutter test --tags golden` 9/9；全量 `flutter test --exclude-tags 'golden || performance' --concurrency=1` `+723 ~26: All tests passed!`（较 `a1d7733` 基线 712 增加 11 项，即本切片 3 项契约 + 8 项 Widget）；`flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` `✓ Built build/web`。
- 2026-09-22：**不采纳**复核的一条 Minor「默认样式在『已过期 + showAge 关闭』时不显示过期程度」。理由：该分支的副标题已按 FR-004 显示目标日期，行内信息与其它档一致；把方向标记改成数字会让默认档与翻页/圆环档失去区分，反而削弱 FR-003。嘀嗒默认档同样是弱信息行，不显示倒计时数字。
- 2026-09-22：第二轮只读复核返回 **`VERDICT: FAIL`**（同时用探针证实第一轮 5 项修正真实落地：删掉 `_writePending` 闸后新用例立刻失败；行/编辑/删除几何 `16→304 / 208→256 / 256→304`；`11 passed`、`No issues found!`）。逐条处置：
  - **Important 1 采纳并已修**：`CountdownApi.update`/`delete` 未调 `_unwrapData`，HTTP 200 携带 `code!=0` 的业务错误被静默当作成功 —— 用户没有任何失败反馈，直接违反 FR-001/FR-002。先加两条 RED 用例（`Expected: throws <Instance of 'DioException'> … Which: emitted <null>`），再补 `_unwrapData(response.data);` 转绿。原契约 stub 恒返回 `code:0`，所以第一版测试测不出该缺陷，这是测试设计的缺口而非实现漏改的侥幸。
  - **Minor 2 不采纳**（`_writePending` 需 dispose 兜底 / SnackBar 应带 `rootNavigator`）：`messenger` 在 `await` 前捕获、`setState` 已在 `finally` 里用 `mounted` 守卫；且 `_showEditor`/`_confirmDelete` 都先 `await showDialog` 结束才进 `_runWrite`，提示时页面上已无模态层遮挡，不需要 root navigator。
  - **Minor 3 采纳**：`plan.md` 原写「不改页面结构」在改成自建 `Row` 后不成立，已在 `plan.md` 就地更正为「不新增页面与路由」，并记录 `ListTile` 合并 `trailing` 语义这一改动理由。
  - **Minor 5 不采纳**（建议删掉行内编辑按钮，只留整行点击进入编辑）：编辑与删除各自保留独立、可播报的动作入口是 FR-006 的判定内容，减掉一个入口是缩小无障碍面而非改善；整行点击作为额外便利保留。
  - **Minor 8 采纳**：契约用例的路径断言从 `endsWith('/countdown/update')` 收紧为 `expect(request.path, '/app-api/todo/countdown/update')`，使 `/app-api/todo` 前缀本身成为被断言的契约。
  - **Minor 2 附带项采纳**：Widget 用例的假 API 原先抛 `Exception`，而真实失败是 `_unwrapData` 抛的 `DioException`，测的是不存在的失败模型；已改为抛同型 `DioException`。
  - 复核另提的两项属提交动作而非代码缺陷：`pubspec.lock`（本机重解析产物，按约定永不提交）与「024 / 020 / 其余 6 个切片的 `tasks.md` 须拆成独立 PR」，均已记入下方 T005 前置条件。
- 2026-09-22：第三轮只读复核返回 **`VERDICT: FAIL`**，唯一 FAIL 项「`messenger.showSnackBar` 未受 `mounted` 守卫，页面卸载后调用会抛未捕获异步异常，FR-001/FR-002 的失败提示正好消失」——**其机理经实测被推翻，但结论（该加守卫）成立，已按实测理由采纳**。探针做法：把倒数日页挂到可 pop 的路由上（`_pumpRoutedPage`），删除请求发出后 `pageBack()` 离开页面，再放行响应。三组事实：① `expect(find.byKey('countdown-row-7'), findsNothing)` 通过 → 响应到达时 State 确已卸载；② 成功与失败两条路径的 `tester.takeException()` **都是 null** → `showSnackBar` 不抛（`messenger` 在 `await` **之前**就已捕获，复核假设的「用已脱离树的 context 去 `of()`」并不成立），`ref.invalidate` 同样不抛；③ 未加守卫时失败用例 `find.textContaining('操作失败')` **命中 1 个** → 真实缺陷是**过期提示被投到了用户已经离开的那一页之上**（`MaterialApp` 的 messenger 全局共用），属 UX 缺陷而非崩溃。已加 `if (mounted)` 并把两条探针固化为回归用例（现在 15 项全绿：5 契约 + 10 Widget）；去掉守卫后「写失败返回时页面已离开」立即失败，故该守卫是被测出来的、不是猜测性防御。
- 2026-09-22：第三轮其余 Minor 的处置：M-1（4xx/5xx 时提示退化成 `DioException [404]: null`）**不在本切片修** —— 同仓 `task_assign_page.dart:66` 等既有代码同病，属全仓错误文案治理；M-2（单飞闸期间零反馈）留待后续；M-3（`countdownsProvider` 去掉 `autoDispose` 以彻底消除过期响应）会改变共享 provider 的存活语义，影响面超出本页，本轮仍以单飞闸 + 卸载守卫兜住，另登记；M-4（`list`/`create` 也补 `code!=0` 用例）本轮只为本片新增的 `update`/`delete` 建了用例，`create` 的 `isCountUp→showAge` 仅改死名字未动线协议；M-5（`ReminderActionApi.dismiss/snooze` 同样漏 `_unwrapData`，`efficiency_api.dart:996-1006`）**属既有缺陷、非 024 引入**，只登记不顺手改；M-6（提交卫生）与本轮已登记的分 PR 要求一致：`git add` 必须精确到 5 个路径，禁止 `git add -A`。复核同时确认前两轮修正无回退、`Semantics` 写法与全仓 30+ 处一致、`_countdownStyles` 可见性合规。
- 2026-09-22：自查发现的**第三处同类缺陷已按同一套路修掉**：单飞闸只盖住了列表里的编辑/删除入口，AppBar 的「新建」按钮未闸 —— 在途写时仍可打开编辑器填完并保存，而 `_runWrite` 的 `if (_writePending) return;` 会**静默丢弃**这次保存（对话框已关闭、无任何提示），等于丢用户输入。先加断言使其 RED（`countdown_manage_test.dart:226`，在途写时 `find.text('新建倒数日')` 竟命中 1 个），再把按钮改为 `_writePending ? null : () => _showEditor()` 转绿。现在四个写入口（新建、行点击、编辑按钮、删除按钮）与保存动作全部受同一个闸约束。


- T005 门禁部分**已全部通过（2026-09-22 最终状态一次跑完，日志 `/tmp/gate-024c.log`）**：`git diff --check` exit=0；`dart format --output=none --set-exit-if-changed` 对本轮 6 个显式路径 `Formatted 6 files (0 changed)` exit=0；`flutter analyze` `No issues found!`；`flutter test --tags golden` `+9: All tests passed!`；`flutter test --exclude-tags 'golden || performance' --concurrency=1` `+726 ~26: All tests passed!`（较 `a1d7733` 基线 712 增加 15 项 = 本切片 5 契约 + 10 Widget）；`flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` `✓ Built build/web`。
- T005 复核部分：三轮只读交叉复核已闭合（第 1、2、3 轮各 1 个 FAIL，全部落地修正，理由与实测证据见上）。第 3 轮的 FAIL 项修正后，**用户明确指示「就此收口，不再加复核轮次」**，故未再跑第 4 轮 —— 这不是复核缺失，是本轮验收口径被人工调整，特此记账。
- T005 仍**未勾选**，唯一剩余条件是「回写矩阵 #49」：`dida-parity-matrix.md` 属 `zh-cloud-docs` 仓，且按约定状态翻转要引已合并的 commit/PR，只能等本切片合并之后（已排入 docs 侧的后续 PR）。同时登记一项跨仓契约缺陷：服务端 `update` 是**全量覆盖**（会写 `backgroundImage`/`sortOrder`），客户端不发送即置空 —— 现在没有任何客户端路径写这两个字段，但一旦要支持背景图/排序，必须先在 Service 侧改契约（PATCH 语义或客户端回传原值），不得由 Flutter 侧硬编码绕过。另登记待复核：`todo_recommend_task` 表与 `TodoRecommendTaskMapper.selectTopByUser:13` 已无调用方，属后端孤立死代码，只提醒不删。


## 未勾项与下一步

- T005 还差：按用户授权的拆分红线，本工作树的改动分 4 个 PR 提交 —— ① 024 倒数纪念日（只含本切片 5 个路径）② 020 搜索分页游标修复 ③ 其余 5 个切片的 `tasks.md`/`spec.md` 回写 ④ `zh-cloud-docs` 矩阵更正与 #49 翻转。本切片合并后，才能以 commit SHA 回写 `dida-parity-matrix.md` 的 #49 行（`无 → 部分`，仍缺背景图与分组）并勾上 T005。`pubspec.lock` 属本机重解析产物，不进任何 PR。

- 本切片只覆盖 #49 中「可离线自足」的部分；`backgroundImage` 展示与嘀嗒「显示分组（倒数日/纪念日/生日/节日）」需要 Service 字段与存储通道，属独立规格，不在本项内。
- **下轮入口（矩阵 #31 日历显示设置）**：已按嘀嗒《02-功能指南/02-日历/06-日历显示设置.md》核对真实设置面 —— 显示农历、显示节假日调休（在「设置-日期与时间」）、任务/习惯/纪念日颜色、「现代/经典」样式与类型图标、辅助时区、显示详细/已完成/检查事项/所有重复周期/打卡/专注记录、日历「显示范围」筛选；FL `lib/` 对 `农历|lunar|节假日|holiday|类型图标|辅助时区|显示已完成` **实测 0 命中**（2026-09-22 复跑），判定「无」成立。BE 已具 `/app-api/todo/calendar/holidays?year&region` 与 `/app-api/todo/calendar/lunar-date?date`（`AppTodoCalendarController.java:40/50`、`LunarUtil`、`TodoCalendarService.java:19/24`），但**农历只有单日查询**：月视图 42 格就要 42 次请求，所以本轮第一动作必须是在 Service 加区间端点（`/lunar-range?start&end`）再改客户端，不得让 Flutter 侧硬编码农历表绕过。矩阵 #31 行的证据已按此更正（原判「无」正确，但理由曾使用嘀嗒页面上并不存在的 `隐藏周末`/`周起始` 关键词）。

