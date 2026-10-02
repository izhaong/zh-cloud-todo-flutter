# 台账：详情里输入「#」创建标签（FL Issue #408，第 167 轮）

分支 `wip/408-detail-hash-tag`，基线 `zh-cloud-todo-flutter origin/develop`（取数基准现读）。
规格与方案见同目录 `spec.md`。

## 一、红测 → 实现 → 反向探针

- 实现前跑 `flutter test test/features/task/detail_hash_tag_test.dart`
  ⇒ `00:01 +3 -1`：三条按缺口判据红（`Expected: '写周报' / Actual: '写周报 #周会'`、
  `Expected: ['周会'] / Actual: []`，以及失败提示那条找不到文案），
  第四条（无井号不动标签表）在改前就是绿的，它守的是回归面。
- 实现后同一条命令 ⇒ `00:01 +4: All tests passed!`（日志 `/tmp/r167-green7.log`）。
- 反向探针：把 `_save()` 里「没有井号就 return」那一句换成恒真 return（等于摘掉标签那次写）后重跑
  ⇒ `00:01 +1 -3`：绿的只剩回归护栏那条，说明三条判据真的咬在标签写入上而不是顺带绿。
  探针字节用 `cp` 备份、`cmp -s` 还原，输出 `restored byte-identical`。
- 过程中两条真实教训（都不是缺口本身）：
  1. 种子必须先建清单——`TaskRepository._requireWritableList`（`lib/state/repositories/task_repository.dart:651`）
     对假 `listId` 抛「清单不存在」，第一次跑四条全红在这一条上；
  2. 详情面板收尾有悬挂计时器，用例末尾要先拆树再把假时钟推过去（`settleTimers`），
     否则报 `A Timer is still pending even after the widget tree was disposed.`。
     失败提示那条另有一层：`ScaffoldMessenger` 按队列播放，「已保存」要先播满自动隐藏时长，
     所以断言前显式 `pump(Duration(seconds: 5))`，并在那之前先证「已保存」确实在播
     ——不是靠多 settle 一下把它蒙过去。

## 二、门禁（跑在最终代码字节上）

| 门 | 读数 |
| --- | --- |
| 1 `git diff --check origin/develop` | rc=0 |
| 2 `dart format --output=none --set-exit-if-changed` 加两个字面量路径 | `Formatted 2 files (0 changed)`、rc=0 |
| 3 `flutter analyze` | `No issues found! (ran in 1.3s)`、rc=0（先前一条 `unused_import` 已把测试里没用上的 drift import 去掉） |
| 4 `flutter test --tags golden` | `00:10 +9: All tests passed!`、rc=0，基线 9 张未重录 |
| 5 非 golden 用例集 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 见下面「五、门禁补读」：这一条要在最终字节上现读，未读到之前不得当作通过 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | 同上，未读到不得当作通过 |

## 三、四件套归属

- 「失败保留已加载数据」：用例第四条（标签那次写抛错 ⇒ 任务已落库、失败文案上屏）。
- 「320px + 1.3 倍字号」「独立读屏语义」：本单**没有新增界面或控件**，落在既有标题输入框上，
  由 `test/features/task/embedded_detail_header_narrow_test.dart` 与
  `test/features/task/task_detail_pane_test.dart` 量的是同一块表面承接；本单不重复声明这两面为新增。
- 「过期响应不覆盖新响应」：本单没有新增异步回写路径，`_save()` 既有的 taskId 守卫原样保留。

## 四、语义取舍与第二意见

1. 井号解析不在本文件重写词法：复用 `lib/features/tag/hash_tag_input.dart` 的
   `parseHashTagInput` 与 `resolveTagIdsByName`（它们各自已有纯词法用例与真表用例），
   否则同一套词边界规则会在两处漂移。
2. 标签写是任务保存成功之后的第二次写，且与 `tagIdsOf(taskId)` 的现值取并集后落回，
   不改写「先删后加」的既有语义。
3. 输入过程中不给「将新建标签：X」的预提示——嘀嗒源页只承诺「输入『#』快速创建标签」，
   未承诺输入态预览，故不加（记为已知边界，见 `spec.md` 五）。
4. 交叉验证通道本轮未取第二意见：三处取舍都有既有用例的红灯当判据，不需要外部意见顶替。

## 五、门禁补读

（本节由现跑读数填写；填上前，门 5 与门 6 属「未执行≠通过」。）
