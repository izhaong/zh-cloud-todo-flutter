#!/usr/bin/env python3
"""preToolUse: 受保护分支禁止改文件；Shell/Bash 内 git commit 拦截。"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))

from zh_cloud_hooks import (  # noqa: E402
    allow,
    current_branch,
    cwd_from_payload,
    deny,
    find_git_root,
    is_edit_tool,
    is_protected_branch,
    is_shell_tool,
    protected_branch_message,
    read_stdin_json,
    shell_command_from_payload,
)

GIT_COMMIT_RE = re.compile(
    r"(?:^|[;&|]\s*)git(?:\s+-C\s+\S+)?\s+commit\b",
    re.IGNORECASE,
)
SKIP_COMMIT_FLAGS = re.compile(
    r"\b(--dry-run|-n|--help|-h)\b",
    re.IGNORECASE,
)

payload = read_stdin_json()
tool_name = str(payload.get("tool_name") or "")
start = cwd_from_payload(payload, Path(__file__))
git_root = find_git_root(start)
if git_root is None:
    allow(payload)
    raise SystemExit(0)

branch = current_branch(git_root)
if not is_protected_branch(branch):
    allow(payload)
    raise SystemExit(0)

user_msg, agent_msg = protected_branch_message(branch)

if is_shell_tool(tool_name):
    command = shell_command_from_payload(payload)
    if GIT_COMMIT_RE.search(command) and not SKIP_COMMIT_FLAGS.search(command):
        deny(
            f"受保护分支 `{branch}` 上禁止 git commit。请先切到 feat/* 或 fix/* 分支。",
            agent_msg,
            payload,
        )
        raise SystemExit(0)
    allow(payload)
    raise SystemExit(0)

if is_edit_tool(tool_name):
    deny(user_msg, agent_msg, payload)
    raise SystemExit(0)

allow(payload)
