# Tasks: Todo 清单 Section

- [x] T001 Drift schema 22 增加 Section 表与任务外键
- [x] T002 新增 Section Repository 与 Provider
- [x] T003 扩展任务创建、复制和更新的 Section 合同
- [x] T004 接入 push/pull/bootstrap/tombstone 和临时 ID
- [x] T005 修复跨页父清单后到时的 Section 暂存
- [x] T006 增加工作区管理条和任务“移动到分组”
- [x] T007 覆盖 Repository、同步和 Widget 测试
- [x] T008 使用 Claude CLI 完成只读交叉评审并处理有效发现
- [ ] T009 完成真实服务端双设备同步与真机交互验收

## 执行证据

- 2026-08-01：补齐分组后首次跑全部 9 张已批准工作区黄金图，定位到“没有 Section 也常驻 44px 管理条”使 8 个列表场景整体下移。未重录基线：先用 Widget 红测冻结“空 Section 不占列表高度”，再把创建首个分组收进已有排序/批量菜单，已有 Section 时仍显示管理条并保留新建、改名、排序和删除。分组工作区 2 项与 9 张原黄金图全部通过，基线图片零修改；全量非 golden/非性能测试 625 项通过、26 项受保护 live 用例跳过，`flutter analyze` 无问题，Web release 构建成功。
