# 计划

1. 红测先行：`test/features/task/quick_add_batch_reminders_test.dart` 四条（每行一条提醒 / 无时间不写也不报错 / 仓储未就绪要出声 / 部分失败保留全部任务并报成功失败数）。实现前 stub 返回 null，实测 `+1 -3`。
2. 实现 `lib/features/task/quick_add_batch_reminders.dart` 的 `attachResolvedReminders`。
3. 接线：`home_shell.dart` 的 `_quickAdd` 与 `tasks_by_list_page.dart` 的 `_submitQuickAdd`（后者在有 `onQuickAdd` 回调时走宿主，两处都接才不漏）。
4. 门禁六道跑在最终字节上；台账过 `tool/check_spec_selfscan.py`。
