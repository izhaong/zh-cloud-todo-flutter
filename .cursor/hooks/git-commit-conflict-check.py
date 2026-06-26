#!/usr/bin/env python3
"""Cursor / Claude Code hook：在 git commit 前检查合并冲突。

触发：
- Cursor `beforeShellExecution`（matcher: git commit）
- Cursor `preToolUse`（matcher: Shell）
- Claude Code `PreToolUse`（matcher: Bash，`if`: `Bash(git commit *)`）

检查项：
1. 工作区/索引是否存在未合并路径（`diff-filter=U`）
2. 当前分支与集成线 `origin/develop`（`hotfix/*` → `origin/main`）模拟合并是否冲突（`git merge-tree`）

故障策略：脚本异常 fail open；检测到冲突则 deny。
日志：`.cursor/hooks/.git-commit-conflict-check.log`
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))

from zh_cloud_hooks import (  # noqa: E402
    allow as hook_allow,
    ask as hook_ask,
    cwd_from_payload,
    deny as hook_deny,
    is_shell_tool,
    read_stdin_json,
    shell_command_from_payload,
)

WORKSPACE = Path(__file__).resolve().parents[2]
LOG_FILE = WORKSPACE / ".cursor" / "hooks" / ".git-commit-conflict-check.log"

GIT_COMMIT_RE = re.compile(
    r"(?:^|[;&|]\s*)git(?:\s+-C\s+\S+)?\s+commit\b",
    re.IGNORECASE,
)
SKIP_COMMIT_FLAGS = re.compile(
    r"\b(--dry-run|-n|--no-verify|--help|-h)\b",
    re.IGNORECASE,
)

INTEGRATION_BRANCH = {
    "default": "develop",
    "hotfix": "main",
}


def log(msg: str) -> None:
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(f"[{ts}] {msg}\n")


def allow(raw: dict) -> None:
    hook_allow(raw)
    sys.exit(0)


def parse_hook_input(raw: dict) -> tuple[str, Path | None]:
    command = shell_command_from_payload(raw)
    if command:
        return command, cwd_from_payload(raw, Path(__file__))

    event = raw.get("hook_event_name", "")
    if event == "beforeShellExecution":
        return str(raw.get("command") or ""), Path(raw.get("cwd") or ".")
    if event == "preToolUse" and is_shell_tool(str(raw.get("tool_name") or "")):
        tool_input = raw.get("tool_input") or {}
        return str(tool_input.get("command") or ""), cwd_from_payload(raw, Path(__file__))
    return "", None


def is_git_commit_command(command: str) -> bool:
    if not command or not GIT_COMMIT_RE.search(command):
        return False
    return SKIP_COMMIT_FLAGS.search(command) is None


def git_root(start: Path) -> Path | None:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=start,
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    return Path(out.stdout.strip())


def git_output(repo: Path, *args: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def current_branch(repo: Path) -> str:
    out = git_output(repo, "branch", "--show-current")
    return (out.stdout or "").strip()


def integration_branch_name(branch: str) -> str:
    if branch.startswith("hotfix/"):
        return INTEGRATION_BRANCH["hotfix"]
    return INTEGRATION_BRANCH["default"]


def has_unmerged_paths(repo: Path) -> list[str]:
    out = git_output(repo, "diff", "--name-only", "--diff-filter=U")
    if out.returncode != 0:
        return []
    return [line for line in out.stdout.splitlines() if line.strip()]


def fetch_integration(repo: Path, branch: str) -> tuple[bool, str]:
    ref = f"origin/{branch}"
    try:
        out = git_output(repo, "fetch", "origin", branch, timeout=60)
    except subprocess.TimeoutExpired:
        return False, "fetch origin 超时"
    if out.returncode != 0:
        err = (out.stderr or out.stdout or "").strip()
        return False, err or f"无法 fetch {ref}"
    verify = git_output(repo, "rev-parse", "--verify", ref)
    if verify.returncode != 0:
        return False, f"远端引用 {ref} 不存在"
    return True, ref


def simulate_merge_conflicts(repo: Path, remote_ref: str) -> tuple[bool, str]:
    base = git_output(repo, "merge-base", "HEAD", remote_ref)
    if base.returncode != 0 or not base.stdout.strip():
        return False, f"无法计算 HEAD 与 {remote_ref} 的 merge-base"

    merge = git_output(
        repo,
        "merge-tree",
        base.stdout.strip(),
        "HEAD",
        remote_ref,
        timeout=45,
    )
    combined = (merge.stdout or "") + (merge.stderr or "")
    conflict_markers = (
        "CONFLICT",
        "changed in both",
        "<<<<<<<",
    )
    if merge.returncode != 0 or any(m in combined for m in conflict_markers):
        return True, remote_ref
    return False, ""


def deny_conflict(
    *,
    repo: Path,
    branch: str,
    integration: str,
    reason: str,
    raw: dict,
    unmerged: list[str] | None = None,
) -> None:
    lines = [
        f"仓库：{repo.name}",
        f"当前分支：{branch or '(detached)'}",
        f"集成线：origin/{integration}",
        f"原因：{reason}",
    ]
    if unmerged:
        lines.append("未合并文件：" + ", ".join(unmerged[:8]))
        if len(unmerged) > 8:
            lines.append(f"… 另有 {len(unmerged) - 8} 个")
    lines.extend(
        [
            "",
            "建议：",
            f"  git fetch origin {integration}",
            f"  git merge origin/{integration}   # 或 git rebase origin/{integration}",
            "解决冲突后再 commit。",
        ]
    )
    user_message = "提交已拦截：存在合并冲突或未合并文件。请先与集成线对齐。"
    agent_message = "\n".join(lines)
    log(f"DENY {repo} branch={branch} integration={integration} reason={reason}")
    hook_deny(user_message, agent_message, raw)
    sys.exit(0)


def ask_fetch_failure(repo: Path, branch: str, integration: str, detail: str, raw: dict) -> None:
    log(f"ASK fetch failed repo={repo} detail={detail}")
    hook_ask(
        (
            f"无法在提交前拉取 origin/{integration} 做冲突检查（{detail}）。"
            "若确认可离线提交，请授权继续。"
        ),
        (
            f"git commit 前冲突检查：fetch origin/{integration} 失败。\n"
            f"仓库：{repo}\n分支：{branch}\n错误：{detail}\n"
            "请用户确认是否仍要提交，或先修复网络/远端后再 commit。"
        ),
        raw,
    )
    sys.exit(0)


def run_checks(repo: Path, raw: dict) -> None:
    branch = current_branch(repo)
    integration = integration_branch_name(branch)

    unmerged = has_unmerged_paths(repo)
    if unmerged:
        deny_conflict(
            repo=repo,
            branch=branch,
            integration=integration,
            reason="工作区或索引存在未解决的合并冲突文件",
            raw=raw,
            unmerged=unmerged,
        )

    ok, ref_or_err = fetch_integration(repo, integration)
    if not ok:
        ask_fetch_failure(repo, branch, integration, ref_or_err, raw)
    remote_ref = ref_or_err

    has_conflict, detail = simulate_merge_conflicts(repo, remote_ref)
    if has_conflict:
        deny_conflict(
            repo=repo,
            branch=branch,
            integration=integration,
            reason=f"与 {detail} 模拟合并会产生冲突",
            raw=raw,
        )

    log(f"ALLOW {repo} branch={branch} integration={integration}")


def main() -> None:
    try:
        raw = read_stdin_json()
    except json.JSONDecodeError as exc:
        log(f"invalid json: {exc}")
        allow({})

    command, cwd = parse_hook_input(raw)
    if not is_git_commit_command(command):
        allow(raw)

    if cwd is None:
        allow(raw)

    repo = git_root(cwd.resolve())
    if repo is None:
        log(f"skip: not a git repo cwd={cwd}")
        allow(raw)

    try:
        run_checks(repo, raw)
    except subprocess.TimeoutExpired:
        log(f"timeout repo={repo}")
        ask_fetch_failure(repo, current_branch(repo), "develop", "git 命令超时", raw)
    except Exception as exc:  # noqa: BLE001 — hook must not crash agent
        log(f"error repo={repo} exc={exc!r}")
        allow(raw)

    allow(raw)


if __name__ == "__main__":
    main()
