# Tasks: Todo 登录界面视觉与易用性优化

**Input**: `specs/003-todo-auth-visual-polish/spec.md`、`plan.md`  
**Status**: Ready

- [ ] T001 新增登录页 Widget 测试基线，覆盖默认内容与现有四种认证模式
- [ ] T002 新增 `AuthBrandPanel`，实现宽屏“今日节奏”与移动端紧凑品牌头
- [ ] T003 在 900px 断点实现双栏/单栏自适应布局，覆盖 1440/900/390/320 宽度
- [ ] T004 将模式切换、标题、说明和主操作整理为单一表单卡片层级
- [ ] T005 增加密码显示/隐藏、autofill hints、键盘动作和稳定语义标签
- [ ] T006 统一加载、成功和错误反馈，未知异常不得暴露内部对象
- [ ] T007 覆盖深浅主题、200% 文本缩放、键盘焦点与无溢出回归
- [ ] T008 同步 `spec.md`，通过 format、analyze 与全量 test 并记录证据
