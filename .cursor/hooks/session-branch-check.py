#!/usr/bin/env python3
"""sessionStart: 注入当前 Git 分支；受保护分支时强提醒（Cursor + Claude Code）。"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))

from zh_cloud_hooks import (  # noqa: E402
    cursor_session_start_output,
    current_branch,
    find_git_root,
    is_claude_mode,
    is_protected_branch,
    read_stdin_json,
    resolve_workspace_root,
    session_start_output,
)

payload = read_stdin_json()
root = find_git_root(resolve_workspace_root(Path(__file__)))
if root is None:
    print("{}")
    raise SystemExit(0)

branch = current_branch(root)

if branch is None:
    message = (
        "【Git】未检出分支（detached HEAD 或非 Git 目录）。"
        "编写代码前请 git checkout develop 并创建 feat/* 或 fix/* 分支。"
    )
    if is_claude_mode(payload):
        session_start_output(None, False, message)
    else:
        cursor_session_start_output(None, False, message)
    raise SystemExit(0)

if not is_protected_branch(branch):
    message = f"【Git】当前分支：`{branch}`。功能开发请使用 feat/* 或 fix/* 分支。"
    if is_claude_mode(payload):
        session_start_output(branch, False, message)
    else:
        cursor_session_start_output(branch, False, message)
    raise SystemExit(0)

message = (
    f"【Git 门禁】当前分支：`{branch}`（main/develop/master 受保护）。"
    "禁止在此分支直接编写业务代码或做功能向 commit。"
    "开工前请切到 feat/* 或 fix/* 分支；合并只走 PR。"
)
if is_claude_mode(payload):
    session_start_output(branch, True, message)
else:
    cursor_session_start_output(branch, True, message)
