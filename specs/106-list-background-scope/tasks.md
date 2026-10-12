# 任务：清单背景的两面偏差收口（FL #572）

- [x] T001 落 specs/106 台账（判据源 `:100`/`:111` 现读，交叉验证口径承接 specs/105）
- [x] T002 实现：装饰层从 modeBody 提到整根 `bareWorkspace`（key `todo-list-background-surface`）+ 图片档「从相册选择」（`pickImage`/`uploadImage` 可注入，默认 `FilePicker` + `DioAttachmentUploadApi.uploadFile`）
- [x] T003 测试：`test/features/list/list_background_scope_picker_test.dart` 3 例（含"默认无装饰层"控制组），`flutter analyze` 0 issue
- [ ] T004 变异探针 ⑥⑦⑧ 各自红、还原 `cmp -s`（见 spec「测试与探针」）
- [ ] T005 门禁：`dart format`（只跑本轮文件）、analyze 0 issue、全量 `flutter test` 跑在 commit 之后（日志 /tmp/fl-gate-284.log）
- [ ] T006 收口：push → PR（Refs #572）→ 合并 → #572 留言关单 → docs 矩阵 #19 翻「有」+ 追记 → docs PR → 父仓 bump FL 指针
