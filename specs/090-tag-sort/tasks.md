# 任务：任务按标签排序

- [x] `TaskSort` 追加 `tag` 档，枚举注释写明追加理由（name 序列化，末尾追加兼容存量行）
- [x] `compareTodoTasks` 增加 `taskTags` / `tagRank` 可选参数与 tag 分支（最小位次、末位哨兵）
- [x] `TaskQueryRepository.filter` 在 tag 档自建位次表（与 `TagRepository.watchAll` 同序，注释钉住两处同改）
- [x] 排序菜单：`_TaskWorkspaceHeaderCommand.tag` + 映射 + `'标签'` 文案 + onPressed 补 case；标签档无方向行
- [x] 页面穿线：位次表由 `tagsStreamProvider` 构建，进 `_visibleTasksInListOrder` 与 `_ListBody`
- [x] 测试 6 条落 `test/task_sort_direction_test.dart` 标签档组；种子反着种防恒真
- [x] 变异探针（tag 档恒 0）转红后还原，判据非恒假
- [x] 门禁：`flutter analyze` rc=0；全仓 `flutter test` rc=0
