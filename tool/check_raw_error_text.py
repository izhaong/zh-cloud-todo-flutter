#!/usr/bin/env python3
"""用户可见文案里不得出现异常原文。

判据（扫 lib/**/*.dart，跳过 *.g.dart 与本判据自身）：
  A. 把异常对象插进字符串：`'$e'`、`'${error}'`、`'${s.error}'` —— 未经 describeError 包裹判红。
  B. `error.toString()` 这类取异常原文的写法（error_text.dart 之外）判红。

用法：
    python3 tool/check_raw_error_text.py [paths...]     # 默认扫 lib
    python3 tool/check_raw_error_text.py --selftest     # 证明这两条判据真会红
"""

import os
import re
import sys

HELPER = os.path.join("lib", "core", "api", "error_text.dart")
INTERP = re.compile(r"\$\{?([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\}?")
WRAPPED = re.compile(r"\bdescribeError\([^()]*\)")
ERRISH = re.compile(r"(^|\.)(e|err|error|exception)$")
TOSTRING = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\.toString\(\)")

REASON_A = "异常对象被插进文案，未经 describeError 转换"
REASON_B = "取了异常原文 toString()，不得进用户可见文案"


def is_error_path(expr):
    return bool(ERRISH.search(expr))


def findings_for(text):
    """Return [(line_no, reason, snippet)] for one file's source."""
    out = []
    for num, line in enumerate(text.split("\n"), 1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("///"):
            continue
        residue = WRAPPED.sub("", line)
        for m in INTERP.finditer(residue):
            if is_error_path(m.group(1)):
                out.append((num, REASON_A, stripped[:90]))
                break
        for m in TOSTRING.finditer(residue):
            if is_error_path(m.group(1)):
                out.append((num, REASON_B, stripped[:90]))
                break
    return out


def scan(paths):
    findings = []
    scanned = 0
    for root_path in paths:
        if os.path.isfile(root_path):
            walk_files = [(os.path.dirname(root_path) or ".", [os.path.basename(root_path)])]
        else:
            walk_files = []
            for root, dirs, files in os.walk(root_path):
                dirs[:] = [d for d in dirs if d not in ("build", ".dart_tool")]
                walk_files.append((root, files))
        for root, files in walk_files:
            for fn in sorted(files):
                if not fn.endswith(".dart") or fn.endswith(".g.dart"):
                    continue
                path = os.path.join(root, fn)
                if os.path.normpath(path) == os.path.normpath(HELPER):
                    continue
                scanned += 1
                with open(path, encoding="utf-8") as fh:
                    for num, reason, snippet in findings_for(fh.read()):
                        findings.append((path, num, reason, snippet))
    return findings, scanned


BAD_SAMPLE = """
class _Page extends StatelessWidget {
  Widget build(BuildContext context) {
    return Text('加载标签失败: $e');
  }
}
"""
BAD_TOSTRING_SAMPLE = """
void _load() {
  setState(() => _error = error.toString());
}
"""
GOOD_SAMPLE = """
class _Page extends StatelessWidget {
  Widget build(BuildContext context) {
    return Text('加载标签失败: ${describeError(e)}');
  }
}
"""


def selftest():
    ok = True
    bad = findings_for(BAD_SAMPLE)
    if not any(r == REASON_A for _, r, _ in bad):
        ok = False
        print("  x 判据 A 没抓到未包裹的 $e 插值")
    bad2 = findings_for(BAD_TOSTRING_SAMPLE)
    if not any(r == REASON_B for _, r, _ in bad2):
        ok = False
        print("  x 判据 B 没抓到 error.toString()")
    good = findings_for(GOOD_SAMPLE)
    if good:
        ok = False
        print("  x 判据把 describeError(e) 误判成失项: %r" % (good,))
    print("SELFTEST %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    args = sys.argv[1:]
    if "--selftest" in args:
        return selftest()
    paths = [a for a in args if not a.startswith("-")] or ["lib"]
    findings, scanned = scan(paths)
    for path, num, reason, snippet in findings:
        print("  x %s:%d %s ｜ %s" % (path, num, reason, snippet))
    print("已扫 %d 个 .dart 文件，失项 %d" % (scanned, len(findings)))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
