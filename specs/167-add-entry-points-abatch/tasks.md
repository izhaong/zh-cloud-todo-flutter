# 167 台账

## T1 口径

- [x] A 批（快捷键 + 小组件「+」）+ A′（握姿探测）本轮做；B 批另单决策。

## T2 改动

- [x] 注册表 addTask 档 + 工作区 intent/handler + 握姿探测 + 深链判据。

## T3 判据与探针

- [x] 4 条判据；**探针**（注册表拿掉 addTask 档）⇒ 红。
- [x] 既有测试连带更新：combo 2 处、list 1 处、edit 1 处、sidebar 1 处（逐字计数）。
- [x] 全量 `+2150 ~26` 0 失败；analyze 0；format rc=0。

## 过程教训

1. SingleActivator 的 == 含 includeRepeats 默认值 —— 构造比较会假失败；
   用 toString 稳定描述（先探针确认注册表生成什么再断言）；
2. 新增枚举值 ⇒ 全仓穷尽 switch 编译红替你找全（keyboard_shortcut_list_test）；
3. 逐字计数断言的代价面：5 处计数全部强制过目。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `global_add_task_shortcut_test` | 4 条全绿 |
| 反向探针 | 红 |
| 既有 4 个测试文件连带更新后 | 全绿 |
| 全量（exclude golden/performance） | `+2150 ~26`，**0 失败** |
