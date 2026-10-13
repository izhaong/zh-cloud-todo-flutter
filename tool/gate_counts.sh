#!/usr/bin/env bash
# 读一份 `flutter test` 日志，报三件事：
#   last      = 最后一条进度行的 pass/skip/fail（跑完之后这才是权威数）
#   max       = 整份日志里这三段计数的最大值
#   complete  = 有没有终止标记（`All tests passed!` 或 `Some tests failed.`）
#
# 为什么要有这把尺：compact reporter 只在计数非零时才打 `~N`/`-N`，
# 而"读一眼最后一行"会在进程还没写完时读到一个中途的拍 —— 那不是结论
# （specs/117 那轮把 5 项存量红读成 1 项，就是这么来的）。
# last 与 max 不等 ⇒ 日志里混了不止一次运行，别拿 last 当整份日志的数。
set -euo pipefail

if [[ "${1:-}" == "--selftest" ]]; then
  t1=$(printf '00:01 +1 ~0 -0: a\n00:02 +12 ~3 -2: b\n00:03 +12 ~3 -2: Some tests failed.\n' | bash "$0" /dev/stdin)
  [[ "${t1%%complete*}" == "last=12/3/2 max=12/3/2 " && "${t1#*complete=}" == "yes" ]] || { echo "SELFTEST FAIL(1 省略段与终止标记): $t1"; exit 1; }

  t2=$(printf '00:01 +8: All tests passed!\n' | bash "$0" /dev/stdin)
  [[ "${t2%%complete*}" == "last=8/0/0 max=8/0/0 " && "${t2#*complete=}" == "yes" ]] || { echo "SELFTEST FAIL(2 零值段): $t2"; exit 1; }

  # 两次运行拼在一起：last 只能是第二次，max 会留在第一次的峰值 ⇒ 必须标不等
  t3=$(printf '00:01 +5 ~0 -0: x\n00:02 +5 ~0 -0: Some tests failed.\n00:01 +2 ~0 -1: y\n00:02 +2 ~0 -1: Some tests failed.\n' | bash "$0" /dev/stdin)
  [[ "${t3%%complete=*}" == "last=2/0/1 max=5/0/1 " && "${t3#*complete=}" == "yes  (last!=max：日志里混了不止一次运行)" ]] || { echo "SELFTEST FAIL(3 拼接日志): $t3"; exit 1; }

  # 没写完的日志：没有终止标记 ⇒ complete=no（这正是要挡的那种读法）
  t4=$(printf '00:01 +1934 ~26 -5: 还在跑\n' | bash "$0" /dev/stdin)
  [[ "${t4#*complete=}" == "no" ]] || { echo "SELFTEST FAIL(4 未跑完): $t4"; exit 1; }

  echo "SELFTEST PASS"
  exit 0
fi

src="${1:--}"
awk '
match($0, /\+[0-9]+( ~[0-9]+)?( -[0-9]+)?/) {
  s = substr($0, RSTART, RLENGTH)
  p = q = r = 0
  if (match(s, /\+[0-9]+/)) p = substr(s, RSTART + 1, RLENGTH - 1) + 0
  if (match(s, / ~[0-9]+/)) q = substr(s, RSTART + 2, RLENGTH - 2) + 0
  if (match(s, / -[0-9]+/)) r = substr(s, RSTART + 2, RLENGTH - 2) + 0
  lp = p; lq = q; lr = r
  if (p > P) P = p
  if (q > S) S = q
  if (r > F) F = r
}
/All tests passed!|Some tests failed\./ { done = 1 }
END {
  flag = (lp == P && lq == S && lr == F) ? "" : "  (last!=max：日志里混了不止一次运行)"
  printf "last=%d/%d/%d max=%d/%d/%d complete=%s%s\n", lp, lq, lr, P, S, F, (done ? "yes" : "no"), flag
}
' "$src"
