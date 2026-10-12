# Tasks: Todo 清单 Section

- [x] T001 Drift schema 22 增加 Section 表与任务外键
- [x] T002 新增 Section Repository 与 Provider
- [x] T003 扩展任务创建、复制和更新的 Section 合同
- [x] T004 接入 push/pull/bootstrap/tombstone 和临时 ID
- [x] T005 修复跨页父清单后到时的 Section 暂存
- [x] T006 增加工作区管理条和任务“移动到分组”
- [x] T007 覆盖 Repository、同步和 Widget 测试
- [x] T008 使用 Claude CLI 完成只读交叉评审并处理有效发现
- [ ] T009 完成真实服务端双设备同步与真机交互验收

## 执行证据

- 2026-08-01：补齐分组后首次跑全部 9 张已批准工作区黄金图，定位到“没有 Section 也常驻 44px 管理条”使 8 个列表场景整体下移。未重录基线：先用 Widget 红测冻结“空 Section 不占列表高度”，再把创建首个分组收进已有排序/批量菜单，已有 Section 时仍显示管理条并保留新建、改名、排序和删除。分组工作区 2 项与 9 张原黄金图全部通过，基线图片零修改；全量非 golden/非性能测试 625 项通过、26 项受保护 live 用例跳过，`flutter analyze` 无问题，Web release 构建成功。
- 2026-09-22：本机 Flutter 工具链重建（Flutter 3.44.8 / Dart 3.12.2）后在 `develop` HEAD `a1d7733` 复跑，Section 相关的仓库/同步/Widget 合同与 9 张黄金图仍全部通过（golden 9/9；全量 `flutter test --exclude-tags 'golden || performance' --concurrency=1` `+712 ~26: All tests passed!`，26 项为受保护 live 用例按显式 dart-define 开关跳过），即本切片的本地回归面在后续多切片合入后仍未被破坏。T009 依旧未勾选：其要求是真实服务端的双设备同步与真机交互验收，本会话既无可登录的 test 环境第二台物理设备，`develop` 远端构建与 test 部署门也仍是 runner 侧容器创建失败（runs `4675`/`4676`/`4677`，日志终点 `NanoCPUs can not be set, as your kernel does not support CPU CFS scheduler or the cgroup is not mounted`），本地 Drift/Widget 测试不能替代该项验收。
