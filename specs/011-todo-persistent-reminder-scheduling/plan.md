# 实施计划

1. 先以通知方法通道、轮询器和 Android Manifest 测试锁定持久调度契约。
2. 将本地通知服务的内存 Timer 替换为 `timezone` + `zonedSchedule`。
3. 将提醒轮询器改为按派发 ID 调度、改期和撤销。
4. 补齐 Android 通知权限、定时接收器与重启恢复接收器。
5. 完成定向测试、静态分析、全量测试和 Web release 构建。
