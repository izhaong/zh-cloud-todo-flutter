# Implementation Plan: Todo 推荐任务与可靠性收口

**Branch**: `feat/99-todo-reliability-closeout` | **Spec**: [spec.md](spec.md) | **Issue**: #99

先以固定 fixture 写推荐、幂等、冲突、退避和可访问性失败测试；再扩展 Drift、Repository、SyncCoordinator 和既有工作区反馈。所有真实设备/API/视觉结论写入 Docs #55。

Issue #236 先补 Repository 与 Widget 失败测试：冻结客户端日界线参数、已有截止时间墙钟保留、无截止时间全天语义、Drift + outbox 原子性、重复点击幂等、成功移出缓存和失败 live-region；再接入 `HomeShell`，不改变任务正文点击行为。

Todo Flutter Jenkins 迁移先增强 `tool/test_jenkinsfile_runtime_contract.sh`，让旧 `GenericTrigger` / `withFolderProperties()`、Job 名环境推断、`abortPrevious` 与 Folder 部署目录合同失败；再把根 Jenkinsfile 收敛为单 Gitea Multibranch ref 路由，并以真实 Jenkins develop 构建验证运行时、测试、Web 制品和 test 部署。

```bash
nice -n 19 flutter analyze
nice -n 19 flutter test --concurrency=1
git diff --check
```
