#!/usr/bin/env python3
"""生命周期 TTS 提示（Cursor + Claude Code 共用）。

启用方式（任选其一，推荐配置文件，Dock 启动的 Cursor 也能读到）：
  1. 复制 scripts/hooks-templates/tts-env.example.sh → .cursor/hooks/tts.local.env
  2. 或 touch .cursor/hooks/tts.enabled（仅开总开关，事件用默认 sessionStart/stop）
  3. 或 ~/.config/zh-cloud/tts.env（全局，所有仓库生效）
  4. 或在启动 IDE 的终端里 export ZH_CLOUD_TTS=1

可选：
  export ZH_CLOUD_TTS_VOICE=Ting-Ting    # macOS `say -v ?` 列表中的音色
  export ZH_CLOUD_TTS_LANG=zh-CN
  export ZH_CLOUD_TTS_EVENTS=all           # 或逗号列表：sessionStart,stop,PreToolUse,...
  export ZH_CLOUD_TTS_MIN_INTERVAL=4       # 高频事件最短间隔（秒），默认 4
  export ZH_CLOUD_TTS_VERBOSE=1            # 跳过高频防抖（不推荐）

用法：在 hooks.json / settings.json 中为各事件注册：
  .cursor/hooks/speak-lifecycle.py <EventName>

事件名与 Cursor camelCase、Claude PascalCase 均可（脚本内会归一化）。
"""
from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent
# 仓库内防抖状态文件（按事件）
STATE_DIR = HOOK_DIR / ".tts-state"

EVENT_PHRASES: dict[str, str] = {
    "sessionstart": "会话开始",
    "sessionend": "会话结束",
    "pretooluse": "准备执行工具",
    "posttooluse": "工具执行完成",
    "posttoolusefailure": "工具执行失败",
    "beforeshellexecution": "即将运行终端命令",
    "aftershellexecution": "终端命令结束",
    "beforesubmitprompt": "提交提示词",
    "beforemcpexecution": "即将调用 MCP",
    "aftermcpexecution": "MCP 调用结束",
    "beforereadfile": "读取文件",
    "afterfileedit": "文件已修改",
    "stop": "本轮任务结束",
    "subagentstart": "子代理启动",
    "subagentstop": "子代理结束",
    "precompact": "上下文压缩",
    "afteragentresponse": "代理回复完成",
    "afteragentthought": "思考完成",
    "workspaceopen": "工作区已打开",
    "userpromptsubmit": "用户提交",
}

HIGH_FREQUENCY = frozenset(
    {
        "pretooluse",
        "posttooluse",
        "posttoolusefailure",
        "afterfileedit",
        "beforereadfile",
        "beforeshellexecution",
        "aftershellexecution",
        "beforemcpexecution",
        "aftermcpexecution",
    }
)


def normalize_event(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def _apply_env_line(line: str) -> None:
    line = line.strip()
    if not line or line.startswith("#"):
        return
    if line.startswith("export "):
        line = line[7:].strip()
    if "=" not in line:
        return
    key, _, value = line.partition("=")
    key = key.strip()
    value = value.strip().strip('"').strip("'")
    if key:
        os.environ.setdefault(key, value)


def load_tts_config() -> None:
    """从配置文件加载 TTS 开关（不覆盖已有环境变量）。"""
    if (HOOK_DIR / "tts.enabled").is_file():
        os.environ.setdefault("ZH_CLOUD_TTS", "1")

    for path in (
        Path.home() / ".config" / "zh-cloud" / "tts.env",
        HOOK_DIR / "tts.local.env",
    ):
        if not path.is_file():
            continue
        try:
            for line in path.read_text(encoding="utf-8").splitlines():
                _apply_env_line(line)
        except OSError:
            continue


def tts_enabled() -> bool:
    return os.environ.get("ZH_CLOUD_TTS", "").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def event_allowed(event_key: str) -> bool:
    raw = os.environ.get("ZH_CLOUD_TTS_EVENTS", "sessionStart,stop,SessionStart,Stop").strip()
    if raw.lower() in {"all", "*"}:
        return True
    allowed = {normalize_event(part) for part in raw.split(",") if part.strip()}
    return event_key in allowed


def read_stdin_json() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def resolve_event(argv: list[str], payload: dict) -> str:
    if len(argv) > 1 and argv[1].strip():
        return normalize_event(argv[1])
    if payload.get("hook_event_name"):
        return normalize_event(str(payload["hook_event_name"]))
    if payload.get("tool_name"):
        return "pretooluse"
    if payload.get("session_id") and not payload.get("tool_name"):
        return "sessionstart"
    return "unknown"


def phrase_for(event_key: str, payload: dict) -> str:
    base = EVENT_PHRASES.get(event_key, f"生命周期 {event_key}")
    tool = str(payload.get("tool_name") or "").strip()
    if tool and event_key in {"pretooluse", "posttooluse", "posttoolusefailure"}:
        return f"{base}：{tool}"
    return base


def should_debounce(event_key: str) -> bool:
    if os.environ.get("ZH_CLOUD_TTS_VERBOSE", "").strip().lower() in {"1", "true", "yes"}:
        return False
    return event_key in HIGH_FREQUENCY


def debounce_ok(event_key: str, min_interval: float) -> bool:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    stamp = STATE_DIR / f"{event_key}.ts"
    now = time.time()
    try:
        if stamp.exists():
            last = float(stamp.read_text(encoding="utf-8").strip())
            if now - last < min_interval:
                return False
        stamp.write_text(str(now), encoding="utf-8")
    except OSError:
        return True
    return True


def _spawn_tts(cmd: list[str]) -> None:
    """脱离 hook 进程组，避免 Cursor 3s 超时或脚本退出时杀掉 say。"""
    subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def speak(text: str) -> None:
    voice = os.environ.get("ZH_CLOUD_TTS_VOICE", "Ting-Ting").strip() or "Ting-Ting"
    lang = os.environ.get("ZH_CLOUD_TTS_LANG", "zh-CN").strip()

    if platform.system() == "Darwin" and shutil.which("say"):
        args = ["say"]
        if voice:
            args.extend(["-v", voice])
        args.append(text)
        _spawn_tts(args)
        return

    if shutil.which("espeak-ng"):
        _spawn_tts(["espeak-ng", "-v", lang, text])
        return
    if shutil.which("espeak"):
        _spawn_tts(["espeak", text])
        return

    if shutil.which("spd-say"):
        _spawn_tts(["spd-say", text])


def main() -> None:
    load_tts_config()
    payload = read_stdin_json()
    event_key = resolve_event(sys.argv, payload)

    # 观察型 hook：始终返回空 JSON，不阻断 Agent
    print("{}")

    if not tts_enabled():
        return
    if event_key == "unknown":
        return
    if not event_allowed(event_key):
        return

    try:
        min_interval = float(os.environ.get("ZH_CLOUD_TTS_MIN_INTERVAL", "4"))
    except ValueError:
        min_interval = 4.0

    if should_debounce(event_key) and not debounce_ok(event_key, min_interval):
        return

    speak(phrase_for(event_key, payload))


if __name__ == "__main__":
    main()
