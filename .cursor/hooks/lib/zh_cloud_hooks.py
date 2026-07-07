"""Shared helpers for zh-cloud Cursor / Claude Code hooks."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

PROTECTED_BRANCHES = frozenset({"main", "develop", "master"})
EDIT_TOOL_NAMES = frozenset(
    {
        "Write",
        "StrReplace",
        "Delete",
        "EditNotebook",
        "ApplyPatch",
        # Claude Code
        "Edit",
        "MultiEdit",
        "NotebookEdit",
    }
)
SHELL_TOOL_NAMES = frozenset({"Shell", "Bash"})


def read_stdin_json() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def emit(obj: dict) -> None:
    print(json.dumps(obj, ensure_ascii=False))


def is_claude_mode(payload: dict) -> bool:
    return bool(payload.get("hook_event_name"))


def hook_event_name(payload: dict) -> str:
    return str(payload.get("hook_event_name") or "")


def allow(payload: dict | None = None) -> None:
    if payload and is_claude_mode(payload):
        emit({})
        return
    emit({"permission": "allow"})


def deny(
    user_message: str,
    agent_message: str | None = None,
    payload: dict | None = None,
) -> None:
    reason = agent_message or user_message
    if payload and is_claude_mode(payload):
        event = hook_event_name(payload) or "PreToolUse"
        if event == "PreToolUse":
            emit(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": reason,
                    }
                }
            )
            return
        if event in {"SessionStart", "Setup", "SubagentStart"}:
            emit(
                {
                    "hookSpecificOutput": {
                        "hookEventName": event,
                        "additionalContext": reason,
                    }
                }
            )
            return
        emit({"decision": "block", "reason": reason})
        return

    body: dict = {
        "permission": "deny",
        "user_message": user_message,
    }
    if agent_message:
        body["agent_message"] = agent_message
    emit(body)


def ask(
    user_message: str,
    agent_message: str | None = None,
    payload: dict | None = None,
) -> None:
    reason = agent_message or user_message
    if payload and is_claude_mode(payload):
        event = hook_event_name(payload) or "PreToolUse"
        if event == "PreToolUse":
            emit(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "ask",
                        "permissionDecisionReason": reason,
                    }
                }
            )
            return
        emit({"decision": "block", "reason": reason})
        return

    body: dict = {
        "permission": "ask",
        "user_message": user_message,
    }
    if agent_message:
        body["agent_message"] = agent_message
    emit(body)


def session_start_output(branch: str | None, protected: bool, message: str) -> None:
    env_branch = branch or ""
    env_flag = "1" if protected else "0"
    emit(
        {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": message,
            }
        }
    )
    env_file = os.environ.get("CLAUDE_ENV_FILE")
    if env_file:
        try:
            path = Path(env_file)
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("a", encoding="utf-8") as handle:
                handle.write(f"export ZH_CLOUD_GIT_BRANCH={env_branch!r}\n")
                handle.write(f"export ZH_CLOUD_PROTECTED_BRANCH={env_flag!r}\n")
        except OSError:
            pass


def cursor_session_start_output(branch: str | None, protected: bool, message: str) -> None:
    env_branch = branch or ""
    emit(
        {
            "env": {
                "ZH_CLOUD_GIT_BRANCH": env_branch,
                "ZH_CLOUD_PROTECTED_BRANCH": "1" if protected else "0",
            },
            "additional_context": message,
        }
    )


def shell_command_from_payload(payload: dict) -> str:
    tool_input = payload.get("tool_input") or {}
    return str(
        payload.get("command")
        or payload.get("full_command")
        or tool_input.get("command")
        or ""
    )


def cwd_from_payload(payload: dict, hook_file: Path) -> Path:
    tool_input = payload.get("tool_input") or {}
    cwd = (
        payload.get("cwd")
        or payload.get("working_directory")
        or tool_input.get("working_directory")
        or tool_input.get("cwd")
    )
    if cwd:
        return Path(cwd)
    return resolve_workspace_root(hook_file)


def find_git_root(start: Path | None = None) -> Path | None:
    cwd = (start or Path.cwd()).resolve()
    for directory in (cwd, *cwd.parents):
        if (directory / ".git").exists():
            return directory
    return None


def current_branch(git_root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(git_root), "branch", "--show-current"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    branch = (result.stdout or "").strip()
    return branch or None


def is_protected_branch(branch: str | None) -> bool:
    if not branch:
        return False
    return branch in PROTECTED_BRANCHES


def resolve_workspace_root(hook_file: Path) -> Path:
    for key in ("CLAUDE_PROJECT_DIR", "ZH_CLOUD_GIT_ROOT"):
        env_root = os.environ.get(key)
        if env_root:
            return Path(env_root).resolve()
    return hook_file.resolve().parents[1]


def protected_branch_message(branch: str) -> tuple[str, str]:
    user = (
        f"当前在受保护分支 `{branch}`（main/develop/master），禁止直接改代码。"
        "请先：`git fetch origin` → `git checkout develop` → `git pull --ff-only` → "
        "`git checkout -b feat/<简述>` 或 `fix/<简述>`，再开始编写。"
    )
    agent = (
        f"Git 分支为 `{branch}`（受保护集成/发布线）。"
        "在创建功能分支并得到用户确认之前，不得使用 Write/Edit/StrReplace 等工具修改业务文件，"
        "不得执行会产生功能向提交的 git commit。"
        "若用户明确要求在受保护分支做文档/chore/紧急热修，先请用户确认并说明范围。"
    )
    return user, agent


def is_edit_tool(tool_name: str) -> bool:
    return tool_name in EDIT_TOOL_NAMES


def is_shell_tool(tool_name: str) -> bool:
    return tool_name in SHELL_TOOL_NAMES

