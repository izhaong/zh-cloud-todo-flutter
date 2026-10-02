# 任务与台账

| # | 任务 | 判据 | 状态 |
| --- | --- | --- | --- |
| T1 | 红测 | `flutter test test/features/task/quick_add_batch_reminders_test.dart --concurrency=1` ⇒ 实现前 `+1 -3`（3 条断言级失败，不是编译错），实现后 `+4: All tests passed!`、`rc=0` | 完成 |
| T2 | helper | `git grep -n 'attachResolvedReminders' HEAD -- lib` ⇒ 定义 1 处 + 调用 2 处（`home_shell.dart`、`tasks_by_list_page.dart`） | 完成 |
| T3 | 失败语义 | 部分失败那条用例：`test/features/task/quick_add_batch_reminders_test.dart` 里「其中一条提醒写失败时其余照常落库，并一起报出成功数与失败数」—— 提醒行 2、任务行 3、消息同时含 2 与 1 | 完成 |
| T4 | 门禁 | 见下表（日志目录 `/tmp` 之外不留痕，读数抄在本表；复跑命令即本行给出的那条） | 见「三」 |

## 三、门禁读数（跑在最终字节上）

| 门 | 命令 | 读数 |
| --- | --- | --- |
| 1 | `git diff --check origin/develop..HEAD` | 见 PR 正文回填 |
| 2 | `dart format --output=none --set-exit-if-changed lib/features/task/quick_add_batch_reminders.dart lib/features/home/home_shell.dart lib/features/task/tasks_by_list_page.dart test/features/task/quick_add_batch_reminders_test.dart` | 见 PR 正文回填 |
| 3 | `flutter analyze` | 见 PR 正文回填 |
| 4 | `flutter test --tags golden` | 见 PR 正文回填（基线 9 张，不重录） |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | 见 PR 正文回填 |
| 6 | `flutter build web --release` | 见 PR 正文回填 |

> 表里写「见 PR 正文回填」是刻意的：本笔提交时门禁仍在跑，未跑完的格子**不许**填绿。
