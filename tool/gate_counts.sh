#!/usr/bin/env bash
# 读 `flutter test` 的输出，取整份日志里 `+N ~N -N` 三个计数的最大值。
#
# 为什么要有这把尺：compact reporter 只在非零时才打 `~N`/`-N`，且最后一行常常是
# 失败清单摘要或"还没并完"的那一拍 —— 直接读末行会把红读少（specs/117 那轮就把
# 5 条红读成 1 条）。
set -euo pipefail

if [[ "${1:-}" == "--selftest" ]]; then
  # 两条罐头样本：证这条尺能数出被省略的 ~/- 段，也能在"末行是摘要"时取到最大值。
  a=$(printf '00:01 +1 ~0 -0: a\n00:02 +12 ~3 -2: b\nSome tests failed\n' | bash "$0" /dev/stdin)
  b=$(printf '00:01 +8: All tests passed!\n' | bash "$0" /dev/stdin)
  [[ "$a" == "pass=12 skip=3 fail=2" ]] || { echo "SELFTEST FAIL(1): $a"; exit 1; }
  [[ "$b" == "pass=8 skip=0 fail=0" ]] || { echo "SELFTEST FAIL(2): $b"; exit 1; }
  echo "SELFTEST PASS"
  exit 0
fi

src="${1:-(读 stdin)}"
awk '
match($0, /\+[0-9]+( ~[0-9]+)?( -[0-9]+)?/) {
  s = substr($0, RSTART, RLENGTH)
  p = q = r = 0
  if (match(s, /\+[0-9]+/)) p = substr(s, RSTART + 1, RLENGTH - 1) + 0
  if (match(s, / ~[0-9]+/)) q = substr(s, RSTART + 2, RLENGTH - 2) + 0
  if (match(s, / -[0-9]+/)) r = substr(s, RSTART + 2, RLENGTH - 2) + 0
  if (p > P) P = p
  if (q > S) S = q
  if (r > F) F = r
}
END { printf "pass=%d skip=%d fail=%d\n", P, S, F }
' "$src"

