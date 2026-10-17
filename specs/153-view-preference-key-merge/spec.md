# 153 · 清单作用域偏好 pull 按键合并（原 FL #422）

## 病灶

`sync_coordinator.dart` 的 `_upsertLocalViewPreference` 在写回本地行时是**整行覆盖**：

```dart
valueJson: jsonEncode(localPayload),
```

`SIDEBAR_VISIBILITY` 这一行偏好上**挂着多个键**（`showTags`、`showFilters`，以及快捷键覆盖等），
但 pull 回来的 payload 是**整行**。两台离线设备各改其中一个键（A 改 `showTags`、B 改 `showFilters`）
各自 push 后，服务端只剩后推者那一行 ⇒ **先推那一侧的键在 pull 回来时被整行顶回默认**，
用户明确设过的偏好**静默消失**。

这正是单机写侧早就修掉的那个病灶的**跨端版本**：`sidebar_visibility_repository.dart` 的
`_write` 已经是"读旧行 → 按键合并 → 写回"，并有用例钉着「两个开关写同一行偏好」；
pull 端同款既无实现、也无用例。

## 修法

1. **只对 `SIDEBAR_VISIBILITY` 做键级并集**（`{...本地, ...来料}`：来料覆盖同键，本地独有的键保留）。
   同一张表上还有 `TASK_CAPTURE`（payload 带 `defaultListServerId` 的本地化改写，不是纯键值 map）、
   看板偏好（列级 fallback）、以及 swipe / sort / grouping 等 ——
   **一次 PR 给每个 sourceType 都定合并策略，验证面会炸**，故本切片只收一个。
2. **只在 pull 常态那条路上合并**，冲突回写那条**保持"服务端优先"**。
   理由：冲突路径**不会回推**（冲突后 outbox 被标 failed 且不重排），
   在它上面做键级合并会造出"本地行 ≠ 服务端行、而双方 revision 相同"的**永不分叉态** ——
   判据还会**假绿**（只驱动 pull 就能通过）。故加了 `mergeLocalKeys` 开关，**默认 false**。
3. **合并后把并集回推**一次：只在本地合并的话，A 的本机看起来对了、B 上仍然是缺的 ——
   那不叫修好。回推的判据是「**并集 != 来料**」：相等时**不回推**，
   否则 `pull → 合并 → 回推 → 再 pull` 会**自激**（每一轮 pull 都推一条一模一样的东西）。
4. 新增 `preferenceKeyMap()`：拆壳读**内层**键值 map，包装形状（`{"valueJson":"{…}"}`，pull 侧写的就是它）
   与裸形状（单机写侧）**两种都吃** —— 与仓储 `_jsonMap` 同一口径的读半边。
   读不懂（坏 JSON / 形状不对）就**不合并**（宁可不动，也不拿半个 map 去覆盖）。

## 判据

真库 + 真 `SyncCoordinator` + 罐头 pull 响应：

| 断言 | 为什么 |
| --- | --- |
| pull 后 `showTags` 仍为 `false` | 这正是本单报的**静默丢失** |
| pull 后 `showFilters` 为 `false` | 来料的键当然要生效（不能为了保本地而丢来料） |
| outbox 里有 `view_preference` | 并集要**回推**，否则对端永远学不到（只本地合并 = 假修好） |

**反向探针**：把 `_mergedValueJson` 的合并关掉（直接 `jsonEncode(localPayload)`）⇒
`showTags` 变 `null`，判据转红。

> ⚠️ 探针第一次**没生效**（锚点字符串与 `dart format` 之后的写法不一致，替换未命中），
> 于是"探针下仍绿"——差点被当成"判据没咬住"。**改完探针必须确认它真的改到了**
> （打印替换结果 / 看 `grep`），否则绿的意思是"探针没跑"，不是"修复成立"。

## 明确写进规格的边界

**跨端「重置回默认」不传播。** 本地删键后，服务端那份仍带着它，
合并会把它当"本地独有的键"保留下来。这是本口径的**已知边界**，不是漏掉：
要支持"删除也跨端生效"，得引入**墓碑 + 版本序**（谁能压过谁要有定序），
那是另一个设计，且服务端 `valueJson` 只当不透明串存、不解析 —— 纯客户端约定能做，
但"两个方向的并发写谁赢"必须有明确规则，不能顺手做。
