# 实施计划

1. 在 `test/features/task/task_organize_search_test.dart` 先增加失败用例，锁定键盘修饰键、连续范围、选择坞响应式布局和删除确认。
2. 新建 `lib/features/task/widgets/task_batch_action_bar.dart`，将批量动作定义与 UI 从工作区标题栏迁移到内容区底部选择坞。
3. 调整 `lib/features/task/tasks_by_list_page.dart` 和任务行回调，让页面持有唯一选择集合与锚点，并按当前可见顺序解析 `Shift/Cmd/Ctrl` 点击。
4. 复用 `TaskRepository.delete` 实现确认后的逐项批量删除，保留失败项选择与可重试反馈。
5. 通过 Dart MCP 运行定向测试、全量静态分析和全量测试，再执行 `flutter build web --release`。
6. 完成独立代码审查，修复发现项后提交、推送、创建并直接合并关联 Issue #62 的 PR。
7. 在更多操作中补齐纯读的批量系统分享，按列表实际可见顺序汇总标题、正文和截止时间；验证任务与 outbox 前后不变，并关联 B3 Issue #95。
