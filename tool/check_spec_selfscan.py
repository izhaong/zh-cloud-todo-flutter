#!/usr/bin/env python3
"""规格台账（`specs/<NNN>/tasks.md`）的散文自证检查器。

为什么有这个文件：第 77 轮的只读复核连着判我同一类账 ——「把统计行叫末行」
（`/tmp/r77c6/review_r77_round6_report.md:108`）、「一句话的全称唯一性」（同文件 `:130`）、
「量词只抓阿拉伯数字，抓不到『四处』」（同文件 `:118`）。
前几次的修法是把判据**写进 markdown 散文**，而散文里的判据既要人读、又会随下一笔编辑漂，
等于没修 ⇒ 本版起判据落成代码，散文只留读数。

为什么重写（上一版 `c53da6a` 的三条判据实测 0 鉴别力，逐条给字节）：
① 锚点用 `base = target.parent` 解析（`c53da6a:tool/check_spec_selfscan.py:127`），
   且解析不到就静默跳过（同文件 `:58-59`）⇒ 台账里 `/tmp/…log:1152` 这种绝对路径**永远**解析不到
   ⇒ 实际评估 0 个锚点，指不到的死锚点照样绿；
③ 的"证据标记"里塞了 `：`、`、`（同文件 `:27` 的 `CMD_MARK`）⇒ 带标点的空口量词被豁免，**评估 0 条**；
`--selftest` 的变异①靠往文件尾粘一行引用 `/tmp/r68/baseline_develop.log` 才变红（同文件 `:103`）
⇒ 换一个环境就没牙。⇒ 本版把自检改成**自带语料**（`CORPUS`，只用仓内相对路径），不碰 /tmp。

用法：
    python3 tool/check_spec_selfscan.py [--selftest] <specs/**/tasks.md>
退出码：0 = 干净；1 = 有失项或自检失效；2 = 用法错误。
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# `foo.log:1137` / `specs/x/tasks.md:120` / `/tmp/r79h/gates.log:42` 这类跨文件锚点
REF = re.compile(r"(?<![\w/])(/[A-Za-z0-9_./-]*|[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]*|[A-Za-z0-9_.-]+\.(?:log|md|dart|txt|py)):(\d+)")
# 覆盖性主张：一律是"我全做完了"那一族措辞
COVERAGE = re.compile(
    r"(全改成|全部改成|都改|统一为|全篇|全部通过|都已|均已|已回写|已补|共\s*\d+\s*[笔条处份]|"
    r"零漏|没有遗漏|无一|逐条?已|全量|唯一)"
)
QUANT = re.compile(r"(?:[0-9]+|[一二两三四五六七八九十])\s*(?:处|条|份|笔|格|张|行|个)")
# 只有"长得像命令/指针"的东西才算证据。标点（：、、）不算 —— 那正是上一版的漏口。
EVIDENCE = re.compile(
    r"(grep|rg\s|wc\s+-|git\s+(grep|diff|log|show|rev-parse|rev-list|ls-tree)|awk\s|sed\s+-|python3\s|"
    r"flutter\s+(test|analyze|build)|dart\s+format|[0-9a-f]{7,40}|(?:#|!)\d{2,4}|"
    r"[\w./-]+\.(?:log|md|dart|py):\d+|命中\s*\d+|rc\s*[=＝]\s*\d)"
)
# `分支:文件:行` —— 必须有**两个**冒号才认，免得把普通路径误判成分支形态
BRANCH_REF = re.compile(
    r"(?<![\w/:])((?:refs/heads/|origin/)?[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+):"
    r"([A-Za-z0-9._/-]+\.(?:log|md|dart|txt|py)):(\d+)"
)
# 「X 由脚本产出 / 脚本已断言」：必须点名一个**仓内存在**的脚本
CLAIM_SCRIPT = re.compile(r"(脚本已断言|脚本产出|由脚本|脚本实算|校验器已断言|仓内脚本)")
SCRIPT_PATH = re.compile(r"((?:tool|scripts)/[A-Za-z0-9_./-]+\.py)")
HEADING_ROUND = re.compile(r"^#+ .*(?:（第 ([0-9、,–\-]+) 轮）|第 (\d+) 轮)", re.M)
FUTURE = re.compile(r"第 ([0-9]+) 轮[^。\n]{0,24}(未回|未派)")
# 「第 a–b 轮都已判过」：区间的上下界必须等于本文处置节推出的那一个
DONE_RANGE = re.compile(r"第\s*([0-9]+)\s*[–\-]\s*([0-9]+)\s*轮都已判")
# 元语言豁免只认"紧贴"：`不是末行` / `才是末行` / `不叫末行` 这种说法就在锚点旁边
NEGATION = re.compile(r"[不未]叫|才是|^.*\|\s*不是\s*$|「末行」|\"末行\"")
# 只盯「末行」这一种主张：把统计行叫末行才是历次判我的那条罪（`r77c6/review_r77_round6_report.md:108`）。
# 触发词就这一个字面，不多扩：扩到「统计行」会把散文里正常写「统计行在 `x.log:2`、全文 9 行」的句子
# 判成失项 ⇒ 语料「统计行在中间·句里不称末行」把这条边界钉住（期望不红）。
# 上一版同样只认「末行」（`c53da6a:tool/check_spec_selfscan.py:54`）⇒ 这条不是修过的地方，别当卖点。
# 统计行的真假另有判据：锚点行号必须落在真存在的那一行上。
LASTLINE_WORDS = ("末行",)


def rounds_judged(text: str) -> set[int]:
    """已经写过处置节的轮号 ⇒ 文档里它是既成事实，不许再说"未回/未派"。"""
    done: set[int] = set()
    for m in HEADING_ROUND.finditer(text):
        token_group = m.group(1) or m.group(2) or ""
        if m.group(1) and ("–" in m.group(1) or "-" in m.group(1)):
            parts = re.split(r"[–-]", m.group(1), maxsplit=1)
            if len(parts) == 2 and parts[0].strip().isdigit() and parts[1].strip().isdigit():
                done.update(range(int(parts[0]), int(parts[1]) + 1))
        for token in re.split(r"[、,–\-]", token_group):
            token = token.strip()
            if token.isdigit():
                done.add(int(token))
    return done


def resolve(raw: str, repo_root: Path) -> Path | None:
    """锚点路径解析：绝对路径按绝对路径查；其余按**仓库根**（不是 tasks.md 的目录）查。

    返回 None = 这个引用在文件系统上不存在 ⇒ 由调用方判"死锚点"。
    """
    p = Path(raw)
    cand = [p] if p.is_absolute() else [repo_root / p, repo_root / "specs" / p]
    for c in cand:
        if c.exists():
            return c
    return None


_BRANCH_LINES: dict[tuple[str, str], int | None] = {}


def branch_blob_lines(repo_root: Path, ref: str, path: str) -> int | None:
    """`分支:文件` 形态锚点的真身校验：文件系统上没有这条路径，但 git 里有。

    返回 None = 该分支上根本没有这个文件（⇒ 死锚点）；否则返回该 blob 的行数。
    上一版只会按文件系统查，于是台账里 `feat/xxx:specs/yyy/tasks.md:120` 这种
    "指另一条分支上的同一形状"的写法被一律判死 —— 那是假失项，会把人引去删真证据。
    """
    key = (ref, path)
    if key not in _BRANCH_LINES:
        probe = subprocess.run(
            ["git", "cat-file", "-e", f"{ref}:{path}"],
            cwd=repo_root, capture_output=True,
        )
        if probe.returncode != 0:
            _BRANCH_LINES[key] = None
        else:
            shown = subprocess.run(
                ["git", "show", f"{ref}:{path}"],
                cwd=repo_root, capture_output=True, text=True,
            )
            _BRANCH_LINES[key] = len(shown.stdout.splitlines())
    return _BRANCH_LINES[key]


def check(text: str, repo_root: Path) -> list[str]:
    errs: list[str] = []
    lines = text.splitlines()

    # ① 锚点必须指得到；被称作「末行」的那个行号必须真等于全文行数
    for n, line in enumerate(lines, 1):
        # 先看 `分支:文件:行`：这类锚点在文件系统上必然找不到，得走 git。
        # 处理过的位置打码，免得下面按文件系统再扫一遍、报一条假死锚点。
        scan = line
        for bm in BRANCH_REF.finditer(line):
            ref, bpath, want = bm.group(1), bm.group(2), int(bm.group(3))
            total = branch_blob_lines(repo_root, ref, bpath)
            if total is None:
                errs.append(
                    f":{n} 分支锚点 `{ref}:{bpath}:{want}` 指不到 —— 该分支上没有这份文件"
                    f"（判据：`git cat-file -e {ref}:{bpath}`）⇒ 死锚点等于没证据"
                )
            elif want > total:
                errs.append(
                    f":{n} 分支锚点 `{ref}:{bpath}:{want}` 越界：该 blob 只有 {total} 行"
                    f"（判据：`git show {ref}:{bpath} | wc -l`）"
                )
            scan = scan.replace(bm.group(0), " " * len(bm.group(0)), 1)
        for m in REF.finditer(scan):
            raw, want = m.group(1), int(m.group(2))
            if raw.startswith("http") or not raw.strip():
                continue
            target = resolve(raw, repo_root)
            if target is None:
                # 只有当这行确实在"引用一份日志/文件"时才判死锚点（sha 之类不误伤）
                if re.search(r"\.(log|md|dart|txt|py)$", raw):
                    errs.append(
                        f":{n} 锚点 `{raw}:{want}` 指不到 —— 该文件在仓内与绝对路径两处都不存在"
                        f"（判据：`ls -la {raw}`）⇒ 死锚点等于没证据"
                    )
                continue
            total = len(target.read_text(encoding="utf-8", errors="replace").splitlines())
            if want > total:
                errs.append(
                    f":{n} 锚点 `{raw}:{want}` 越界：该文件只有 {total} 行"
                    f"（判据：`wc -l < {raw}`）"
                )
            if any(w in line for w in LASTLINE_WORDS) and not NEGATION.search(line):
                if want != total:
                    errs.append(
                        f":{n} 把 `{raw}:{want}` 称作末行，但该文件共 {total} 行"
                        f"（判据：`wc -l < {raw}`）⇒ 要么改指真末行，要么把这行改写成"
                        f"「`+N` 统计行在 :{want}、全文 {total} 行、:N 不是末行」"
                    )

    # ② 已判过的轮不许再写"未回/未派"
    done = rounds_judged(text)
    for n, line in enumerate(lines, 1):
        for m in FUTURE.finditer(line):
            quoted = any(q.format(m.group(1)) in line for q in (
                '"第 {} 轮', '“第 {} 轮', '「第 {} 轮'))
            if quoted:
                continue
            if int(m.group(1)) in done:
                errs.append(
                    f":{n} 说「第 {m.group(1)} 轮 {m.group(2)}」，但文档里该轮的处置节已经存在"
                    f"（已判轮号：{sorted(done)}）"
                )

    # ②b 「第 a–b 轮都已判过」少写一轮，与"已判过却写未回"是同一类账（第 7 轮 F1 就是它）：
    # 区间由本文处置节自己推出，散文只许照抄，不许凭记忆。
    if done:
        real = (min(done), max(done))
        for n, line in enumerate(lines, 1):
            for m in DONE_RANGE.finditer(line):
                claimed = (int(m.group(1)), int(m.group(2)))
                if claimed != real:
                    errs.append(
                        f":{n} 说「第 {claimed[0]}–{claimed[1]} 轮都已判过」，但本文处置节推出的是"
                        f"第 {real[0]}–{real[1]} 轮（判据：`rounds_judged` 取小节标题里的轮号）"
                    )

    # ③ 覆盖性主张：量词与"全…"同现时，必须给命令/指针；标点不算证据
    for n, line in enumerate(lines, 1):
        if not COVERAGE.search(line):
            continue
        m = QUANT.search(line)
        if m and not EVIDENCE.search(line):
            errs.append(
                f":{n} 覆盖性主张里的量词「{m.group(0).strip()}」既无可复跑命令也无指针"
                f"（上一版 `c53da6a:27` 的 `CMD_MARK` 里就含「：」「、」⇒ 标点当证据会把这条判据绕过）"
            )

    # ④ 「X 由脚本产出 / 脚本已断言」必须点名一个仓内存在的脚本
    for n, line in enumerate(lines, 1):
        if not CLAIM_SCRIPT.search(line):
            continue
        named = SCRIPT_PATH.search(line)
        if not named:
            errs.append(
                f":{n} 说「{CLAIM_SCRIPT.search(line).group(0)}」却没点名仓内脚本路径"
                f"（形如 `tool/xxx.py`）⇒ 归属声明不可核"
            )
        elif not (repo_root / named.group(1)).exists():
            errs.append(
                f":{n} 点名的脚本 `{named.group(1)}` 在仓内不存在 ⇒ 这句话是空的"
            )
        elif not re.search(r"断言|产出|实算", line):
            continue
        elif named and "grep" not in line and "errors" not in line and "append" not in line:
            errs.append(
                f":{n} 声称脚本里有该断言，但没给出证明它的命令（`grep -n … {named.group(1)}`）"
                f" ⇒ 这句话在脚本里找不到对应的 `errs.append`（空口归属）"
            )
    return errs


# ---------- 自带语料的自检：不依赖 /tmp，也不依赖被审文件的内容 ----------
# 每条 = (名字, 判据编号, 文本, 期望是否红)
CORPUS: list[tuple[str, str, str, bool]] = [
    ("末行·指到的行不等于全文行数", "①",
     "读数在 `logs/gates.log:7`（全文 9 行）\nline8\nline9\n"
     "参照 `logs/gates.log:7` 的末行。\n" + "x\n" * 2, True),
    ("末行·元语言豁免（写着「不叫末行」）", "①",
     "a\nb\nc\n参照 `logs/gates.log:2`，:3 才是物理末行、:2 **不叫末行**。\n", False),
    ("死锚点·文件不存在", "①", "见 `logs/nope.log:12` 的统计行。\n", True),
    ("统计行在中间·句里不称末行（上一版会误伤）", "①",
     "统计行 `logs/gates.log:2`，全文 9 行。\n", False),
    ("锚点·真存在的文件且不称末行", "①", "锚点 `logs/ok.md:2` 与 `logs/ok.md:1`。\n", False),
    ("轮号·已判过却写未回", "②",
     "## 第 3 轮只读复核：`VERDICT: FAIL`\n\n- 只读复核第 3 轮未回 ⇒ 不谈合并\n", True),
    ("轮号·引用历史句被引号包住", "②",
     "## 第 3 轮只读复核：`VERDICT: FAIL`\n\n- 台账原文「第 3 轮未回」是当时的账\n", False),
    ("轮号·已判区间少写一轮（少报 = 与②同族）", "②",
     "## 第 1 轮\n## 第 2 轮\n## 第 3 轮\n- 现在第 1–2 轮都已判过\n", True),
    ("轮号·已判区间照抄本文处置节", "②",
     "## 第 1 轮\n## 第 2 轮\n## 第 3 轮\n- 现在第 1–3 轮都已判过\n", False),
    ("量词·只有标点做证据（旧版会漏）", "③",
     "本笔把四处全改成统计行：A、B、C、D\n", True),
    ("量词·带可复跑命令", "③",
     "四处全改成统计行（`grep -c \"^+9\" logs/gates.log` = 4）\n", False),
    ("量词·只有 `git rev-list` 这类命令（上一版 EVIDENCE 不认 rev-list）", "③",
     "共 8 笔（`git rev-list --count origin/develop..HEAD` = 14 ⇒ 见下文）\n", False),
    ("唯一性·空口「唯一」", "③", "这是唯一一处未被覆盖的形状\n", True),
    ("脚本归属·没点名脚本", "④", "每步守恒（脚本已断言）：总量不变\n", True),
    ("脚本归属·点名的脚本不存在", "④",
     "由脚本 `tool/no_such_checker.py` 产出，`grep -n errors tool/no_such_checker.py`\n", True),
    ("分支锚点·分支上没有这份文件", "①",
     "见 `feat/nope-branch:specs/x/tasks.md:12` 的同款写法。\n", True),
    ("分支锚点·分支与 blob 都在（走 git 不走文件系统）", "①",
     "见 `feat/corpus-branch:specs/x/tasks.md:2` 的同款写法。\n", False),
    ("脚本归属·点名且给出证明命令", "④",
     "由脚本 `tool/check_spec_selfscan.py` 产出"
     "（判据：`grep -n \"errs.append\" tool/check_spec_selfscan.py`）\n", False),
]


def selftest(_unused: Path | None = None) -> int:
    """每条语料都必须按期望结果走：该红的红、该绿的绿。

    ⚠️ 语料用的假文件一律建在**临时目录**里，绝不在被审仓库下落 `logs/`
    （上一版的自检会在仓库根造文件，那本身就是对被审工作树的写操作）。
    """
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        (root / "logs").mkdir()
        (root / "logs" / "gates.log").write_text("h\ni\nj\nk\nl\nm\nn\no\np\n", encoding="utf-8")
        (root / "logs" / "ok.md").write_text("one\ntwo\nthree\n", encoding="utf-8")
        (root / "tool").mkdir()
        (root / "tool" / "check_spec_selfscan.py").write_text(
            "def f():\n    errs.append('x')\n", encoding="utf-8")
        # 「分支锚点」这条判据要 PRESENT/ABSENT 成对，就得有个真 git 仓库当基准；
        # 建在同一个临时目录里，收尾随目录一起消失。git 不可用时**显式说明跳过**，
        # 不许静默把该红的放过（那等于把判据降级成摆设）。
        git = subprocess.run(
            ["git", "init", "-q", str(root)], capture_output=True, text=True)
        if git.returncode == 0:
            env_cmd = [
                ["git", "-C", str(root), "config", "user.email", "selftest@example.invalid"],
                ["git", "-C", str(root), "config", "user.name", "selftest"],
            ]
            for cmd in env_cmd:
                subprocess.run(cmd, capture_output=True)
            (root / "specs" / "x").mkdir(parents=True)
            (root / "specs" / "x" / "tasks.md").write_text(
                "one\ntwo\nthree\n", encoding="utf-8")
            for cmd in [
                ["git", "-C", str(root), "add", "-A"],
                ["git", "-C", str(root), "commit", "-q", "-m", "selftest 基线"],
                ["git", "-C", str(root), "branch", "feat/corpus-branch"],
            ]:
                subprocess.run(cmd, capture_output=True)
        else:
            print("  ⚠️ 临时 git 仓库建不起来 ⇒ 分支锚点的 PRESENT 一条不计入（"
                  "ABSENT 一条仍会判，且它只依赖 `cat-file` 失败）")
        return _run_corpus(root)


def _run_corpus(root: Path) -> int:
    bad = 0
    for name, tag, text, expect_red in CORPUS:
        errs = check(text, root)
        red = bool(errs)
        ok = red == expect_red
        if not ok:
            bad += 1
        print(f"  {'ok ' if ok else '坏 '} [{tag}] {name}：期望"
              f"{'红' if expect_red else '绿'} → 实际{'红' if red else '绿'}"
              f"{'' if ok else '（判据与期望不符！）'}"
              + (f"｜{errs[0][:70]}" if red and errs else ""))
    return bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("target", type=Path)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if not a.target.exists():
        print(f"读不到 {a.target}", file=sys.stderr)
        return 2
    # 从 target 往上找仓库根（有 .git 的那层）—— 上一版用 target.parent 是错的
    repo_root = next((p for p in a.target.resolve().parents if (p / ".git").exists()),
                     a.target.resolve().parent)
    text = a.target.read_text(encoding="utf-8")
    errs = check(text, repo_root)
    for e in errs:
        print(f"  ! {e}")
    print(f"{a.target}: 失项 {len(errs)} 条（仓库根按 {repo_root.name} 解析）")
    rc = 1 if errs else 0
    if a.selftest:
        print("自检（自带语料，不碰 /tmp；该红的必须红、该绿的必须绿）：")
        n = selftest()
        print(f"  与期望不符的判据 = {n} 条")
        rc = rc or (1 if n else 0)
    return rc


if __name__ == "__main__":
    sys.exit(main())
