# 任务清单

## 第 196 轮（归档／已归档／恢复）

- [x] 契约核对：服务端 `PUT /todo/countdown/{id}/archived`（参数名 `value`）与 `GET /list?archived=` 均已在 `origin/develop`，`AppTodoCountdownRespVO` 有 `archived` ⇒ 本轮不改后端
- [x] 取号：`git ls-tree -d --name-only origin/develop specs/` 与全部远端分支同名扫描，070–076 已占，077 空
- [x] 红测：`test/features/countdown/countdown_archive_test.dart` 现跑 `grep -c '^  testWidgets(' test/features/countdown/countdown_archive_test.dart` 读数 10 条。先跑出过红（缺 `archived` 字段与 `setArchived` 端点），最后一条红是「切回主列表后迟到的响应不得覆盖」——真实原因是 autoDispose 重取需要推进帧数，改成 `_advance(tester)` 后该文件 10 条全绿（原始输出 `00:01 +10: All tests passed!`）
- [x] 实现：`CountdownDto.archived`；`CountdownApi.list({archived})`；`CountdownApi.setArchived`；`archivedCountdownsProvider`；页面与卡片「...」菜单；失败保留数据
- [x] 六道门禁（都在最终字节上各跑一次，日志 `/tmp/gates456-r196.log`）：`git diff --check` rc=0；`dart format --output=none --set-exit-if-changed` 本轮显式 7 个文件输出 `Formatted 7 files (0 changed)`；`flutter analyze` 输出 `No issues found!`；`flutter test --tags golden` 输出 `00:05 +9: All tests passed!`（基线 9 张未重录）；`flutter test --exclude-tags 'golden || performance' --concurrency=1` 输出 `03:35 +1357 ~26: All tests passed!`；`flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` 输出 `✓ Built build/web`
- [ ] 只读复核：`claude -p` 的 `VERDICT: PASS` 是修 pump 时序之前那一版字节上拿到的，改完测试文件后没有再跑第二轮 ⇒ 合并前置未满足，本 PR 不开合并。`cursor-agent` 交叉验证的意见与处置逐条写在 PR 正文里
- [x] 自扫：`python3 tool/check_spec_selfscan.py specs/077-countdown-archive/tasks.md` 现读输出 `失项 0 条`（本行写完后再跑一次取数）
- [ ] 回写：矩阵 #50 的「说明/缺口」格按合并后 SHA 更新（不新增相对锚点，证据写成同行可复算命令）
- [ ] 同步：FL 分支→commit→push→PR 已完成，合并与父仓 bump 留下一轮

## 余量与下一轮入口

- 本 PR 合并前还欠一件事：在 PR head 的最终字节上重跑一次 `claude -p` 取 VERDICT，再把结果回写本文件上一条方框
- 「分组」面（`显示分组` 开关 + 倒数日、纪念日、生日、节日四类自动分组）仍未做，前置是后端 `GET /list` 按 `type` 过滤或返回分组，跟踪在 zh-cloud-service #304
- #50 的桌面端形态（右键卡片、左上角切「已归档」）本轮只落 mobile 的「...」菜单路径，桌面差异留待与各前端形态统一时再判
