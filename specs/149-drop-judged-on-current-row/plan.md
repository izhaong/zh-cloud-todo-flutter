# 149 计划

1. 先确认 skip 发生在哪一层：读 `SidebarDropZone` 与 `sidebar.dart` 的接法。
   发现 `onWillAcceptWithDetails` 是同步闸门 ⇒ 只改控制器无效。
2. 控制器加必填 `loadTask` 接缝；两个落点的判据移进 operation、按当前行算。
3. `_serialize` 改成能带出落点自己算出的 outcome。
4. 悬停对齐标签落点：`accept: (_) => true`。
5. 判据成对（会写的 / 不会写的），再跑反向探针确认判别力。
6. 门禁：analyze / format / 定向回归 / 全量。
