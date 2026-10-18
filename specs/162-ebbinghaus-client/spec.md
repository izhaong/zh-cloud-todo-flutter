# 162 · 艾宾浩斯档位的客户端接线（FL #326 客户端半，service !416）

## 判据源

《10-设置重复任务.md》`:105`「重复周期按照 1，2，4，7，15，15，15…… 循环」。
阶梯命中哪天由服务端算（`isEbbinghausOffset` 纯函数），客户端只做「能选、能存、能读回中文」。

## 改动

1. 档位表（`ChoiceChip` Wrap）加 `('EBBINGHAUS', '艾宾浩斯')`，位置在「法定节假日」与「自定义」之间；
2. `_repeatRuleLabel` 文案映射加 `'EBBINGHAUS': '艾宾浩斯'`（漏一档会把枚举名直接印给用户）；
3. 选中时清空 `weekdays`（阶梯 offset 内生于档位，服务端 v1 带 weekdays 就拒；保存路径本就只为 CUSTOM 派生星期集，双保险）；
4. **`repeat_rule_repository` 的频率白名单加 `EBBINGHAUS`** —— 本刀真正咬住的一处（见下）；
5. wire 层双向判据（`EBBINGHAUS ⇄ ebbinghaus`）与未知值兜底。

## 判据（4 条）

| 判据 | 钉什么 |
| --- | --- |
| widget：档位表里有「艾宾浩斯」chip，选它保存 ⇒ `repeat_rules.freq='EBBINGHAUS'` 且 `byDay` 为 null（不带星期集） | 档位入口 + v1 上行契约 |
| widget：保存后读回「艾宾浩斯」且**不出现裸枚举** `EBBINGHAUS` | 文案表 |
| wire：`toWire('EBBINGHAUS')=='ebbinghaus'` 且 `fromWire('ebbinghaus')=='EBBINGHAUS'` | service !416 的 wire 契约 |
| wire：未知值兜底（`null`/`''` ⇒ `DAILY`；`'future-mode'` ⇒ `FUTURE_MODE` 不炸） | 老客户端前向兼容 |

**反向探针**：把白名单里的 `EBBINGHAUS` 拿掉 ⇒ **两条 widget 判据红**（保存被 `ArgumentError` 拦下，`repeat_rules` 0 行）。

## 过程教训

**widget 测试的"0 行"要往 Snackbar 那头查**：保存失败不是异常冒出来，而是调用方
`on ArgumentError catch` 弹了个 SnackBar 就吞掉 —— 测试里看不到。
**三层白名单**（UI 档位表 / 文案映射 / repository 校验）加新档时要**一起**改，
漏哪一层就是"看得见选不上"（本刀漏了第三层，判据当场红）。
判据红时先加一行 debug print 看落库行数，比猜 widget 手势快得多。

## 边界

- ON_COMPLETE 版（步号状态 + 迟到漂移）—— 服务端 v1 不含，客户端无入口；
- 档位表在窄屏/大字下的滚动手势沿用 `_revealChip`（与 legal 测试同法）。
