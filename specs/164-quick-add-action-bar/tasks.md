# 164 台账

## T1 口径（opencode 三轮）

- [x] v1 渲染走配置 + 编辑入口放第二步；id 用 wire 名；三件契约写死（dueAt 优先级/标签二次写/切清单清分区）。
- [x] 优先级不做三态（显示生效档）；清除=长按；识别行不并进日期 chip。

## T2 改动

- [x] setting + bar widget + 四 handler + 拆 Dropdown + create 切 state + 识别行压制。

## T3 判据与探针

- [x] 5 条判据全绿；**探针**（切清单不清分区 + 识别行不压制）⇒ 红。
- [x] 既有 subtask 测试同步改走新 chip（+9 全绿）。
- [x] 全量 `+2138 ~26`，0 失败；analyze 0；format rc=0。

## 判据抓到的真缺陷

1. `write()` 漏"多余 id"校验（containsAll 不查超量）⇒ 恰等校验补上；
2. 清单弹层 `valueOrNull` 首帧 null ⇒ 只渲染收集箱 ⇒ 改 `read(provider.future)` + mounted。

## 过程教训

1. **既有测试从不用 pumpAndSettle**（sheet 的 listener 让它永不静止 ⇒ 10 分钟超时）；
2. fixture 有种子数据 —— 库断言按标题过滤；
3. 弹层项不在视口时 ensureVisible 前给足 pump；
4. heredoc 的 `\$` 转义让 print 失效。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `quick_add_action_bar_test` | 5 条全绿 |
| 反向探针 | 红 |
| `subtask_context_and_consecutive_test` | 9 条全绿 |
| 全量（exclude golden/performance） | `+2138 ~26`，**0 失败** |
