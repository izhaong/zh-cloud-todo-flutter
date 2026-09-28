# 047 · 实施计划（# 快速创建标签）

范围裁定见 `spec.md`；验收与证据见 `tasks.md`。

1. **词法层**（`lib/features/tag/hash_tag_input.dart`）
   `parseHashTagInput` 纯函数：按行扫描，`#` 在行首或空白后、后面不是空白也不是 `#` 才算 token，
   token 到下一个空白结束；只有真剥掉 token 的行才收拢空白（其余行原样）。
   用例：`test/features/tag/hash_tag_input_test.dart` 的 `parseHashTagInput` 8 条。
2. **落地层**（同文件）`resolveTagIdsByName`：`getAll()` 已按 `createdAt` 升序 ⇒
   trim 后逐字命中就用它，否则 `create`；同名多行取最早一条。6 条用例跑真 Drift（`NativeDatabase.memory()`）。
3. **接线层**（`lib/features/shell/quick_add_bar.dart`）
   新增 `QuickAddTagIdsEnsurer` 回调 + `_buildHashTagRequest`/`_hashTagNamesOf`/`_openTagPickerSheet`
   三个私有件，被移动弹层与桌面输入条共用；标签弹层收成 `_TagPickerSheet`（`StatefulWidget`）。
   **为什么不是 mixin/继承**：两处的状态形状不同（一个用 `onChanged`、一个用 controller listener），
   抽公共基类要为 6 行重复引入一层看不见的间接；共用的是自由函数，不共享状态。
4. **页面只提供能力**（`lib/features/task/tasks_by_list_page.dart`）
   `_ensureTagIdsByName` 用 `tagRepositoryProvider`；`home_shell` 的提交分支、
   `TaskRepository.createBatch` 签名都不动 ⇒ 相撞面小（见 tasks.md）。
5. **首版踩过的两个坑**（已改，记录在 tasks.md 的探针节）
   - 标签弹层第一版用 `showModalBottomSheet` + 闭包局部状态 + 函数末尾 `nameCtrl.dispose()`
     ⇒ 弹层退出动画期间仍会重建 ⇒ `A TextEditingController was used after being disposed`；
     成功建完收起输入行时又撞 `_FocusInheritedScope` 断言 ⇒ 改成 `StatefulWidget` 自持 controller，
     并在移除带焦点的输入框前 `unfocus()`。
   - 计数在 320px + 1.3 倍下把操作行撑溢出 31px ⇒ `Row + Spacer` 改 `Wrap`。
