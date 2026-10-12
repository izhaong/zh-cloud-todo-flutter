# 任务与台账

| # | 任务 | 判据 | 状态 |
| --- | --- | --- | --- |
| T1 | 红测 | `flutter test test/features/task/quick_add_batch_reminders_test.dart --concurrency=1` ⇒ 实现前 `+1 -3`（3 条断言级失败，不是编译错），实现后 `+4: All tests passed!`、`rc=0` | 完成 |
| T2 | helper | `git grep -n 'attachResolvedReminders' HEAD -- lib` ⇒ 定义在 `lib/features/task/quick_add_batch_reminders.dart`，调用两处，分别是 `lib/features/home/home_shell.dart` 与 `lib/features/task/tasks_by_list_page.dart` | 完成 |
| T3 | 失败语义 | 部分失败那条用例：`test/features/task/quick_add_batch_reminders_test.dart` 里「其中一条提醒写失败时其余照常落库，并一起报出成功数与失败数」—— 提醒行 2、任务行 3、消息同时含 2 与 1 | 完成 |
| T5 | 接线判据 | `test/features/home/quick_add_batch_reminders_wiring_test.dart` —— 泵真 `HomeShell`，在真 `QuickAddBar` 里输入三行（两行带「明天9点」）并提交，断言任务 3 行、提醒 2 行、每条提醒的 `remindAt` 等于其任务的 `dueAt` | 完成 |
| T6 | 反向探针 | 摘掉 `home_shell.dart` 里那次 `attachResolvedReminders` 调用后复跑 T5 ⇒ `rc=1`（红）；还原后 `git status --porcelain lib` 为空 ⇒ 接线确有判据，不是「helper 绿就算数」 | 完成 |
| T4 | 门禁 | 六道读数全在下方「三」表，且都跑在最终字节上；跑完 `git status --porcelain` 为空（`pubspec.lock` 未动） | 完成 |

## 三、门禁读数（跑在最终字节上）

| 门 | 命令 | 读数 |
| --- | --- | --- |
| 1 | `git diff --check origin/develop..HEAD` | 无输出、`rc=0` |
| 2 | `dart format --output=none --set-exit-if-changed` 对本笔 5 个文件 | `Formatted 5 files (0 changed)`、`rc=0`（第一次跑是 `rc=1` 且报本文件 Changed，已按 formatter 收齐后复跑） |
| 3 | `flutter analyze` | `No issues found!`、`rc=0`（首跑 `rc=1` 报 unused_import，摘掉多余 import 后复跑） |
| 4 | `flutter test --tags golden` | `+9: All tests passed!`、`rc=0` ⇒ 9 张基线一张未重录 |
| 5 | `flutter test --exclude-tags 'golden 或 performance' --concurrency=1` | `+1319 ~26: All tests passed!`、`rc=0`（终头实跑；`develop` 基线 `+1314 ~26` ⇒ 本笔新增 5 条用例） |
| 6 | `flutter build web --release`（带 test 域名与租户两个 dart-define） | `✓ Built build/web`、`rc=0` |

> 门禁 2/3 的**首跑是红的**（本文件未格式化、多余 import），先修再复跑，不是拿旧读数交差；
> develop 全仓 `dart format` 另有 11 个文件为红（FL #430），与本笔无关，未顺手格式化。
