# B1 验收旅程

1. 禁网启动应用，快速添加“明天 10 点 写周报”，确认解析并覆盖默认清单。
2. 粘贴三行（含空行），确认只创建非空任务；重启后所有有效任务仍在。
3. 在详情编辑 Markdown、标签和检查事项，离开再返回确认聚合一致。
4. 添加附件并模拟失败，检查 failed、retry 和 delete；恢复网络后确认仅成功上传一次。
5. 运行 B1 的 Service、Repository、Widget、契约测试以及 `flutter analyze` 和完整 `flutter test`。
