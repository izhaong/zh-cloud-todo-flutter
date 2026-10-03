/// 重复频率在「本地常量」与「服务端 wire 值」之间的映射。
///
/// 本地 `todo_repeat_rules.freq` 沿用大写常量（`DAILY`/`WEEKDAY`/…），服务端
/// `TodoRepeatFrequencyEnum.frequency` 是小写连字符（`daily`/`legal-workday`）。
/// 老档位都是单个词，`toLowerCase()` 刚好等价；从 `LEGAL_WORKDAY` 这档起不再成立
/// ⇒ 必须过这一层，否则出库发的是 `legal_workday`，服务端 `findByFrequency` 认不出来，
/// 入站 `.toUpperCase()` 又会把 `legal-workday` 存成带连字符的第三种写法，档位读不回来。
library;

String repeatFrequencyToWire(String local) =>
    local.trim().toLowerCase().replaceAll('_', '-');

String repeatFrequencyFromWire(Object? wire, {String fallback = 'DAILY'}) {
  final text = (wire ?? '').toString().trim();
  if (text.isEmpty) return fallback;
  return text.replaceAll('-', '_').toUpperCase();
}
