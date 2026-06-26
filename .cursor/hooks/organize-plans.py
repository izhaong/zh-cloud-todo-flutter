#!/usr/bin/env python3
"""Cursor hook: 把新风格 Plan 从临时目录归位到 `.claude/plans/<app>/`。

触发：
- `stop`           Plan / Agent 执行结束后扫描（主触发）
- `afterFileEdit`  编辑含 .plan.md 时扫描
- `postToolUse`    Write 工具写入 .plan.md 后立即扫描

来源目录（仅扫描根下扁平 `*.plan.md`，不递归子目录）：
- ~/.claude/plans/              Cursor 自动落盘（仓外）
- <workspace>/.claude/plans/    误落在索引根下的 Plan

目标（权威正文，Cursor 可正确渲染 todos）：
- zh-cloud/.claude/plans/<app>/*.plan.md
- 归档：zh-cloud/.claude/plans/<app>/archive/

文件名约定（docs/_meta/plan-naming.md）：
    {YYYYMMDDHHmm}_{app}_{module}_{slug}.plan.md
    app ∈ {todo, count, health, mall, platform, shared, service, admin}
    shared → platform/；service/admin → 各自子目录

幂等：
- 源已在目标路径 → 跳过
- 目标存在且内容相同 → 仅删源
- 目标存在且内容不同 → 跳过 + 写冲突日志
- 否则移动；源在 git 仓内优先 `git mv`，否则 shutil.move + git add

故障策略：fail open。日志：`.claude/hooks/.organize-plans.log`。
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

WORKSPACE = Path(__file__).resolve().parents[2]
PLANS_ROOT = WORKSPACE / ".cursor" / "plans"
LOG_FILE = WORKSPACE / ".cursor" / "hooks" / ".organize-plans.log"

SOURCE_DIRS = [
    Path.home() / ".cursor" / "plans",
    PLANS_ROOT,
]

APP_TO_DIR = {
    "todo": "todo",
    "count": "count",
    "health": "health",
    "mall": "mall",
    "platform": "platform",
    "shared": "platform",
    "service": "service",
    "admin": "admin",
}

FILENAME_RE = re.compile(
    r"^(?P<ts>\d{12})_(?P<app>[a-z][a-z0-9]*)_(?P<module>[a-z0-9-]+)_(?P<slug>[a-z0-9-]+)\.plan\.md$"
)


def log(msg: str) -> None:
    line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n"
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line)
    except OSError:
        print(line, end="", file=sys.stderr)


def read_stdin_json() -> dict:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return {}
        return json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        log(f"WARN parse stdin: {exc}")
        return {}


def _paths_touch_plan_md(event: dict) -> bool:
    paths = list(event.get("file_paths") or [])
    single = event.get("file_path")
    if single:
        paths.append(single)
    tool_input = event.get("tool_input")
    if isinstance(tool_input, dict):
        for key in ("path", "file_path", "target_file"):
            val = tool_input.get(key)
            if isinstance(val, str):
                paths.append(val)
    elif isinstance(tool_input, str):
        try:
            parsed = json.loads(tool_input)
            if isinstance(parsed, dict):
                for key in ("path", "file_path", "target_file"):
                    val = parsed.get(key)
                    if isinstance(val, str):
                        paths.append(val)
        except json.JSONDecodeError:
            pass
    return any(str(p).endswith(".plan.md") for p in paths)


def should_run(event: dict) -> bool:
    name = event.get("hook_event_name", "")
    if name == "stop":
        return True
    if name in {"afterFileEdit", "postToolUse"}:
        if name == "postToolUse" and event.get("tool_name") not in {None, "Write"}:
            return False
        return _paths_touch_plan_md(event)
    return False


def files_equal(a: Path, b: Path) -> bool:
    try:
        return a.read_bytes() == b.read_bytes()
    except Exception:  # noqa: BLE001
        return False


def is_inside_git_repo(path: Path) -> Path | None:
    try:
        out = subprocess.run(
            ["git", "-C", str(path.parent), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=False,
        )
        if out.returncode == 0:
            return Path(out.stdout.strip())
    except Exception:  # noqa: BLE001
        return None
    return None


def git_run(cwd: Path, *args: str) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["git", "-C", str(cwd), *args],
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


def resolve_target(filename: str) -> Path | None:
    m = FILENAME_RE.match(filename)
    if not m:
        return None
    sub = APP_TO_DIR.get(m.group("app"))
    if not sub:
        return None
    return PLANS_ROOT / sub / filename


def relocate(src: Path) -> None:
    if not src.is_file():
        return
    name = src.name
    if name.startswith(".") or name == "README.md":
        return
    if not FILENAME_RE.match(name):
        log(f"SKIP 旧风格命名（非 {{YYYYMMDDHHmm}}_{{app}}_…）：{src}")
        return

    target = resolve_target(name)
    if target is None:
        log(f"SKIP 未识别 app：{src}")
        return

    try:
        if src.resolve() == target.resolve():
            return
    except Exception:  # noqa: BLE001
        pass

    target.parent.mkdir(parents=True, exist_ok=True)

    if target.exists():
        if files_equal(src, target):
            try:
                src.unlink()
                log(f"DEDUP 目标已存在且一致，删源：{src} -> {target}")
            except Exception as exc:  # noqa: BLE001
                log(f"ERR 删源失败 {src}: {exc}")
            return
        log(f"CONFLICT 目标已存在但内容不同，跳过：{src} -> {target}")
        return

    src_repo = is_inside_git_repo(src)
    workspace_repo = is_inside_git_repo(PLANS_ROOT)

    if src_repo and workspace_repo and src_repo == workspace_repo:
        rel_src_str = str(src.resolve().relative_to(src_repo))
        rel_dst_str = str(target.resolve().relative_to(src_repo))
        code, _, err = git_run(src_repo, "mv", rel_src_str, rel_dst_str)
        if code == 0:
            log(f"GITMV {src} -> {target}")
            return
        log(f"WARN git mv 失败，回退普通 mv：{err.strip()}")

    try:
        shutil.move(str(src), str(target))
    except Exception as exc:  # noqa: BLE001
        log(f"ERR mv 失败 {src} -> {target}: {exc}")
        return

    if workspace_repo:
        rel = str(target.resolve().relative_to(workspace_repo))
        code, _, err = git_run(workspace_repo, "add", "--", rel)
        if code == 0:
            log(f"MV+ADD {src} -> {target}")
        else:
            log(f"MV ok 但 git add 失败：{err.strip()}（{target}）")
    else:
        log(f"MV {src} -> {target}（目标不在 git 仓内）")


def scan_all() -> None:
    if not PLANS_ROOT.is_dir():
        PLANS_ROOT.mkdir(parents=True, exist_ok=True)
        log(f"INFO 已创建 {PLANS_ROOT}")
    for root in SOURCE_DIRS:
        if not root.is_dir():
            continue
        for entry in sorted(root.iterdir()):
            if entry.is_file() and entry.name.endswith(".plan.md"):
                try:
                    relocate(entry)
                except Exception as exc:  # noqa: BLE001
                    log(f"ERR 处理 {entry} 抛异常：{exc}")


def main() -> int:
    event = read_stdin_json()
    if not should_run(event):
        print("{}")
        return 0
    try:
        scan_all()
    except Exception as exc:  # noqa: BLE001
        log(f"FATAL scan_all: {exc}")
    print("{}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
