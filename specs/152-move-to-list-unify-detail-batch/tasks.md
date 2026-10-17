# 152 台账

## T1 详情面板

- [x] 现读：`_save` 把 `listId` 交给 `update` ⇒ `_requireSectionInList` 拿旧分组的 id 校验新清单 ⇒ 抛错。
- [x] 修法：`update` 不带 `listId`；换清单走第二笔 `moveToList`，失败可见（只读说"只读"）。
- [x] 判据走**接缝**（`_RecordingMoveRepository`）：`update` 无 `listId` + 恰一次 `moveToList`。
- [x] 反向探针：退回 `update(listId:)` ⇒ 红。

## T2 批量

- [x] 现读三条缺口：不查可写 / 不清分组 / 不拒子任务；外层 `catch (_)` 把具体理由吞成「本地写入失败」。
- [x] 修法：三条守卫 + `sectionId` 清空 + `on StateError` 原样上报。
- [x] 判据三条（子任务 / 只读 / 清分组）。
- [x] 反向探针：三条各自撤掉 ⇒ 三条各自红。

## T3 验证

- [x] 详情面板 `+27`；批量所在文件 `+32`；两者全绿。
- [x] 反向探针（详情面板 1 条 + 批量 3 条）全部确认。
- [x] `flutter analyze` 0 issue。
- [x] 全量（exclude golden/performance）：`+2106 ~26`，0 失败；改动后相关 72 条复跑全绿。

## 过程教训

1. **试过"直接复用 moveToList"，被既有用例当场拦住**：它各自再入队一次 ⇒ 2 个任务 4 条 outbox，
   破坏"逐项各一条"。**要复用它的落库部分就得先把落库/入队拆开** —— 那是独立一刀。
   这轮我选择了"内联三条守卫"（把能修的修掉），并把**缺的**（子树）显式记成遗留，
   而不是硬塞一个会重复入队的实现。
2. **判据要挑稳定的那一层**：详情面板那条我先写的是 UI 点击，但"带分组"时点击路径驱动不稳
   （实测：选了目标清单却仍留在原清单，原因是 UI 层而不是修复本身）。
   换成**接缝判据**（记录 `update` 是否收到 `listId`、是否调了 `moveToList`）后既稳又更贴修复点。
3. **兜底 catch 会吃掉"可解释的拒绝"**：`catch (_) → '本地写入失败'` 让"子任务不许单独换清单"
   与"目标清单只读"都变成一句没有下一步的话。**判据要钉住 reason 本身**，不能只钉 failed。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 详情面板 | `+27 All tests passed!` |
| 批量所在文件 | `+32 All tests passed!` |
| 反向探针 | 4 条（1 详情 + 3 批量）各自红 |
| `flutter analyze` | `No issues found!` |
| 全量（exclude golden/performance） | `+2106 ~26`，**0 失败** |
| 相关复跑（详情+批量+收集箱入口） | `+72 All tests passed!` |
