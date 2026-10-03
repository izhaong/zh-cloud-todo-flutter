# 任务清单

## 第 200 轮（置顶客户端接线）

- [x] 前置已合并：service PR !315（develop `2a5a16cde9dd`）提供 `PUT /todo/countdown/{id}/pinned?value=`，独占在服务端同一事务内成立
- [x] 取号：FL `git ls-tree -d --name-only origin/develop specs/` 到 077，全部远端分支里 078 未被占
- [x] 红测：`test/features/countdown/countdown_pin_test.dart` 在实现前编译挂掉，两类报因：DTO 还没有 `isPinned` 这个命名参数；`expect` 的说明文字在本仓 flutter_test 里必须写成 `reason:` 位置参数不行。行号没写进台账，因为 `dart format` 一跑就会漂
- [x] 实现：`CountdownDto.isPinned`、`CountdownApi.setPinned`、卡片「...」的「置顶」项、`_runPin` 与 `countdown-pin-error` 提示
- [x] 单文件读数：本文件 8 条用例全过（`flutter test test/features/countdown/countdown_pin_test.dart`），并被门禁第 5 道的套件覆盖：`03:41 +1365 ~26: All tests passed!`
- [x] 六道门禁（最终字节，日志 `/tmp/gates-452.log`）：`git diff --check` rc=0；`dart format --output=none --set-exit-if-changed` 本轮显式 3 个文件 rc=0；`flutter analyze` `No issues found!`；`flutter test --tags golden` `00:09 +9: All tests passed!`（基线 9 张未重录）；`flutter test --exclude-tags 'golden || performance' --concurrency=1` `03:41 +1365 ~26: All tests passed!`；`flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` 见日志末尾
- [ ] 只读复核：`claude -p` 本轮未派（同日两次派单都 0 字节，不刷循环求绿），登记未复核；`cursor-agent` 4143 字节给了 CROSSCHECK: DONE，其中「客户端不排序、不二次写、不自创取消入口、未越界」四条判过，**「过期响应不覆盖新响应」那条断言被判未量到声明表面** —— 已按下面一条如实记为未满足
- [x] 台账自扫：`python3 tool/check_spec_selfscan.py specs/078-countdown-pin/tasks.md` 输出 `失项 0 条`（本行写完再跑一次）
- [ ] 四件套里「过期响应不覆盖新响应」**未满足**：那条用例先 gate 住列表再点「置顶」，`_runPin` 触发的重取被同一个 gate 卡住后又被测试自己 complete 掉，等于没有投出「旧响应迟到」的时序，判据落空。已立单，本轮不冒充通过
- [ ] 回写：矩阵 #50 的「置顶」面按合并 SHA 改判（不新增相对锚点，证据写成同行可复算命令）
- [ ] 同步：commit→push→PR→合并→父仓 bump
- [ ] 「取消置顶」入口仍缺原文依据，未做
