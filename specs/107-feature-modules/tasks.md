# 任务：「设置 > 功能模块」开关（FL #574）

- [x] T001 落 specs/107 台账（判据源四句 + 反向那句现读）
- [x] T002 实现：仓储三件套（`getFeature`/`watchFeature`/`saveFeature`，键 `module.<枚举名>`，默认开）→ `featureModuleProvider` family → 设置页「功能模块」分区 → 视图档位菜单过滤 + 停当档时回落 → 番茄 dock 条件渲染 → 搜索入口与快捷键早退
- [x] T003 测试：`test/features/settings/feature_module_settings_test.dart` 7 例，`flutter analyze` 0 issue
- [x] T004 变异探针 ⑨⑩⑪ 各自红、还原 `cmp -s`（⑨档位菜单过滤去掉 → 四象限负向红；⑩dock 条件去掉 → 番茄负向红；⑪`saveFeature` 改整块覆盖 → 仓储第一条红）
- [x] T005 门禁：`dart format`（只跑本轮文件）、analyze 0 issue、全量 `flutter test` 跑在 commit 之后（1739 通过 / 26 跳过 / 1 失，失项是 FL #569 主干存量红，已在干净 develop `aa0c4b7606a2` 的独立 worktree 复现，日志 /tmp/fl-gate-285.log）
- [ ] T006 收口：push → PR（Refs #574）→ 合并 → #574 关单 → docs 矩阵 #35 翻「有」+ 同步六处 → docs PR → 父仓 bump
