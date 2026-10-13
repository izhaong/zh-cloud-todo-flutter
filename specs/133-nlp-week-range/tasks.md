# 133 台账

## T1 正则

- `lib/state/nlp_date.dart`：五个新模式插在绝对日期之后、明天之前。
- 周X/下周X 的 delta 简化为 `(target - weekday) % 7`（Dart % 恒非负），
  同日推下周（delta==0 → 7）；`下?` 组在 Dart 中未命中时是 `''` 而非
  `null`（跟 JS 不一样），`(group(1) ?? '').isNotEmpty` 才判得准。
- 绝对日期的时间取 `now.hour` 是 origin/develop 现状（现状锁）。

## T2 用例（test/nlp_date_week_range_test.dart，17 条）

- 周X 3 / 下周X 2 / N天后 3（含 0天后非法）/ 大后天 1 / 月底 2（含非闰年
  2 月）/ 不回归 4（明天/今天下午/绝对日期/后天带时间）/ 优先级 2。

## 存量用例更新

- `nlp_date_bare_time_test.dart` 「3天后再说」原钉 null（现状锁——当时
  未扩面），specs/133 后改为 `isNotNull` 并登记理由。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format | 0 changed |
| 全量 | `+2050 ~26 -1`（唯一红 #569 存量） |
