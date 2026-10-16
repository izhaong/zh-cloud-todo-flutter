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
import os
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
# ③ 只认**命令**。指针（sha、`#123`、`file:12`）只能证明"有这个东西"，
# 证明不了"是这个数"——第 8 轮复核 F9 就是拿"量词 + 一个 sha"把上一版骗过去的。
EVIDENCE_CMD = re.compile(
    r"(grep|rg\s|wc\s+-|ls\s+-|git\s+(?:grep|diff|log|show|rev-parse|rev-list|ls-tree)|awk\s|sed\s+-|python3\s|"
    r"flutter\s+(?:test|analyze|build)|dart\s+format)"
)
# `分支:文件:行` —— 必须有**两个**冒号才认，免得把普通路径误判成分支形态
BRANCH_REF = re.compile(
    r"(?<![\w/:])((?:refs/heads/|origin/)?[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+):"
    r"([A-Za-z0-9._/-]+\.(?:log|md|dart|txt|py)):(\d+)"
)

# 跨仓锚点（Issue #394）：`<repo>@<ref>:<path>:<line>`。
# 不带 ref 的 `<repo>/<path>:<line>` 不用单独扫 —— REF 的捕获组本来就能吃到这个形状，
# 差别只在「首段是不是兄弟仓名」，那个在匹配后判，省一次全文正则。
CROSS_AT = re.compile(
    r"(?<![\w/])([A-Za-z0-9_.-]+)@([A-Za-z0-9_./-]+):([A-Za-z0-9_./-]+):(\d+)")

# 什么样的首段算「跨仓意图」。**只在缺兄弟仓时**才用它决定判红（要求 2）：
# 不设这条，`lib/features/x.dart:120` 这种普通相对路径的首段 `lib` 也会被当成仓名，
# 于是每次都因为「没有 lib 这个兄弟仓」而红 —— 那不是本单要的。
# 本工作区的仓一律叫 `zh-cloud-*`（见父仓 .gitmodules），按这个前缀认。
SIBLING_NAME = re.compile(r"^zh-cloud-[a-z0-9-]+$")

# 锚点分类计数（要求 3）：把豁免摆到台面上，别让覆盖率靠沉默撑起来。
ANCHOR_STATS = {"local": 0, "cross": 0, "cross_missing": 0, "dead": 0}


def reset_anchor_stats() -> None:
    for k in ANCHOR_STATS:
        ANCHOR_STATS[k] = 0
# 「X 由脚本产出 / 脚本已断言」：必须点名一个**仓内存在**的脚本。
# ⚠️ 别只列固定词组：台账的自然写法是「由 `tool/xxx.py` 产出」（脚本名与"由"被路径隔开），
# 上一版只认「由脚本」四字连着 ⇒ 自测里那条"命令跑不出命中"的语料直接跳过整条判据、假绿
# （本轮自己抓的：新写的 corpus 期望红、实际绿，才暴露出这个口子）。
CLAIM_SCRIPT = re.compile(
    r"(脚本已断言|脚本产出|由脚本|脚本实算|校验器已断言|仓内脚本|"
    r"(?:由|经|从)\s*`?[\w./-]+\.(?:py|sh)`?\s*(?:产出|实算|断言)|脚本.{0,6}产出)"
)
SCRIPT_PATH = re.compile(r"((?:tool|scripts)/[A-Za-z0-9_./-]+\.py)")
HEADING_ROUND = re.compile(r"^#+ .*(?:（第 ([0-9、,–\-]+) 轮）|第 (\d+) 轮)", re.M)
FUTURE = re.compile(r"第 ([0-9]+) 轮[^。\n]{0,24}(未回|未派)")
# 「第 a–b 轮都已判过 / 都判过 / 均已判」这一族区间主张：上下界必须等于本文处置节推出的区间。
# 上一版只认「都已判」四个字，台账改写成「都判过」就整条漏网（第 8 轮复核 F8：它把区间改成
# 「第 1–8 轮复核都判过」后仍然绿 ⇒ 这条判据当时是死的）。
DONE_RANGE = re.compile(r"第\s*([0-9]+)\s*[–\-~]\s*([0-9]+)\s*轮[^。\n]{0,10}?(?:都|均)[^。\n]{0,6}?判")
# 台账里写「判据：grep -n "X" tool/xxx.py」时，把这条命令真的跑一遍（第 8 轮复核 F10：
# 上一版只检查"有没有给命令"，不回查命令跑不跑得出东西 ⇒ 「脚本里有这条断言」照样能空口写）
CLAIMED_GREP = re.compile(r"grep\s+(?:-\w+\s+)*\"([^\"]+)\"\s+((?:tool|scripts)/[A-Za-z0-9_./-]+\.py)")
# 元语言豁免只认"紧贴"：`不是末行` / `才是末行` / `不叫末行` 这种说法就在锚点旁边
# 第 11 轮补两类（同一判据在台账里会把"谈这个写法"的句子判成假失项，判据一响就没人信它）：
#   ① 显式否定：`不是物理末行` ⇒ 这句正在纠正旧措辞，不是重复犯错。中间**不许跨标点**
#      （`不是靠猜的，末行是 :9` 这种"否定 + 正向主张"必须仍红，语料钉住）；
#   ② 提及而非使用（用/引）：`「末行异常计数」`、``「`:140` 是该末行」`` ⇒ 词被引号包着 = 在谈这个词。
#      只认**直角引号**：ASCII 双引号在 markdown 里成对出现，`grep -c "^  ok"` = 26、末行「…」
#      这种句子的"闭引号"会被当成开引号 ⇒ 正向主张被误免（第 11 轮实测踩过，语料已钉）。
#   边界：开引号必须在「末行」**之前** ⇒「`+907` 就是末行」仍然红。
NEGATION = re.compile(
    r"[不未]叫|才是|^.*\|\s*不是\s*$|「末行」"
    r"|不是[^，。；\n]{0,6}末行|「[^」\n]{0,12}末行"
)
# ①b 的"就近"尺度：锚必须出现在「末行」之前这么多个字符里，否则不算这条主张的证据。
# 第 11 轮复核实测两个缴获形状：`…就是"末行"`（ASCII 引用紧贴主张）与
# `A（锚）+ B 那行就是末行`（同行别处的锚盖住本条无锚主张）⇒ 行级 `REF in line` 太宽。
NEAR_ANCHOR = 30


def near(pos: int, line: str) -> tuple:
    """返回（前窗, 环绕窗, 后窗截断）。

    - 锚**前后都算**，但后窗要在遇到句号或下一个「末行」之前截断 ⇒
      `…就是末行（`x.log:9`）` 这种"锚紧跟其后"合法，而
      `A（锚）+ B 那行就是末行` 里 A 的锚既在 30 字之外、又隔着另一个主张，不算。
    - 否定/引号提及看环绕窗：`「末行」` 的闭引号在词后面，只往前看就认不出来。
    """
    prev = line[max(0, pos - NEAR_ANCHOR):pos]
    around = line[max(0, pos - NEAR_ANCHOR):pos + 6]
    tail = line[pos + 2:pos + 2 + NEAR_ANCHOR]
    for stop in ("。", "；", "末行"):
        i = tail.find(stop)
        if i >= 0:
            tail = tail[:i]
    return prev, around, tail
# 只盯「末行」这一种主张：把统计行叫末行才是历次判我的那条罪（`r77c6/review_r77_round6_report.md:108`）。
# 触发词就这一个字面，不多扩：扩到「统计行」会把散文里正常写「统计行在 `x.log:2`、全文 9 行」的句子
# 判成失项 ⇒ 语料「统计行在中间·句里不称末行」把这条边界钉住（期望不红）。
# 上一版同样只认「末行」（`c53da6a:tool/check_spec_selfscan.py:54`）⇒ 这条不是修过的地方，别当卖点。
# 统计行的真假另有判据：锚点行号必须落在真存在的那一行上。
LASTLINE_WORDS = ("末行",)

# ⑤「N 处 / N 个 / N 条…」紧跟一个括号枚举 ⇒ 项数必须等于 N（第 8 轮 F-9 提的修法，
#    第 10 轮复核复判仍空转：只查"有没有命令"，不查"命令给不了的项数"）
COUNT_ENUM = re.compile(
    r"([0-9]+|[一二两三四五六七八九十])\s*(处|个|条|格|笔|面|项)[^（）\n]{0,16}"
    r"[（(]([^（）\n]*[、；;][^（）\n]*)[）)]"
)
CN_NUM = {"一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
          "六": 6, "七": 7, "八": 8, "九": 9, "十": 10}
# 「末行」这一主张里，什么样的句子算"在报一个读数"（而不是在讨论这条规则本身）
LASTLINE_CLAIM = re.compile(r"\+\d|\d+\s*行|=|读数|通过|All tests|统计行")


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

    返回 None = 这个引用在文件系统上不存在 ⇒ 由调用方再走 bare_matches，别急着判死。
    """
    p = Path(raw)
    cand = [p] if p.is_absolute() else [repo_root / p, repo_root / "specs" / p]
    for c in cand:
        if c.exists():
            return c
    return None


_BARE_INDEX: dict[str, dict[str, list[str]]] = {}


def bare_matches(raw: str, repo_root: Path) -> list[str]:
    """裸文件名锚点（`kanban_view.dart:540`）的解析：本仓从矩阵到各台账都这么写。

    上一版只按"仓库根下有没有这个路径"查 ⇒ 全仓 44 份台账里 80% 的锚点被误判成死锚点
    （第 8 轮复核 F12：它拿 165 条失项实测，133 条说"仓内不存在"的文件其实都在 `lib/` 下）。
    误伤的后果比漏报更糟：写台账的人会去删**真证据**来让它变绿。

    返回值语义：1 条 = 解析成功；>1 条 = 有歧义（该补路径，但这是"写法不清"不是"没证据"）；
    0 条 = 真不存在 ⇒ 才允许报死锚点。
    """
    global _BARE_INDEX
    if "/" in raw or raw.startswith("."):
        return []
    key = str(repo_root)
    idx = _BARE_INDEX.get(key)
    if idx is None:
        shown = subprocess.run(["git", "ls-files"], cwd=repo_root,
                               capture_output=True, text=True)
        idx = {}
        for rel in shown.stdout.splitlines():
            idx.setdefault(Path(rel).name, []).append(rel)
        _BARE_INDEX[key] = idx
    return idx.get(raw, [])


_BRANCH_LINES: dict[tuple[str, str], int | None] = {}


def ref_candidates(ref: str) -> list[str]:
    """`分支:文件` 里的"分支"在一份干净的克隆里长成什么。

    `git clone` 只把源仓的分支落成 `origin/<分支>`；和本地同名的那根 ref 要有人
    真 `git checkout` 过才存在 ⇒ 只按裸名查会让**同一份字节**在"我这块工作树"
    和"别人那份新克隆"里给出两个数（实测差 3 条）。判据不该看谁的机器上有缓存。
    """
    if ref.startswith("origin/") or ref == "origin":
        return [ref]
    return [ref, f"origin/{ref}"]


def branch_blob_lines(repo_root: Path, ref: str, path: str) -> int | None:
    """`分支:文件` 形态锚点的真身校验：文件系统上没有这条路径，但 git 里有。

    返回 None = 该分支上根本没有这个文件（⇒ 死锚点）；否则返回该 blob 的行数。
    上一版只会按文件系统查，于是台账里 `feat/xxx:specs/yyy/tasks.md:120` 这种
    "指另一条分支上的同一形状"的写法被一律判死 —— 那是假失项，会把人引去删真证据。
    """
    key = (ref, path)
    if key not in _BRANCH_LINES:
        total: int | None = None
        for cand in ref_candidates(ref):
            probe = subprocess.run(
                ["git", "cat-file", "-e", f"{cand}:{path}"],
                cwd=repo_root, capture_output=True,
            )
            if probe.returncode != 0:
                continue
            shown = subprocess.run(
                ["git", "show", f"{cand}:{path}"],
                cwd=repo_root, capture_output=True, text=True,
            )
            total = len(shown.stdout.splitlines())
            break
        _BRANCH_LINES[key] = total
    return _BRANCH_LINES[key]


_SIBLING_CACHE: dict[tuple[str, str], Path | None] = {}


def sibling_repo_root(repo_root: Path, name: str) -> Path | None:
    """工作区里的兄弟仓：`<repo_root 的父目录>/<name>`，且它真是个 git 仓。

    Issue #394：台账会出现指向**另一个仓**的真实引用（`zh-cloud-todo-flutter/lib/…:120`）。
    旧版只在「绝对路径 / 本仓根 / 本仓 `git ls-files`」三处查 ⇒ 这类引用**结构上**永远
    解析不到，被一律判成死锚点。误伤的后果比漏报更糟：写台账的人会去删**真证据**来让它变绿
    （脚本 docstring 第 8 轮复核 F12 记的正是这个失败模式）。

    `.git` 在普通仓是目录、在 worktree / submodule 里是文件，故用 exists() 而非 is_dir()。
    返回 None = 这台机器上没有这个兄弟仓 ⇒ 调用方按「跨仓缺仓」判红（要求 2）。
    """
    key = (str(repo_root), name)
    if key in _SIBLING_CACHE:
        return _SIBLING_CACHE[key]
    # ① 工作区兄弟目录（标准布局：`zh-cloud/zh-cloud-service` 旁边就是 `zh-cloud-todo-flutter`）；
    # ② `ZH_CLOUD_ROOT` 指的父目录 —— 在 /tmp 或 `todo-worktrees/` 这类**非标准布局**里跑时，
    #    兄弟仓的名字不是 `zh-cloud-*`，只有这个口子能指回真仓（同 `check_parity_matrix.py` 的先例）。
    # 两处都没有 ⇒ None ⇒ 由调用方按「跨仓缺仓」判红（要求 2，绝不静默放过）。
    cands = [repo_root.parent / name]
    env_root = os.environ.get("ZH_CLOUD_ROOT")
    if env_root:
        cands.append(Path(env_root) / name)
    found = next((c for c in cands if (c / ".git").exists()), None)
    _SIBLING_CACHE[key] = found
    return found


_CROSS_LINES: dict[tuple[str, str, str], int | None] = {}


def cross_blob_lines(sib: Path, ref: str | None, path: str) -> int | None:
    """跨仓锚点取对象（要求 1：**显式标基准 ref**）。

    给了 `@<ref>` 就按它（并试 `origin/<ref>`，与 `branch_blob_lines` 同口径：
    判据不该看谁的机器上有没有那根本地 ref）。没给就按该仓的集成线 `origin/develop`，
    再退 `develop` / `HEAD`，最后才回落到它工作树上的实际文件 —— 顺序是「规范 ref 优先」，
    免得同一份台账在「有 worktree」和「只有克隆」的机器上给出两个数。

    返回 None = 该仓里真没有这条路径 ⇒ 才允许判死锚点。
    """
    key = (str(sib), ref or "", path)
    if key in _CROSS_LINES:
        return _CROSS_LINES[key]
    total: int | None = None
    for cand in (ref_candidates(ref) if ref else ["origin/develop", "develop", "HEAD"]):
        probe = subprocess.run(
            ["git", "-C", str(sib), "cat-file", "-e", f"{cand}:{path}"],
            capture_output=True,
        )
        if probe.returncode != 0:
            continue
        shown = subprocess.run(
            ["git", "-C", str(sib), "show", f"{cand}:{path}"],
            capture_output=True, text=True,
        )
        total = len(shown.stdout.splitlines())
        break
    if total is None:
        local = sib / path
        if local.exists():
            total = len(local.read_text(encoding="utf-8", errors="replace").splitlines())
    _CROSS_LINES[key] = total
    return total


def grep_hits(repo_root: Path, pattern: str, rel: str) -> int:
    """把台账自己写的那条 `grep -n "X" tool/….py` 真的跑一遍（只用 argv，不进 shell）。

    先按 BRE 跑，跑不出再试 `-E`、`-F`：三把都不中才算"没命中"。
    这不是放水 —— 判的是「这条证据在不在」，不该被 BSD / GNU 对 `\\|` 的方言差异决定
    （本机是 BSD grep，`QUANT = \\|CLAIM_SCRIPT = ` 这种 GNU 写法 BRE 跑不通，
    要是不试三种，台账里所有真命令都会被误判成假）。
    """
    best = 0
    for extra in ([], ["-E"], ["-F"]):
        run = subprocess.run(["grep", "-c", *extra, "-e", pattern, rel],
                             cwd=repo_root, capture_output=True, text=True)
        try:
            best = max(best, int((run.stdout or "0").strip() or 0))
        except ValueError:
            pass
        if best:
            break
    return best


def check(text: str, repo_root: Path) -> list[str]:
    errs: list[str] = []
    lines = text.splitlines()
    reset_anchor_stats()

    # ① 锚点必须指得到；被称作「末行」的那个行号必须真等于全文行数
    for n, line in enumerate(lines, 1):
        # 先看 `分支:文件:行`：这类锚点在文件系统上必然找不到，得走 git。
        # 处理过的位置打码，免得下面按文件系统再扫一遍、报一条假死锚点。
        scan = line
        # 跨仓 + 显式 ref 的形态先处理，免得下面 REF 只吃到后半截（`lib/x.dart:120`）
        for cm in CROSS_AT.finditer(scan):
            sib_name, cref, cpath, cwant = (cm.group(1), cm.group(2),
                                            cm.group(3), int(cm.group(4)))
            sib = sibling_repo_root(repo_root, sib_name)
            if sib is None:
                if SIBLING_NAME.match(sib_name):
                    ANCHOR_STATS["cross_missing"] += 1
                    errs.append(
                        f":{n} 跨仓锚点 `{cm.group(0)}` 的仓 `{sib_name}` 不在工作区里"
                        f"（判据：`ls -d ../{sib_name}`）⇒ 缺兄弟仓时判红："
                        f"依赖工作树的校验器静默绿，在 CI 上等于这条判据根本不存在"
                    )
                scan = scan.replace(cm.group(0), " " * len(cm.group(0)), 1)
                continue
            ctotal = cross_blob_lines(sib, cref, cpath)
            if ctotal is None:
                ANCHOR_STATS["dead"] += 1
                errs.append(
                    f":{n} 跨仓锚点 `{cm.group(0)}` 指不到 —— "
                    f"`git -C ../{sib_name} cat-file -e {cref}:{cpath}` 无命中"
                    f"（基准 ref 显式取自 `@` 后面那个）⇒ 死锚点等于没证据"
                )
            elif cwant > ctotal:
                ANCHOR_STATS["cross"] += 1
                errs.append(
                    f":{n} 跨仓锚点 `{cm.group(0)}` 越界：`{sib_name}` 的 `{cref}:{cpath}` "
                    f"只有 {ctotal} 行（判据：`git -C ../{sib_name} show {cref}:{cpath} | wc -l`）"
                )
            else:
                ANCHOR_STATS["cross"] += 1
            scan = scan.replace(cm.group(0), " " * len(cm.group(0)), 1)
        for bm in BRANCH_REF.finditer(scan):
            ref, bpath, want = bm.group(1), bm.group(2), int(bm.group(3))
            total = branch_blob_lines(repo_root, ref, bpath)
            if total is None:
                errs.append(
                    f":{n} 分支锚点 `{ref}:{bpath}:{want}` 指不到 —— 这份文件既不在"
                    f"本地 `{ref}` 上，也不在 `origin/{ref}` 上"
                    f"（判据：`git cat-file -e {ref}:{bpath}`、"
                    f"`git cat-file -e origin/{ref}:{bpath}`）⇒ 死锚点等于没证据"
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
            # 第 10 轮复核 F-12：REF 的捕获组会把 `https:` 那段吃掉，于是
            # `https://host/logs/a.md:12` 传下来的 raw 是 `//host/logs/a.md`，
            # 上面那道 startswith("http") 挡不住 ⇒ 在"去掉反引号的原文"上判前缀。
            if "://" in scan[:m.start(1)][-9:] or raw.startswith("//"):
                continue
            target = resolve(raw, repo_root)
            if target is None:
                hits = bare_matches(raw, repo_root)
                if len(hits) == 1:
                    target = repo_root / hits[0]
                elif len(hits) > 1:
                    errs.append(
                        f":{n} 锚点 `{raw}:{want}` 在仓内有 {len(hits)} 个同名文件"
                        f"（如 {hits[0]}、{hits[1]}）⇒ 写法不清：补上目录，别让人猜是哪一份"
                    )
                    continue
            if target is None:
                # 跨仓形态（Issue #394）：首段是兄弟仓名 ⇒ 走 `git -C <兄弟仓>` 取对象。
                # 不先试这一下，跨仓的真实引用会被下面判成死锚点，逼人去删真证据。
                sib_name = raw.split("/", 1)[0] if "/" in raw else ""
                sib = sibling_repo_root(repo_root, sib_name) if sib_name else None
                if sib is not None:
                    cpath = raw.split("/", 1)[1]
                    ctotal = cross_blob_lines(sib, None, cpath)
                    if ctotal is None:
                        ANCHOR_STATS["dead"] += 1
                        errs.append(
                            f":{n} 跨仓锚点 `{raw}:{want}` 指不到 —— "
                            f"`git -C ../{sib_name} cat-file -e origin/develop:{cpath}` 无命中"
                            f"（未写 `@ref` ⇒ 基准取该仓集成线 `origin/develop`，再退 develop / HEAD / 工作树）"
                            f"⇒ 死锚点等于没证据"
                        )
                    elif want > ctotal:
                        ANCHOR_STATS["cross"] += 1
                        errs.append(
                            f":{n} 跨仓锚点 `{raw}:{want}` 越界：`{sib_name}` 的 `{cpath}` "
                            f"只有 {ctotal} 行（判据：`git -C ../{sib_name} show origin/develop:{cpath} | wc -l`）"
                        )
                    else:
                        ANCHOR_STATS["cross"] += 1
                    continue
                if sib_name and SIBLING_NAME.match(sib_name):
                    # 要求 2：缺兄弟仓时判红。静默放过 = 在 CI 上这条判据根本不存在。
                    ANCHOR_STATS["cross_missing"] += 1
                    errs.append(
                        f":{n} 跨仓锚点 `{raw}:{want}` 的仓 `{sib_name}` 不在工作区里"
                        f"（判据：`ls -d ../{sib_name}`）⇒ 缺兄弟仓时判红："
                        f"依赖工作树的校验器静默绿，在 CI 上等于这条判据根本不存在"
                    )
                    continue
                # 只有当这行确实在"引用一份日志/文件"时才判死锚点（sha 之类不误伤）
                if re.search(r"\.(log|md|dart|txt|py)$", raw):
                    ANCHOR_STATS["dead"] += 1
                    errs.append(
                        f":{n} 锚点 `{raw}:{want}` 指不到 —— 绝对路径、仓库根、git 索引三处都查过"
                        f"（判据：`git ls-files \"*{raw}\"` 无命中）⇒ 死锚点等于没证据"
                    )
                continue
            ANCHOR_STATS["local"] += 1
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

    # ①b 正向「末行」主张必须**就近**带锚（第 8 轮 F-7 的修法；第 10 轮补"整行有锚也放行"太宽；
    #     第 11 轮复核实测两个缴获形状 ⇒ 改成逐次出现、只看前 NEAR_ANCHOR 字的窗口）
    for n, line in enumerate(lines, 1):
        for m in re.finditer("末行", line):
            prev, around, tail = near(m.start(), line)
            if not LASTLINE_CLAIM.search(around):
                continue                    # 环绕窗里没有"在报读数"的形状 ⇒ 不归本尺
            if NEGATION.search(around):
                continue                    # 就近的显式否定 / 直角引号提及 ⇒ 在谈这个词
            if REF.search(prev) or BRANCH_REF.search(prev) or REF.search(tail) or BRANCH_REF.search(tail):
                continue
            errs.append(
                f":{n} 把某个读数称作「末行」但就近（前 {NEAR_ANCHOR} 字）没有 `文件:行号` 锚"
                f" ⇒ 无从核对（判据：补锚，或按本仓口径改写成「`+N` 统计行在 :行号、全文 X 行」）"
            )
            break                           # 一行只报一次，别把同一条病刷成一排

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

    # ③ 覆盖性主张：量词与"全…"同现时，必须给**可复跑的命令**；标点、单个 sha 都不算证据
    # （第 8 轮复核 F9：上一版"有证据即通过"，于是「四处全改成」后面挂一个 sha 就绿 ——
    #   而 sha 只能证明"有这么一笔提交"，证明不了"是四处"。）
    for n, line in enumerate(lines, 1):
        if not COVERAGE.search(line):
            continue
        m = QUANT.search(line)
        if m and not EVIDENCE_CMD.search(line):
            errs.append(
                f":{n} 覆盖性主张里的量词「{m.group(0).strip()}」没有可复跑命令"
                f"（sha / `#123` / 指针只能证明「有这个东西」，证明不了「是这个数」；"
                f"上一版把「：」「、」也算证据 ⇒ 见 `c53da6a:27` 的 `CMD_MARK`）"
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
        else:
            # 给了命令还不够（第 8 轮复核 F10）：命令得真跑得出命中。
            for gm in CLAIMED_GREP.finditer(line):
                hits = grep_hits(repo_root, gm.group(1), gm.group(2))
                if hits == 0:
                    errs.append(
                        f":{n} 拿 `{gm.group(0)}` 当证据，但这条命令跑出来是 0 命中"
                        f"（BRE / -E / -F 三种都试了，判据在仓库根现跑）⇒ 脚本里没这句话"
                    )
    # ⑤「N 处/N 个/N 条…」紧跟括号枚举 ⇒ 项数必须等于 N
    #    （第 8 轮 F-9 的修法，第 10 轮复核复判仍空转。③ 只问"有没有可复跑命令"，
    #     于是「四处…（`grep …` = 4）：A、B、C」带着命令也照绿 —— 命令给不了"项数"这件事）
    for n, line in enumerate(lines, 1):
        for cm in COUNT_ENUM.finditer(line):
            num = cm.group(1)
            want = int(num) if num.isdigit() else CN_NUM.get(num)
            if want is None:
                continue
            items = [x for x in re.split(r"[、；;]", cm.group(3).strip()) if x.strip()]
            if len(items) < 2 or len(items) == want:
                continue
            errs.append(
                f":{n} 写「{num}{cm.group(2)}」，紧跟的括号里却枚举了 {len(items)} 项"
                f"（{cm.group(0).strip()[:60]}…）⇒ 数与项对不上：改数或补齐项"
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
    ("分支锚点·分支只在 origin 上（干净克隆的形状）", "①",
     "见 `feat/remote-only:specs/x/tasks.md:2` 的同款写法。\n", False),
    ("脚本归属·点名且给出证明命令", "④",
     "由脚本 `tool/check_spec_selfscan.py` 产出"
     "（判据：`grep -n \"errs.append\" tool/check_spec_selfscan.py`）\n", False),
    ("脚本归属·命令跑了但 0 命中（F10 的形状）", "④",
     "每条读数都由 `tool/check_spec_selfscan.py` 产出"
     "（判据：`grep -n \"这句话脚本里根本没有\" tool/check_spec_selfscan.py`）\n", True),
    ("锚点·裸文件名唯一命中（本仓惯例，旧版误判死）", "①",
     "见 `ok.md:2` 的读数。\n", False),
    ("锚点·裸文件名越界（解析到了仍要核行数）", "①",
     "见 `ok.md:9` 的读数。\n", True),
    ("锚点·裸文件名有歧义（两份同名 ⇒ 该补目录）", "①",
     "见 `dup.md:1` 的读数。\n", True),
    ("量词·只挂一个 sha 当证据（F9 的形状）", "③",
     "四处全改成统计行（见 876c35e）\n", True),
    ("轮号·写成「都判过」的少报区间（F8 的形状）", "②",
     "## 第 1 轮\n## 第 2 轮\n## 第 3 轮\n- 第 1–2 轮复核都判过\n", True),
    ("轮号·写成「都判过」且区间照抄", "②",
     "## 第 1 轮\n## 第 2 轮\n## 第 3 轮\n- 第 1–3 轮复核都判过\n", False),
    # ①b：正向「末行」主张没锚（第 10 轮复核 F-7：① 只在"这行有锚"时才查，
    #      于是「统计行的 +907 就是末行」整条漏网 ⇒ 判据当时是死的）
    ("末行·正向读数主张没有任何锚（F-7 的形状）", "①b",
     "统计行的 `+907` 就是末行。\n", True),
    ("末行·正向读数主张带真锚（①b 的绿对照）", "①b",
     "统计行 `+9` 是末行（`logs/gates.log:9`，全文 9 行）\n", False),
    # 第 11 轮复核缴获的两个形状，从此各钉一条语料：
    ("末行·ASCII 引用紧贴主张不算提及（①b 须红）", "①b",
     '旧措辞指的 `+907` 就是"末行"。\n', True),
    ("末行·同行别处的锚不豁免后一个主张（①b 须红）", "①b",
     "统计行 `+9` 是末行（`logs/a.log:9`）+ `+18 All tests passed!` 那行就是末行。\n", True),
    ("末行·谈这个写法本身的元语言（①b 豁免）", "①b",
     "本条只谈「末行」这个写法，`+907` 不是末行。\n", False),
    ("末行·显式否定（第 11 轮：纠正句曾被判成假失项）", "①b",
     "旧措辞指的 `+9` 那一行不是物理末行。\n", False),
    ("末行·引号开在词前 = 提及而非使用", "①b",
     "本条只谈「末行的写法」这一条规则，`+907` 是统计行。\n", False),
    ("末行·ASCII 闭引号不算开引号（台账 447 行的形状）", "①b",
     "的 `grep -c \"^  ok\"` = 26、末行「与期望不符的判据 = 0 条」。\n", True),
    ("末行·否定与主张之间隔着逗号不算否定", "①b",
     "这个数不是靠猜的，`+907` 就是末行。\n", True),
    ("末行·引号开在词后不算提及（444 行的形状仍须红）", "①b",
     "统计行 `+907` 就是末行「与期望不符的判据 = 0 条」。\n", True),
    # ⑤：计数词紧跟括号枚举 ⇒ 项数比对（第 10 轮复核 F-9：③ 只问"有没有可复跑命令"，
    #    带着命令的「四处…（A、B、C）」仍然绿 —— 命令证不了项数）
    ("计数词·带可复跑命令但括号只枚举三项（F-9 的形状）", "⑤",
     "四处全改成统计行（A、B、C）（`grep -c \"^+9\" logs/gates.log` = 4）\n", True),
    ("计数词·括号枚举项数与数一致", "⑤",
     "四处全改成统计行（A、B、C、D）（`grep -c \"^+9\" logs/gates.log` = 4）\n", False),
    ("计数词·括号里不是枚举（无顿号）⇒ 不比项数", "⑤",
     "四处全改成统计行（`grep -c \"^+9\" logs/gates.log` = 4）\n", False),
    # ① 的 URL 假阳性（第 10 轮复核 F-12：反引号里的 http 链接被切成 `//example.com/…:12` 死锚点）
    ("锚点·整串是 URL 不当死锚点查", "①",
     "见 `https://example.com/logs/a.md:12` 的原文。\n", False),

    # ---------- 跨仓锚点（Issue #394）：绿红必须成对，否则新判据可能恒真 ----------
    # 绿：`<兄弟仓>/<路径>:<行>` 打得到 —— 那份文件只存在于兄弟仓里。
    ("跨仓锚点·兄弟仓里真有这个文件", "①",
     "跨仓判据见 `zh-cloud-sibling-fixture/lib/only-remote.dart:2` 那一行。\n", False),
    # 红：把仓名去掉（要求 4 的变异）。同一条路径在本仓里不存在 ⇒ 必须红。
    # 这一对是「新判据有判别力、不是恒绿」的证明：同一份内容，带仓名绿、不带仓名红。
    ("跨仓锚点·去掉仓名就变成本仓死锚点（要求 4 的变异）", "①",
     "跨仓判据见 `lib/only-remote.dart:2` 那一行。\n", True),
    # 红：缺兄弟仓（要求 2）。静默放过 = 在 CI 上这条判据根本不存在。
    ("跨仓锚点·缺兄弟仓判红（要求 2）", "①",
     "见 `zh-cloud-absent-repo/lib/x.dart:1` 的统计行。\n", True),
    # 红：跨仓锚点越界（兄弟仓那份文件只有 3 行）。
    ("跨仓锚点·行号越界", "①",
     "见 `zh-cloud-sibling-fixture/lib/only-remote.dart:99` 的统计行。\n", True),
    # 绿：`@ref` 形态（基准 ref 显式写在 `@` 后面）。兄弟仓没有 git 对象 ⇒
    # 走「回落到工作树文件」那一支，仍应判绿。
    ("跨仓锚点·@ref 形态", "①",
     "见 `zh-cloud-sibling-fixture@origin/develop:lib/only-remote.dart:1` 那一行。\n", False),
]


def selftest(_unused: Path | None = None) -> int:
    """每条语料都必须按期望结果走：该红的红、该绿的绿。

    ⚠️ 语料用的假文件一律建在**临时目录**里，绝不在被审仓库下落 `logs/`
    （上一版的自检会在仓库根造文件，那本身就是对被审工作树的写操作）。
    """
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        # 本仓放进一层工作区目录里，好让**兄弟仓**能落在它旁边（跨仓判据要用，Issue #394）。
        workspace = Path(td)
        root = workspace / "repo"
        root.mkdir()
        # 兄弟仓用一个**只有工作树、没有 git 对象**的目录：`cross_blob_lines` 的
        # 「git 取不到就回落到工作树文件」那一支因此被真的走到，且不依赖本机有没有 git。
        sibling = workspace / "zh-cloud-sibling-fixture"
        (sibling / "lib").mkdir(parents=True)
        (sibling / ".git").write_text("gitdir: nowhere\n", encoding="utf-8")
        (sibling / "lib" / "only-remote.dart").write_text("a\nb\nc\n", encoding="utf-8")
        (root / "logs").mkdir()
        (root / "logs" / "gates.log").write_text("h\ni\nj\nk\nl\nm\nn\no\np\n", encoding="utf-8")
        (root / "logs" / "ok.md").write_text("one\ntwo\nthree\n", encoding="utf-8")
        # 裸文件名判据要有 PRESENT/ABSENT/歧义 三组：dup.md 故意在两个目录下各放一份
        (root / "tool").mkdir()
        (root / "logs" / "dup.md").write_text("one\ntwo\nthree\n", encoding="utf-8")
        (root / "tool" / "dup.md").write_text("one\ntwo\nthree\n", encoding="utf-8")
        (root / "tool" / "check_spec_selfscan.py").write_text(
            "def f():\n    errs.append('x')\n", encoding="utf-8")
        # 「分支锚点」这条判据要 PRESENT/ABSENT 成对，就得有个真 git 仓库当基准；
        # 建在同一个临时目录里，收尾随目录一起消失。git 不可用时**显式说明跳过**，
        # 不许静默把该红的放过（那等于把判据降级成摆设）。
        skipped: set[str] = set()
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
            # 「干净克隆」的形状：分支只有 `origin/<分支>`、本地同名 ref 不存在。
            # 造法 = 起一个裸仓当 origin、把基线推成另一根分支名、fetch 回来。
            # 裸仓建在 root 里面、且**必须排在 `add -A` 之后**，否则会被扫进索引。
            bare = root / "origin.git"
            for cmd in [
                ["git", "init", "-q", "--bare", str(bare)],
                ["git", "-C", str(root), "remote", "add", "origin", str(bare)],
                ["git", "-C", str(root), "push", "-q", "origin",
                 "HEAD:refs/heads/feat/remote-only"],
                ["git", "-C", str(root), "fetch", "-q", "origin"],
            ]:
                subprocess.run(cmd, capture_output=True)
            has_remote_only = subprocess.run(
                ["git", "-C", str(root), "rev-parse", "--verify", "--quiet",
                 "refs/remotes/origin/feat/remote-only"],
                capture_output=True).returncode == 0
            if not has_remote_only:
                skipped.add("分支锚点·分支只在 origin 上（干净克隆的形状）")
                print("  ⚠️ origin 上的 `feat/remote-only` 没建起来 ⇒ "
                      "「只在 origin 上有」这条不计入（明说，不静默）")
        else:
            skipped.update({
                "分支锚点·分支与 blob 都在（走 git 不走文件系统）",
                "分支锚点·分支只在 origin 上（干净克隆的形状）",
            })
            print("  ⚠️ 临时 git 仓库建不起来 ⇒ 分支锚点的 PRESENT 两条不计入"
                  "（ABSENT 一条仍会判，且它只依赖 `cat-file` 失败）")
        return _run_corpus(root, skipped)


def _run_corpus(root: Path, skip: set[str] | None = None) -> int:
    bad = 0
    skip = skip or set()
    for name, tag, text, expect_red in CORPUS:
        if name in skip:
            print(f"  跳过 [{tag}] {name}（夹具的前置条件没搭起来）")
            continue
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
    # 要求 3：把锚点分类计数打出来。豁免不计数就会变成免死金牌，
    # 下一轮没人知道覆盖率是不是靠"没跑"撑起来的。
    st = ANCHOR_STATS
    print(
        f"  锚点分类：本仓可比对 {st['local']} / 跨仓可比对 {st['cross']}"
        f" / 跨仓缺兄弟仓（判红）{st['cross_missing']} / 判成不成立 {st['dead']}"
    )
    rc = 1 if errs else 0
    if a.selftest:
        print("自检（自带语料，不碰 /tmp；该红的必须红、该绿的必须绿）：")
        n = selftest()
        print(f"  与期望不符的判据 = {n} 条")
        rc = rc or (1 if n else 0)
    return rc


if __name__ == "__main__":
    sys.exit(main())
