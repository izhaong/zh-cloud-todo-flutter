#!/usr/bin/env python3
"""判据：`specs/` 的编号在 **develop ∪ 全部未合并分支** 上是一对一（FL #395 / service #309）。

## 为什么要有这把尺

取号只看 develop 会撞号：目录名不同 ⇒ git 不冲突 ⇒ 四条都能合进 develop，
但**引用层面**「specs/045」合完之后有四个所指，矩阵任何一格引它都可能拿别的面当证据。
本仓 045 撞过四回（2026-09 那轮）、090 与 105 各撞过两回（2026-10-11/12）。

## 判据形状

对每根 `origin/*` 分支读 `<branch>:specs/` 的目录名，抽出前导号，**按号聚合目录名**：

- 同一号在**同一根分支**上对应多个目录名 ⇒ 红（该分支自己就自相矛盾）。
- 同一号在**不同分支**上对应多个目录名，且这些目录名**都能在 develop 上同时存在**
  ⇒ 红（真正的「都会合进来」那种撞号）。
- 同一号只在 develop 上有一个目录、其它分支只是同一目录的另一版本 ⇒ 不算撞。
  （判别办法：把所有候选目录名去重，只留**也出现在 develop 上**的，或**分支尚未合并**的。）

## 自检

`--selftest` 造一个假仓：先造「同号两目录都在 develop」的坏基线，**证明它会红**，
再还原成一对一证明它不误判。这是 FL #395 第 3 条明确要求的
「必须拿已知有错的基线证明它会红，别写完就当它有效」。

用法：
    python3 tool/check_spec_number_unique.py [--repo <path>] [--selftest]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

NUMBER = re.compile(r"^(\d+)-")


def git(repo: Path, *args: str) -> str:
    out = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        check=False,
    )
    return out.stdout if out.returncode == 0 else ""


def spec_dirs_of(repo: Path, ref: str) -> list[str]:
    """读 `ref:specs/` 下的目录名；取不到（分支没有 specs/）就回空表。"""
    raw = git(repo, "ls-tree", "-d", "--name-only", f"{ref}:specs")
    return [line.strip() for line in raw.splitlines() if line.strip()]


def branch_refs(repo: Path) -> list[str]:
    raw = git(
        repo,
        "for-each-ref",
        "--format=%(refname:short)",
        "refs/remotes/origin/",
    )
    refs = []
    for line in raw.splitlines():
        ref = line.strip()
        if not ref or ref.endswith("/HEAD"):
            continue
        # 只看 feature 线：develop / main 由 develop 那一份代表
        tail = ref.split("/", 1)[1] if "/" in ref else ref
        if tail.startswith(("feat/", "fix/", "chore/", "docs/")):
            refs.append(ref)
    return refs


def collisions(repo: Path) -> dict[str, set[str]]:
    """返回 {号: {目录名}}，只保留**真会同时出现在合并结果里**的多对一。

    关键是别把「陈旧分支上的旧目录名」算成占用 —— 那会让判据在改名之后永远红着。
    已实测（`git merge-tree <改名后> <改名前的分支>`）：旧名在合并结果里**消失**，
    因为 develop 一侧删除、分支一侧相对 merge-base 没动 ⇒ 删除生效。
    所以一根分支只有在**自己相对 merge-base 新增了某个目录名**时，才算它占了这个号。

    规则：
    - **当前工作树/HEAD** 上的目录名（这是「本分支」的事实源；在 develop 上跑就是
      develop 自己，在功能分支上跑就是「合完之后大概长这样」）。
    - 每个未合并分支只计入 `分支的 specs 目录名 - merge-base 的 specs 目录名`
      （即「这根分支新引入的目录名」）。
    """
    head_dirs = spec_dirs_of(repo, "HEAD")

    by_number: dict[str, set[str]] = {}

    def add(name: str) -> None:
        m = NUMBER.match(name)
        if m:
            by_number.setdefault(m.group(1), set()).add(name)

    for name in head_dirs:
        add(name)

    merged = set(git(repo, "branch", "-r", "--merged", "HEAD").split())
    for ref in branch_refs(repo):
        if ref in merged:
            continue
        base = git(repo, "merge-base", "HEAD", ref).strip()
        if not base:
            continue
        introduced = set(spec_dirs_of(repo, ref)) - set(spec_dirs_of(repo, base))
        for name in introduced:
            add(name)

    return {n: dirs for n, dirs in by_number.items() if len(dirs) > 1}


def run(repo: Path) -> int:
    bad = collisions(repo)
    if not bad:
        print("specs 编号一对一：0 处撞号")
        return 0
    print(f"specs 编号撞号：{len(bad)} 处 ⇒ 引用「specs/<NNN>」会有多个所指")
    for number in sorted(bad):
        print(f"  {number}: {', '.join(sorted(bad[number]))}")
    print("\n处置口径（FL #395 第 2 条）：先合的保号，后合的改名，"
          "改名那条同批改掉自己台账里的自引用。")
    return 1


def selftest() -> int:
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        subprocess.run(["git", "init", "-q", "-b", "develop", str(repo)], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "config", "user.email", "selftest@example.invalid"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(repo), "config", "user.name", "selftest"], check=True
        )

        def commit(dirs: list[str], msg: str) -> None:
            for d in dirs:
                (repo / "specs" / d).mkdir(parents=True, exist_ok=True)
                (repo / "specs" / d / "spec.md").write_text("# x\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
            subprocess.run(
                ["git", "-C", str(repo), "commit", "-q", "-m", msg], check=True
            )

        # ① 干净基线：一对一 ⇒ 不红
        commit(["044-a", "045-b"], "干净基线")
        subprocess.run(
            ["git", "-C", str(repo), "update-ref", "refs/remotes/origin/develop", "HEAD"],
            check=True,
        )
        ok = run(repo)
        if ok != 0:
            print("SELFTEST FAIL(① 干净基线被误判为撞号)")
            return 1

        # ② 坏基线：同号两目录进 develop ⇒ 必须红（这条就是「证明它会红」）
        commit(["045-c"], "撞号")
        subprocess.run(
            ["git", "-C", str(repo), "update-ref", "refs/remotes/origin/develop", "HEAD"],
            check=True,
        )
        if run(repo) == 0:
            print("SELFTEST FAIL(② 同号两目录未判红 —— 这把尺是恒绿的)")
            return 1

        # ③ 同号同目录名在不同分支（同一规格的另一版本）⇒ 不该误判
        subprocess.run(
            ["git", "-C", str(repo), "checkout", "-q", "-b", "feat/x", "HEAD~1"],
            check=True,
        )
        (repo / "specs" / "045-b" / "spec.md").write_text("# y\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "commit", "-q", "-m", "同目录另一版本"], check=True
        )
        subprocess.run(
            ["git", "-C", str(repo), "update-ref", "refs/remotes/origin/feat/x", "HEAD"],
            check=True,
        )
        # develop 仍是坏基线 ⇒ 仍应红；这里量的是「feat/x 没带来**新**目录名」，
        # 即把 045-c 从 develop 拿掉后应只剩一对一。
        subprocess.run(
            ["git", "-C", str(repo), "checkout", "-q", "develop"], check=True
        )
        subprocess.run(
            ["git", "-C", str(repo), "rm", "-q", "-r", "specs/045-c"], check=True
        )
        subprocess.run(
            ["git", "-C", str(repo), "commit", "-q", "-m", "还原一对一"], check=True
        )
        subprocess.run(
            ["git", "-C", str(repo), "update-ref", "refs/remotes/origin/develop", "HEAD"],
            check=True,
        )
        if run(repo) != 0:
            print("SELFTEST FAIL(③ 同一目录的另一版本被误判成撞号)")
            return 1

        # ④ 关键回归：develop 上把 045-c **改名**到 139-c，另有一根分支还停在
        # 改名前的状态（它上面照旧有 045-c）。这根陈旧分支**不该**让判据继续红 ——
        # 实测 `merge-tree` 里旧名会消失（develop 删除、分支未改 ⇒ 删除生效）。
        # 这条正是「把陈旧分支的旧目录名误当占用」那个 bug 的探针。
        # 先把 045-c 加回来，让 develop 短暂回到撞号态，再从它拉出陈旧分支。
        commit(["045-c"], "重新引入 045-c 以便造陈旧分支")
        subprocess.run(
            ["git", "-C", str(repo), "update-ref", "refs/remotes/origin/develop", "HEAD"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(repo), "update-ref", "refs/remotes/origin/feat/stale", "HEAD"],
            check=True,
        )
        # develop 上把 045-c 改名为 139-c（陈旧分支不动，仍带 045-c）
        subprocess.run(
            ["git", "-C", str(repo), "mv", "specs/045-c", "specs/139-c"], check=True
        )
        subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "commit", "-q", "-m", "045-c 改名为 139-c"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(repo), "update-ref", "refs/remotes/origin/develop", "HEAD"],
            check=True,
        )
        if run(repo) != 0:
            print("SELFTEST FAIL(④ 陈旧分支上的旧目录名被误当成仍占用该号)")
            return 1

    print("SELFTEST OK(① 不误判 ② 会红 ③ 版本分叉不误判 ④ 陈旧分支不误判)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    return run(Path(a.repo).resolve())


if __name__ == "__main__":
    sys.exit(main())
