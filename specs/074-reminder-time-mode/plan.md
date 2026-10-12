# 计划：提醒侧时间模式三档

## 落点

| 层 | 改动 | 位置 |
| --- | --- | --- |
| 本地库 | 提醒表加 `time_mode` 列（默认 0），`schemaVersion` 由 23 进到 24 | `lib/core/db/app_database.dart:232`、`lib/core/db/app_database.dart:444` |
| 迁移 | v23→v24 加列并回填 `fixed_timezone = 1 → time_mode = 2` | `lib/core/db/app_database.dart:685`、`lib/core/db/app_database.dart:691` |
| 仓储 | `create` / `update` 收 `timeMode` 入参，缺省时按旧布尔位推导；写库同时写档位与派生布尔位 | `lib/state/repositories/reminder_repository.dart:33`、`lib/state/repositories/reminder_repository.dart:91` |
| 出站 | 同步 payload 带 `timeMode` | `lib/state/repositories/reminder_repository.dart:201` |
| 界面 | 「固定时区」开关换成按档位编号的单选组，副标题照抄嘀嗒措辞 | `lib/features/task/task_detail_pane.dart:451`、`lib/features/task/task_detail_pane.dart:108` |
| 写库通路 | 草稿里的档位传给仓储的更新调用 | `lib/features/task/task_detail_pane.dart:278` |

## 顺序

1. 先做红测：档位选择 → 写库 → 出站，这条链在没有实现时必须判红。
2. Drift 加列 + 迁移回填，跑 `build_runner` 重生成 `app_database.g.dart`。
3. 仓储收参数：档位优先，缺省回落到 `TaskTimeMode.fromLegacyFlag`。
4. 界面换控件，保留既有校验（选了固定档仍要求 IANA 时区非空）。
5. 补迁移回填用例与窄屏用例，六道门禁在最终字节上各跑一次。

## 风险

- 把布尔位换成单选组会动到既有显隐用例的 key：`reminder_timezone_gate_test.dart` 里的
  `_fixedTimezoneRow` 必须跟着改成档位 key，否则它判的就不再是「固定时区」这一档。
- 迁移回填只在「列不存在」这条分支里执行，重复打开同一个库不得二次改写。
