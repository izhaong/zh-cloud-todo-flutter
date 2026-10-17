# 155 计划

1. 确认服务端已带 `memberCount`（specs/054 切片二）⇒ 本地只需落库与映射。
2. 加列 + 迁移（`_columnExists` 守卫）+ `schemaVersion` 31。
3. pull 映射：先 `memberCount`，再 `member_count`，最后**保留旧值**，最后才是 1。
4. 判据两条（落库 / 缺键保留）+ 反向探针。
5. 判据接入查询（`task_query_repository`）写进边界，标注下一刀。
