#!/usr/bin/env python3
"""beforeShellExecution / PreToolUse(Bash): 网络命令含疑似密钥时 ask。"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))

from zh_cloud_hooks import allow, ask, read_stdin_json, shell_command_from_payload  # noqa: E402

payload = read_stdin_json()
command = shell_command_from_payload(payload)

SECRET_PATTERNS = [
    re.compile(r"Authorization:\s*Bearer\s+[A-Za-z0-9._-]{8,}", re.I),
    re.compile(r"password\s*=\s*[^\s\"']{6,}", re.I),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"-----BEGIN (RSA |EC )?PRIVATE KEY-----"),
    re.compile(r"token\s*=\s*[A-Za-z0-9._-]{20,}", re.I),
]

for pattern in SECRET_PATTERNS:
    if pattern.search(command):
        ask(
            "命令中可能包含密钥或 Token，请确认不会泄露到日志或提交历史。",
            "改用环境变量或占位符；勿在聊天/命令中粘贴真实凭据。",
            payload,
        )
        raise SystemExit(0)

allow(payload)
