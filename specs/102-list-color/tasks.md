# 任务：清单「颜色」属性端到端（FL #339）

- [x] T001 落 specs/102 台账（本文件 + spec.md；判据源镜像 `02-用清单管理任务.md:73` 现读确认）
- [x] T002 TDD 红：三个测试文件先写（仓储 3 用例 + 编辑器 3 用例 + 侧栏 2 用例），色板 key 未实现时恰红
- [x] T003 绿：`list_color.dart`（色板 + 解析）→ 仓储 `create` 接 color + `setColor` → 编辑器色板 + `_save` 透传 → 侧栏 `_SidebarRow.iconColor`
- [x] T004 变异探针 4 条各自红、还原 `cmp -s`（见 spec「测试与探针」）
- [ ] T005 门禁：`dart format`、analyze 0 issue、全量 `flutter test`（commit 后跑，日志 /tmp/fl339-gate.log）
- [ ] T006 收口：push → PR → 合并 → #339 留言（颜色已落地、剩 Emoji）→ docs 矩阵 #19 ⑦ 追记 → 父仓 bump
