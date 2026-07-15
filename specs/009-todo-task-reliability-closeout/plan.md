# Implementation Plan: Todo 推荐任务与可靠性收口

**Branch**: `feat/99-todo-reliability-closeout` | **Spec**: [spec.md](spec.md) | **Issue**: #99

先以固定 fixture 写推荐、幂等、冲突、退避和可访问性失败测试；再扩展 Drift、Repository、SyncCoordinator 和既有工作区反馈。所有真实设备/API/视觉结论写入 Docs #55。

```bash
nice -n 19 flutter analyze
nice -n 19 flutter test --concurrency=1
git diff --check
```
