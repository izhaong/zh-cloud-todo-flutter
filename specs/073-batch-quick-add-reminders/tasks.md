# 任务与台账

| # | 任务 | 判据 | 状态 |
| --- | --- | --- | --- |
| T1 | 红测 | `flutter test test/features/task/quick_add_batch_reminders_test.dart --concurrency=1` ⇒ 实现前 `+1 -3`（3 条断言级失败，不是编译错），实现后 `+4: All tests passed!`、`rc=0` | 完成 |
| T2 | helper | `git grep -n 'attachResolvedReminders' HEAD -- lib` ⇒ 定义在 `lib/features/task/quick_add_batch_reminders.dart`，调用两处，分别是 `lib/features/home/home_shell.dart` 与 `lib/features/task/tasks_by_list_page.dart` | 完成 |
| T3 | 失败语义 | 部分失败那条用例：`test/features/task/quick_add_batch_reminders_test.dart` 里「其中一条提醒写失败时其余照常落库，并一起报出成功数与失败数」—— 提醒行 2、任务行 3、消息同时含 2 与 1 | 完成 |
| T4 | 门禁 | 见下表（日志目录 `/tmp` 之外不留痕，读数抄在本表；复跑命令即本行给出的那条） | 见「三」 |

## 三、门禁读数（跑在最终字节上）

| 门 | 命令 | 读数 |
| --- | --- | --- |
| 1 | `git diff --check origin/develop..HEAD` | 无输出、`rc=0` |
| 2 | `dart format --output=none --set-exit-if-changed lib/features/task/quick_add_batch_reminders.dart lib/features/home/home_shell.dart lib/features/task/tasks_by_list_page.dart test/features/task/quick_add_batch_reminders_test.dart` | 见 PR 正文回填 |
| 3 | `flutter analyze` | `No issues found!`、`rc=0` |
| 4 | `flutter test --tags golden` | **未跑**（本轮预算用尽）⇒ 不判绿，下轮补 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | **未跑** ⇒ 不判绿，下轮补（新目录只加 4 条用例，全量基线 +4 是预期） |
| 6 | `flutter build web --release` | **未跑** ⇒ 不判绿，下轮补 |

> 表里写「见 PR 正文回填」是刻意的：本笔提交时门禁仍在跑，未跑完的格子**不许**填绿。
