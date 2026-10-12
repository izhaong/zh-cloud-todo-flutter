# Tasks: Todo 登录界面视觉与易用性优化

**Input**: `specs/003-todo-auth-visual-polish/spec.md`、`plan.md`  
**Status**: Complete

- [x] T001 新增登录页 Widget 测试基线，覆盖默认内容与现有四种认证模式
- [x] T002 新增 `AuthBrandPanel`，实现宽屏“今日节奏”与移动端紧凑品牌头
- [x] T003 在 900px 断点实现双栏/单栏自适应布局，覆盖 1440/900/390/320 宽度
- [x] T004 将模式切换、标题、说明和主操作整理为单一表单卡片层级
- [x] T005 增加密码显示/隐藏、autofill hints、键盘动作和稳定语义标签
- [x] T006 统一加载、成功和错误反馈，未知异常不得暴露内部对象
- [x] T007 覆盖深浅主题、200% 文本缩放、键盘焦点与无溢出回归
- [x] T008 同步 `spec.md`，通过 format、analyze 与全量 test 并记录证据

## 验收证据（2026-07-12）

- `dart format --output=none --set-exit-if-changed lib test`：102 files，0 changes。
- `flutter analyze`：No issues found。
- `flutter test`：173/173 passed。
- 登录专项：9/9 passed，覆盖 1440/900/390/320、自适应布局、四种模式、密码显隐、autofill、未知异常脱敏、动态语义播报、深色主题、200% 文本缩放与 Tab 焦点。
- Playwright 实图检查：1440×900 桌面双栏垂直居中、390×844 移动单栏均无裁切或横向溢出；临时截图与浏览器产物未纳入仓库。
