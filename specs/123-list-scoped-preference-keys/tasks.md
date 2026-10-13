# 执行记录：清单作用域偏好的跨设备键归一（FL #619，矩阵 #14 面⑨ 的前半）

> 编号说明：本目录起稿在 `specs/121-…`，提交期间并行会话把 121 用给了 `specs/121-timeline-color-by`
> （FL !621）⇒ 改到 122；合并 `origin/develop@b5682baf` 时又撞上 `specs/122-timeline-smart-list-guard`
> （FL !624）⇒ 最终 **123**。取号时扫过 develop 与全部 `refs/pull/*/head`，123 当时没人用；
> 同一晚上两次撞号说明「扫 develop ∪ 未合并分支」在并行会话同时开工时仍然会输在时间差上，
> 落盘前应当再扫一次（本笔就是这么发现的）。

## 落地的文件

| 文件 | 干什么 |
| --- | --- |
| `lib/core/sync/list_view_preference_scope.dart` | 一处定义"三种类型各自的本地形状"与规范键的换算，含设备无关键与形状不认识两类豁免 |
| `lib/core/sync/sync_coordinator.dart` | 出站把本地键换成 `list-server:<serverId>`、入站换回该类型形状，出站与入站的判定都走上面那个类；复算 `grep -c ListViewPreferenceScope lib/core/sync/sync_coordinator.dart` ⇒ 7（出站块 3 行、入站块 4 行），同 `grep -n "ListViewPreferenceScope\." | wc -l` 数到的也是这 7 行 |
| `test/sync_coordinator_list_scoped_preference_test.dart` | 出站两类各一条、收集箱豁免、清单未上服务端本轮不发、入站写回本地形状并端到端读回、清单不存在时不落地死行；复算 `grep -c "  test(" test/sync_coordinator_list_scoped_preference_test.dart` ⇒ 6（上面列的就是这 6 项） |
| `test/core/sync/list_view_preference_scope_test.dart` | 纯形状用例：三种类型都能取出清单 id、设备无关键不动、形状不认识的键按原样发送、规范键与本地形状来回换算、越界类型一律不动；复算 `grep -c "  test(" test/core/sync/list_view_preference_scope_test.dart` ⇒ 5（上面列的就是这 5 项） |
| `test/sync_coordinator_organize_search_test.dart` | 改掉一条**旧断言正好钉住这个缺陷**的用例（见下方"契约钉"） |

## 测试与结果

- `flutter test --no-pub test/sync_coordinator_organize_search_test.dart
  test/sync_coordinator_list_scoped_preference_test.dart
  test/core/sync/list_view_preference_scope_test.dart` ⇒ `+20 All tests passed!`
  （声明数逐文件复算：同一条 `grep -c "  test("` 分别对三个文件跑 ⇒ 6、5、9 ⇒ 本轮新增的是前两处 11 条，第三个文件是改写那条契约钉、条数不变）
- `flutter analyze` ⇒ `No issues found!`
- 全量（跑在并过 develop 之后的最终产物 `7af77179` 上，尺子 `bash tool/gate_counts.sh /tmp/gate299c.log`）
  ⇒ `last=1975/26/5 max=1975/26/5 complete=yes`；
  develop `b5682baf` **单独实测**（`git worktree add --detach /tmp/wt-fl-299dev origin/develop` 后跑同一条命令）
  ⇒ `last=1964/26/5 max=1964/26/5 complete=yes`
  （对账 `1975 - 1964 = 11` ＝ 本轮新增的 11 条；5 项红与 develop 逐条同名，都是 #607/#610/#569 的存量 ⇒ 净新增红 0）
- 黄金基线 0 张：`git diff --name-only cd57faf6 HEAD -- test/goldens test/visual` ⇒ 空输出
  （本笔不碰任何 widget，弹层/像素都不涉及）

## 变异探针

| 探针 | 改哪 | 结果 |
| --- | --- | --- |
| P1 | 出站把 `localListId(...)` 的入参换成 `null`（等于出站永不归一） | 红 3 条：出站两条 + "清单还没上服务端不发" |
| P2 | 入站把 `isListScopedType(payloadSourceType)` 换成永不成立的比较 | 红 2 条：入站写回本地形状 + 清单不存在不落地 |
| P3 | 整个 `sync_coordinator.dart` 退回修复前（`cp <(git show cd57faf6:lib/core/sync/sync_coordinator.dart) …`） | 复跑 `flutter test --no-pub test/sync_coordinator_list_scoped_preference_test.dart test/sync_coordinator_organize_search_test.dart` ⇒ `Failing tests:` 段列出 6 项：新增文件里除收集箱豁免外的 5 项 + `sort preference pushes from A and B…` 那条改写过的用例 |

P1/P2 的还原都是 `cp` 备份后 `cmp` 校验（不用 `git checkout --`，那会连未提交改动一起抹掉）。

## 契约钉：旧断言钉的正是这个缺陷

`test/sync_coordinator_organize_search_test.dart` 里那条
`sort preference pushes from A and B restores it from the sync feed` 一开始是被我改红的。
读下去发现它并没有测到"跨端"：

- A 端从没插过任何 `todoLists` 行，`save('list-a', ...)` 的 `sourceKey` 就是字面量 `list-a`；
- B 端读回也用 `.get('list-a')` —— **两端的键是同一个字符串**，
  而真机上同一服务端清单在两台的本地 id 是各自的 uuid（`sync_coordinator.dart` 里
  `existing?.id ?? _uuid.v4()`）⇒ 这条用例的结构让它无法暴露缺陷，
  同时 `expect(pushedChange!['payload'], {…'sourceKey': 'list-a'…})` 把脏形状钉成了契约。

改法（不是把断言放松）：A 端插 `id='list-a', serverId=7` 的清单行，B 端插
**另一把本地 id** `list-b-on-b` 但同一个 `serverId=7`，
断言出站是 `list-server:7`、B 按自己的 id 读回 A 设的档位与方向。
P3 证了它现在是真的判据：把同步层退回修复前 ⇒ 这条用例单独红（`Failing tests` 只列它）。

## 自我更正

第一轮全量跑出来 `last=1961/26/6`（复算 `bash tool/gate_counts.sh /tmp/gate299.log`），比本轮收尾的读数多 1 项 ⇒ 多的那 1 项就是上面那条契约钉。
我先把它当成"回归"查了两遍代码，才确认是实现正确、断言过时——
这个顺序是对的（新红先假定是自己造的），差别在于这次要额外回答"旧断言测到了它声称的东西吗"。

## 交叉验证记录

见 `spec.md` 最后两节：判 A、`TASK_SORT`/`TASK_GROUP` 不该被那个开关管、
`_resolvePayloadRefs` 的 null 是"延后"不是"丢弃"（本台账第 3 条需求照它写）；
它另外给的"收集箱其实同步了""智能清单落进 inbox 行"两条我对着代码复验后并进了 FL #619；
它建议"本轮不要顺手改归一"未采纳，理由与去处也写在 `spec.md`。

## 合并状态（2026-10-13，本笔留言同步在 FL !622）

`POST /pulls/622/merge` 连发九次都是 `405 Please try again later`，`mergeable` 恒 `False`；
同一时刻本地四条判据都说明这是干净快进（下面逐条可复跑）：

- `git merge-base --is-ancestor origin/develop HEAD` ⇒ rc=0
- `git rev-list --count HEAD..origin/develop` ⇒ 0
- `git merge-tree --write-tree origin/develop HEAD` ⇒ rc=0，输出里 `CONFLICT` 行数为 0
- `git ls-remote origin refs/pull/622/head` ⇒ `21e55704a749`（PR 的 head ref 不是过期快照）

⇒ 判 Gitea 侧的合并状态没算出来，不重复刷循环（先例是 !423 刷到二十五次仍 405）。
处置：继续往本 PR 追加提交逼它重算；仍不行就留给下轮重试，台账与读数不因此改口径。
