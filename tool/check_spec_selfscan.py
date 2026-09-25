#!/usr/bin/env python3
"""规格台账（`specs/<NNN>/tasks.md`）的散文自证检查器。

为什么要有这个文件：第 77 轮连着四轮判我同一类账 ——「把统计行叫末行」「一句话的全称唯一性」
「量词不给枚举」。前三次我的修法是把判据**写进 markdown 散文**，而散文里的判据既要人读、又会随
下一笔编辑漂，等于没修。这个脚本把三条判据落成可复跑的东西，并要求它**在一份已知有错的基线上
真的会红**（`--selftest` 就是干这个的）。

用法：
    python3 tool/check_spec_selfscan.py [--selftest] <specs/**/tasks.md>
退出码：0 = 三条都干净；1 = 有失项（逐条打印 文件:行号 与原因）；2 = 用法/读文件错误。
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

# `foo.log:1137` / `specs/x/tasks.md:120` 这类跨文件锚点
REF = re.compile(r"[A-Za-z0-9_./-]+\.(?:log|md|dart|txt|py):(\d+)")
# 中文与阿拉伯数字两种量词都要抓（第 6 轮复核 F4：只抓阿拉伯数字的判据抓不到「四处」）
QUANT = re.compile(r"(?:[0-9]+|[一二两三四五六七八九十])\s*(?:处|条|份|笔|格|张|行|个)")
COVERAGE = re.compile(r"(全改成|都已|全部改成|均已|已回写|已补|共\s*[0-9]+\s*[笔条处份])")
CMD_MARK = ("`", "grep", "wc", "git ", "awk", "sed", "python3", "flutter", "dart", "：", "、", "（即")
# 「第 N 轮 …未回/未派」与「（第 N 轮）」处置节标题
HEADING_ROUND = re.compile(r"^#+ .*(?:（第 ([0-9、–\-]+) 轮）|第 (\d+) 轮)", re.M)
FUTURE = re.compile(r"第 ([0-9]+) 轮[^。\n]{0,24}(未回|未派)")


def rounds_judged(text: str) -> set[int]:
    """已经写过处置节的轮号 ⇒ 这些轮的结果在文档里是既成事实，不许再说"未回/未派"。"""
    done: set[int] = set()
    for m in HEADING_ROUND.finditer(text):
        for token in re.split(r"[、–\-]", m.group(1) or m.group(2) or ""):
            token = token.strip()
            if token.isdigit():
                done.add(int(token))
        if m.group(1) and "–" in m.group(1):
            a, _, b = m.group(1).partition("–")
            if a.strip().isdigit() and b.strip().isdigit():
                done.update(range(int(a), int(b) + 1))
    return done


def check(text: str, base: Path) -> list[str]:
    errs: list[str] = []
    lines = text.splitlines()

    # ① 「末行」：把 `文件:行号` 称作末行，而该文件的物理末行不是那一行 ⇒ 失项。
    for n, line in enumerate(lines, 1):
        if "末行" not in line or "不是" in line or "才是" in line:
            continue
        for m in REF.finditer(line):
            target, want = base / m.group(0).rsplit(":", 1)[0], int(m.group(1))
            if not target.exists():
                continue
            total = len(target.read_text(encoding="utf-8").splitlines())
            if want != total:
                errs.append(
                    f":{n} 把 `{target.name}:{want}` 叫作「末行」，但该文件共 {total} 行"
                    f"（判据：`wc -l < {target}`）"
                )

    # ② 轮号：已经判过的轮不许再写成"未回/未派"（这是"同一文件两个答案"的机械版）。
    done = rounds_judged(text)
    for n, line in enumerate(lines, 1):
        for m in FUTURE.finditer(line):
            # 豁免：整句被引号包住 = 在**引用**那句旧账（元语言），不是自己在写将来时
            quoted = any(q.format(m.group(1)) in line for q in (
                '"第 {} 轮', '“第 {} 轮', '「第 {} 轮'))
            if quoted:
                continue
            if int(m.group(1)) in done:
                errs.append(
                    f":{n} 说「第 {m.group(1)} 轮 {m.group(2)}」，但文档里该轮的处置节已经存在"
                    f"（已判轮号：{sorted(done)}）"
                )

    # ③ 量词：只管**覆盖性主张**那一族（"四处全改成""三条已回写""共 8 笔"）—— 这类句子的数一旦
    #    与字节不符就是假账；普通叙述里的"九条探针"不归它管（第一版按整行任意量词扫，14/16 命中
    #    都是噪声，那种判据没人会再信）。命中条件 = 量词 + 覆盖动词同现，且本行给不出命令/枚举。
    for n, line in enumerate(lines, 1):
        if not COVERAGE.search(line):
            continue
        m = QUANT.search(line)
        if m and not any(k in line for k in CMD_MARK):
            errs.append(
                f":{n} 覆盖性主张里的量词「{m.group(0).strip()}」既无命令也无枚举"
                f" ⇒ 要么给复算命令，要么按实写成'N 处里 M 处已改'"
            )
    return errs


def selftest(path: Path) -> int:
    """三条 mutation 各造一份"已知有错"的副本，判据必须**每一条都红**。"""
    text = path.read_text(encoding="utf-8")
    cases = {
        "把统计行叫末行": text.replace(
            "- [x] 红测（步骤见下「红测读数」", "- [x] 末行读数（步骤见下「红测读数」", 1
        ) + "\n参照 `/tmp/r68/baseline_develop.log:1152` 的末行。\n",
        "已判过的轮仍写未回": text
        + "\n- 只读复核第 1 轮 `VERDICT` 未回。\n",
        "量词空口数数": text + "\n本笔把四处全改成统计行。\n",
    }
    bad = 0
    for name, mutated in cases.items():
        with tempfile.TemporaryDirectory() as td:
            f = Path(td) / path.name
            f.write_text(mutated, encoding="utf-8")
            errs = check(mutated, path.parent)
            print(f"  mutation「{name}」→ {'红（判据有效）' if errs else '绿（判据是摆设！）'}"
                  f"，命中 {len(errs)} 条")
            if not errs:
                bad += 1
    return bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("target", type=Path)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    text = a.target.read_text(encoding="utf-8")
    errs = check(text, a.target.parent)
    for e in errs:
        print(f"  ! {e}")
    print(f"{a.target}: 失项 {len(errs)} 条")
    rc = 1 if errs else 0
    if a.selftest:
        print("自检（判据必须能在有错基线上红）：")
        n = selftest(a.target)
        print(f"  失效的判据 = {n} 条")
        rc = rc or (1 if n else 0)
    return rc


if __name__ == "__main__":
    sys.exit(main())
