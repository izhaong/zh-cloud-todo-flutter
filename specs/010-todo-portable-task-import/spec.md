# 010 Todo 可移植任务导入

## 目标

用户可从设置页选择便携 JSON 文件，将其中任务导入到本人已同步的普通清单；导入可追踪、可幂等重试，并可按批回滚。

## 输入契约

- 接受 B13 数据导出结构 `{data:{tasks:[...]}}` 与便携根结构 `{tasks:[...]}`。
- B13 数据导出记录来源 `ZH_CLOUD_EXPORT`，根级便携文件记录来源 `PORTABLE_JSON`。
- 兼容 `snake_case` 与 `camelCase`：`id/sourceTaskId`、`due_at/dueAt`、`completed_at/completedAt`。
- 映射标题、说明、截止时间、优先级和完成状态；空标题项在预览中计为忽略。
- 有效任务必须为 1～500 项；标题最长 255 字符，来源标识最长 128 字符。

## 交互契约

- 设置 → 任务 → 任务导入进入独立页面。
- 选择文件后展示文件名、可导入数量、忽略数量和目标清单。
- 每次选择文件生成一个请求 ID；同一文件在忙碌重试期间复用该 ID。
- `TODO_IMPORT_BUSY` 显示可重试提示，不生成新请求 ID。
- 目标清单须通过成员接口确认当前用户角色为 `owner`，共享成员清单不展示。
- 页面展示当前用户导入批次；未回滚批次经确认后可按批回滚。
- 导入或回滚成功后触发一次现有同步；同步失败不改变服务端操作结果，由既有重试机制继续处理。

## 后端契约

- `POST /app-api/todo/import-health/tasks`
- `GET /app-api/todo/import-health/task-batches`
- `POST /app-api/todo/import-health/rollback?batchId=...`
- 业务错误码 `1032022006` 表示相同导入请求正在处理。

## 验收

- API 契约、双格式解析、导入预览、稳定请求 ID、忙碌重试和批次回滚均有自动化测试。
- `flutter analyze`、全量 `flutter test`、`flutter build web --release` 通过。
