#!/usr/bin/env python3
"""beforeShellExecution / PreToolUse(Bash): 拦截危险 git 命令。"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))

from zh_cloud_hooks import (  # noqa: E402
    allow,
    ask,
    current_branch,
    cwd_from_payload,
    deny,
    find_git_root,
    is_protected_branch,
    protected_branch_message,
    read_stdin_json,
    shell_command_from_payload,
)

payload = read_stdin_json()
command = shell_command_from_payload(payload)
start = cwd_from_payload(payload, Path(__file__))
git_root = find_git_root(start)
branch = current_branch(git_root) if git_root else None

DANGEROUS = [
    (re.compile(r"git\s+push\b[^\n]*--force\b", re.I), "禁止 force push。"),
    (re.compile(r"git\s+push\b[^\n]*\s-f\b", re.I), "禁止 force push（-f）。"),
    (re.compile(r"git\s+reset\s+--hard\b", re.I), "禁止 git reset --hard。"),
    (re.compile(r"git\s+clean\s+-fd", re.I), "禁止 git clean -fd（会删除未跟踪文件）。"),
    (re.compile(r"git\s+commit\b[^\n]*--no-verify\b", re.I), "禁止 --no-verify 绕过 hook。"),
]

for pattern, reason in DANGEROUS:
    if pattern.search(command):
        deny(f"Shell 被 hook 拦截：{reason}", f"命令：`{command}`", payload)
        raise SystemExit(0)

if git_root and is_protected_branch(branch):
    if re.search(r"(?:^|[;&|]\s*)git(?:\s+-C\s+\S+)?\s+commit\b", command, re.I):
        if not re.search(r"\b(--dry-run|-n|--help|-h)\b", command, re.I):
            user_msg, agent_msg = protected_branch_message(branch or "")
            deny(user_msg, agent_msg, payload)
            raise SystemExit(0)

    if re.search(r"git\s+push\b", command, re.I):
        if re.search(r"\borigin\s+(main|develop|master)\b", command, re.I):
            ask(
                f"即将向受保护分支 push（当前本地分支：`{branch}`）。确认这是用户授权的 chore/热修/发布操作？",
                "仅在用户明确授权时继续；功能开发应走 feat/* → PR → develop。",
                payload,
            )
            raise SystemExit(0)

allow(payload)
