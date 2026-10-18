# 162 台账

## T1 改动

- [x] 档位表 + 文案映射 + 选中清 weekdays + repository 白名单 + wire 判据。

## T2 判据与探针

- [x] widget 2 条 + wire 2 条；**反向探针**（白名单拿掉）⇒ **2 红**。
- [x] 全量 `+2129 ~26`，0 失败；analyze 0 issue；format rc=0。

## 过程教训

1. **三层白名单要一起改**（UI 档位表/文案映射/repository 校验）—— 漏第三层时
   chip 选得上、保存被 `ArgumentError` 静默吞进 SnackBar，测试只见 0 行；
2. **判据红先 print 行数再猜手势**。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `task_repeat_ebbinghaus_test` | 2 条全绿 |
| `repeat_frequency_wire_test` | 5 条全绿 |
| 反向探针 | 2 红 |
| 全量（exclude golden/performance） | `+2129 ~26`，**0 失败** |
