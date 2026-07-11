# Todo 登录界面视觉与易用性优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变认证接口与会话行为的前提下，把现有登录页改造成具有 Todo 产品识别度、响应式且可访问的跨平台入口。

**Architecture:** `TodoAuthPage` 继续拥有四种认证模式、控制器与提交状态；新增无业务依赖的 `AuthBrandPanel` 负责宽屏“今日节奏”和窄屏品牌头。页面通过 `LayoutBuilder` 在 900px 切换双栏/单栏，表单仍使用现有 `AuthGateway` 与 `sessionProvider`。

**Tech Stack:** Flutter Material 3、flutter_riverpod、flutter_test；不新增依赖或外部资产。

## Global Constraints

- 不修改认证 API、请求字段、Session 持久化或 go_router 行为。
- 不增加第三方登录、二维码登录、隐私协议流程或新的注册字段。
- 复用 `AppColors`、`AppSpacing`、`AppRadius` 与当前 ThemeData。
- 320px 宽度不得横向溢出；交互控件触控高度至少 48px。
- 测试必须使用 Fake `AuthGateway`，不得访问真实后端。
- 保留 `todo-auth-submit`、`todo-auth-register-link`、`todo-auth-forgot-password-link` 等现有稳定 Key。

---

## File Map

- Create `lib/features/auth/widgets/auth_brand_panel.dart`: 纯展示的宽屏任务节奏与移动品牌头。
- Modify `lib/todo_auth_page.dart`: 响应式壳、表单视觉层级、文案、密码显隐、autofill 和反馈。
- Create `test/features/auth/todo_auth_page_test.dart`: 登录页响应式、模式与可访问性回归。
- Modify `test/widget_test.dart`: 保留应用路由冒烟，更新默认标题断言。
- Modify `spec.md`: 记录登录表现层的最新能力与 003 规格链接。
- Create `specs/003-todo-auth-visual-polish/tasks.md`: 任务完成证据。

### Task 1: 锁定现有行为与新交互契约

**Files:**
- Create: `test/features/auth/todo_auth_page_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TodoAuthPage`, `authGatewayProvider`, `sessionStoreProvider`。
- Produces: 稳定 Finder 契约 `todo-auth-wide-layout`、`todo-auth-compact-layout`、`todo-auth-password-visibility`。

- [ ] **Step 1: 写失败测试**

新增测试辅助函数，以 `ProviderScope` + `MaterialApp` 直接渲染 `TodoAuthPage`，并用 `tester.view.physicalSize` 覆盖 1440、900、390、320 宽度。断言：

```dart
expect(find.byKey(const ValueKey('todo-auth-wide-layout')), findsOneWidget);
expect(find.text('把今天安排得更清楚'), findsOneWidget);
expect(find.text('欢迎回来'), findsOneWidget);
expect(find.byKey(const ValueKey('todo-auth-password-visibility')), findsOneWidget);
```

窄屏断言：

```dart
expect(find.byKey(const ValueKey('todo-auth-compact-layout')), findsOneWidget);
expect(find.byKey(const ValueKey('todo-auth-wide-layout')), findsNothing);
expect(tester.takeException(), isNull);
```

模式与显隐断言：点击 `todo-auth-password-visibility` 后，密码字段的 `obscureText` 从 `true` 变为 `false`；点击“验证码”“注册”“忘记密码”后分别出现批准文案和对应字段。

- [ ] **Step 2: 确认测试按预期失败**

Run: `flutter test test/features/auth/todo_auth_page_test.dart test/widget_test.dart`

Expected: FAIL，原因是新布局 Key、文案与密码显隐按钮尚不存在。

- [ ] **Step 3: 提交测试红灯基线**

```bash
git add test/features/auth/todo_auth_page_test.dart test/widget_test.dart
git commit -m "test(auth): 定义登录页视觉交互契约"
```

### Task 2: 构建 Todo 品牌面板与响应式壳

**Files:**
- Create: `lib/features/auth/widgets/auth_brand_panel.dart`
- Modify: `lib/todo_auth_page.dart`
- Test: `test/features/auth/todo_auth_page_test.dart`

**Interfaces:**
- Produces: `AuthBrandPanel({required bool compact})`。
- Consumes: `Theme.of(context)` 与 `AppThemeExtension`，不依赖 Provider 或认证状态。

- [ ] **Step 1: 实现品牌面板**

组件公开签名固定为：

```dart
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key, required this.compact});
  final bool compact;
}
```

宽屏展示品牌标识、“把今天安排得更清楚”、一句说明与三项“今日节奏”；紧凑模式只展示标识、产品名和一句说明。任务状态只使用 `Icons.check_rounded`、`Icons.radio_button_checked`、`Icons.circle_outlined`，不加入图片资产。

- [ ] **Step 2: 实现响应式壳**

在 `TodoAuthPage.build` 使用 `LayoutBuilder`：`constraints.maxWidth >= 900` 时返回 Key 为 `todo-auth-wide-layout` 的双栏 `Row`，否则返回 Key 为 `todo-auth-compact-layout` 的单栏。两者均放在 `SafeArea` 与 `SingleChildScrollView` 内；表单 `ConstrainedBox(maxWidth: 420)`。

- [ ] **Step 3: 运行响应式测试**

Run: `flutter test test/features/auth/todo_auth_page_test.dart --plain-name "响应式"`

Expected: PASS，1440/900 为双栏，390/320 为单栏且无 overflow。

- [ ] **Step 4: 提交布局**

```bash
git add lib/features/auth/widgets/auth_brand_panel.dart lib/todo_auth_page.dart test/features/auth/todo_auth_page_test.dart
git commit -m "feat(auth): 构建自适应登录入口"
```

### Task 3: 优化表单交互、文案与反馈

**Files:**
- Modify: `lib/todo_auth_page.dart`
- Test: `test/features/auth/todo_auth_page_test.dart`

**Interfaces:**
- Preserves: `_AuthMode { password, sms, register, forgotPassword }` 与所有 `AuthGateway` 调用。
- Produces: `todo-auth-password-visibility`、动态语义标签“显示密码”/“隐藏密码”。

- [ ] **Step 1: 把模式切换器移入表单卡片**

密码和短信登录共享卡片头；标题/说明固定为：

```dart
final title = switch (_mode) {
  _AuthMode.password => '欢迎回来',
  _AuthMode.sms => '验证码登录',
  _AuthMode.register => '创建 Todo 账号',
  _AuthMode.forgotPassword => '重置密码',
};
```

说明分别为“登录后继续安排任务与日程”“输入手机号，我们会发送登录验证码”“验证手机号后即可开始使用”“验证手机号并设置新密码”。

- [ ] **Step 2: 增加密码显隐与 autofill**

新增 `_obscurePassword = true`。密码字段使用 `obscureText: _obscurePassword`、登录态 `AutofillHints.password`、重置态 `AutofillHints.newPassword`；尾部 `IconButton` 使用 Key `todo-auth-password-visibility`，tooltip/semantic label 随状态切换。手机号与验证码分别使用 `AutofillHints.telephoneNumber`、`AutofillHints.oneTimeCode`。

- [ ] **Step 3: 收敛反馈文案**

`_AuthMessage` 增加状态图标与 `Semantics(liveRegion: true)`。未知异常统一为“暂时无法完成请求，请稍后重试”，不得拼接 `$error`；`TodoAuthException.message` 继续展示后端可读业务提示。

- [ ] **Step 4: 运行交互测试**

Run: `flutter test test/features/auth/todo_auth_page_test.dart`

Expected: PASS，四模式、密码显隐、autofill、反馈语义和响应式全部通过。

- [ ] **Step 5: 提交交互优化**

```bash
git add lib/todo_auth_page.dart test/features/auth/todo_auth_page_test.dart
git commit -m "feat(auth): 优化登录表单交互反馈"
```

### Task 4: 同步规格并完成全量验证

**Files:**
- Modify: `spec.md`
- Modify: `specs/003-todo-auth-visual-polish/tasks.md`

**Interfaces:**
- Produces: 仓库总览中的 003 能力说明与可复核验证记录。

- [ ] **Step 1: 更新仓库规格与任务状态**

在 `spec.md` 登录章节增加 003 链接与响应式/可访问性能力说明；在 `tasks.md` 勾选通过的任务并记录实际命令结果。

- [ ] **Step 2: 格式与静态检查**

Run: `dart format --output=none --set-exit-if-changed lib test`

Expected: `Changed 0 files`。

Run: `flutter analyze`

Expected: `No issues found!`。

- [ ] **Step 3: 全量测试**

Run: `flutter test`

Expected: 所有测试通过，0 failures。

- [ ] **Step 4: 提交文档与验证证据**

```bash
git add spec.md specs/003-todo-auth-visual-polish/tasks.md
git commit -m "docs(spec): 完成登录界面优化验收"
```

- [ ] **Step 5: 推送当前功能分支**

Run: `git push origin feat/87-todo-auth-visual-polish`

Expected: 远端分支更新到本地 HEAD；现有 PR #86 自动包含新增提交。
