# Todo 搜索范围与任务组合筛选任务

- [x] T001 建立本地搜索范围、组合筛选与稳定分页的 Repository 红绿合同。
- [x] T002 实现全部/任务/清单/标签范围以及任务筛选选择器。
- [x] T003 实现加载更多、过期响应隔离、失败保留与 320px 读屏行为。
- [ ] T004 通过格式、静态分析、全量测试、Web 与 Claude CLI 门禁。
- [ ] T005 创建并合入 Gitea PR，补 develop 构建和测试环境证据。

## 执行证据

- 2026-08-02：依据滴答官方“搜索任务”文档审计当前 Flutter：已有本地 FTS 和混合任务/清单/标签结果，但搜索页缺少范围切换，任务搜索无法在同一语境组合清单、标签、优先级和日期。既有后端分页搜索 API 只作为跨端契约存在；本切片坚持 Drift 离线优先，不增加直接网络读取。
- 2026-08-02：T001 红测先准确缺少 `TaskSearchScope`、`TaskSearchPageRequest`、`TaskSearchPageResult` 与 `TaskQueryRepository.searchPage`。最小实现保持旧 `search()` 兼容，先按 FTS 既有稳定顺序限定范围，再与 `TaskQueryFilter` 的任务 UUID 求交集后切为最大 50 条的一页。55 条任务 fixture 的首页/尾页、重复查询稳定性、双标签/清单/优先级/日期 AND 组合，以及清单范围隔离均通过。
- 2026-08-02：T002 红测先找不到四个搜索范围控件；实现全部/任务/清单/标签切换和仅任务范围可见的筛选页。筛选页只订阅 Drift 清单/标签流，选择清单、两个标签和优先级后只保留交集任务；清除筛选后保留关键词和任务范围。首次测试暴露未订阅清单/标签流导致空下拉，已修正为在页面构建时订阅并传递当前快照。
- 2026-08-02：T003 红测先缺少可控本地查询入口；51 条分页夹具证明追加最后一条不会替换前 50 条，320px 滚动至页尾后“加载更多 1 条搜索结果”具备独立可点击读屏语义。延迟的旧关键词响应在新关键词成功后不能覆盖结果。Repository/持久化/组织 Widget 组合 57 项、`flutter analyze` 和 `git diff --check` 通过。
- 2026-08-02：复核发现普通清单 Provider 有意隐藏 synthetic `inbox`；筛选下拉显式补入“收集箱”，使所有任务位置都可按清单组合搜索。相应 Widget 回归、Repository/持久化组合 30 项、`flutter analyze`、`dart format --output=none --set-exit-if-changed` 与 `git diff --check` 均通过。
- 2026-08-02：变更后的 `flutter test` 全量结果为 `+687 ~26: All tests passed!`（26 项为受保护的 live 环境跳过）；`flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` 成功生成 `build/web`。Wasm dry-run 仅报告既有 `flutter_secure_storage_web` 对 `dart:html`/`dart:js_util` 的兼容性提示，未影响 JS Web 产物。

## 当前阻塞

- 2026-08-02：Claude CLI 2.1.216 以只读 `plan` 模式审查本切片，在约 2 分 30 秒内没有输出任何审查结论，已中断以避免无界等待；工作区无额外写入。该交叉验证未通过也未失败，T004 保持未完成，待 CLI 能返回带 `VERDICT` 的只读结果后补证据；本地格式、分析、测试和 Web 构建不受影响。
