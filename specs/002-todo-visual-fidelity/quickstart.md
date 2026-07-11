# Quickstart: Todo 多端视觉高保真验收

本指南用于实施阶段验证，不连接真实后端，不创建真实用户数据。

## Prerequisites

- 从 `zh-cloud-todo-flutter` 仓库根目录执行命令。
- Flutter 版本与仓库 `pubspec.yaml` 兼容。
- 不设置真实账号、Token 或远端 API 环境变量。
- 视觉测试必须使用 `test/support/todo_visual_fixture.dart` 的内存数据库和固定数据。

## 1. Install dependencies

```bash
flutter pub get
```

Expected: command exits with code 0 and does not add a new production dependency for this feature.

## 2. Static analysis

```bash
flutter analyze
```

Expected: `No issues found!`

## 3. Verify workspace layout profiles

```bash
flutter test test/features/home/todo_workspace_layout_test.dart
```

Expected:

- 1440 width exposes `todo-rail`, `todo-sidebar`, `todo-content`, and `todo-detail`.
- 1280 width uses compact detail behavior defined by the UI contract.
- 1024 width moves sidebar/detail to their contracted containers.
- 390 and 360 widths use the mobile single-column shell.

## 4. Verify task selection and detail binding

```bash
flutter test \
  test/features/task/task_selection_test.dart \
  test/features/task/task_detail_pane_test.dart
```

Expected:

- Clicking task A selects A and renders A in detail.
- Clicking task B replaces both selection and detail content.
- Closing or invalidating the task clears detail safely.
- No test opens a real network connection.

## 5. Verify task-row density and contextual actions

```bash
flutter test \
  test/features/task/task_row_test.dart \
  test/features/task/task_row_hover_test.dart \
  test/features/shell/sidebar_test.dart \
  test/features/shell/quick_add_bar_test.dart
```

Expected:

- Unselected task rows have no independent Card surface or shadow.
- Hover/selected/focus states are distinguishable.
- Pin, drag and more actions are contextual rather than always visible.
- Desktop has one QuickAdd entry.

## 6. Run visual regression tests

```bash
flutter test test/visual/todo_workspace_golden_test.dart
```

Expected: all approved scenarios in `contracts/workspace-ui-contract.md` match files under `test/goldens/todo_workspace/`.

Only after a human approves an intentional visual change may baselines be regenerated:

```bash
flutter test --update-goldens test/visual/todo_workspace_golden_test.dart
```

After regeneration, inspect every changed PNG. Third-party reference screenshots must not be copied into `test/goldens/`.

## 7. Run full regression

```bash
flutter test
```

Expected: all existing and new tests pass. Any existing task, calendar, quadrant, timeline, collaboration or reminder regression blocks completion.

## Manual Acceptance Checklist

逐项完成 [visual-acceptance.md](./checklists/visual-acceptance.md)：每项 10 分，总分必须达到 90/100，且 V01、V03、V04、V07 四个关键门槛必须全部通过。把最终得分、失败项和对应截图文件记录到后续 PR/Issue 验收证据；不能用“golden 测试通过”替代人工评分。
