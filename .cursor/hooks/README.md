# zh-cloud Cursor / Claude Code Hooks

本目录脚本由父仓维护，经 `scripts/bootstrap-repo-ai-config.sh` 同步到各 Git 子仓。

## 双工具配置

| 工具            | 配置文件                          | 事件命名                                                          |
| --------------- | --------------------------------- | ----------------------------------------------------------------- |
| **Cursor**      | `.cursor/hooks.json`              | `sessionStart`、`preToolUse`、`beforeShellExecution`（camelCase） |
| **Claude Code** | `.claude/settings.json` → `hooks` | `SessionStart`、`PreToolUse`、`Bash`（PascalCase）                |

脚本统一放在 **`.cursor/hooks/`**，Claude 与 Cursor **共用同一套 Python 实现**；`lib/zh_cloud_hooks.py` 根据 stdin 是否含 `hook_event_name` 自动输出对应 JSON 格式。

## 分支门禁（核心）

受保护分支：`main`、`develop`、`master`

- 会话开始提醒当前分支
- 受保护分支上 **禁止** `Write`/`Edit`/`StrReplace` 等改文件
- 受保护分支上 **禁止** `git commit`
- 拦截 force push、`reset --hard`、`--no-verify` 等

## 验证

- **Cursor**：Hooks 输出通道 / 设置 → Hooks
- **Claude Code**：终端执行 `/hooks` 查看已加载项

修改 `hooks.json` 或 `.claude/settings.json` 后保存；必要时重启会话。

## 父仓专属

`organize-plans.py` 仅在父仓 `hooks.parent` / `claude-settings.hooks.parent` 中启用，用于 Plan 归位到 `.cursor/plans/`。

## TTS 语音提示（可选）

脚本：`.cursor/hooks/speak-lifecycle.py`（已在各生命周期事件中注册，**默认不发声**）

```bash
# 推荐：配置文件（从 Dock 打开 Cursor 也会生效）
cp scripts/hooks-templates/tts-env.example.sh .cursor/hooks/tts.local.env

# 或终端 export（须从同一终端启动 IDE，Dock 启动读不到）
source scripts/hooks-templates/tts-env.example.sh

# 或全局：~/.config/zh-cloud/tts.env
```

**不播报的常见原因**：只改了 `tts-env.example.sh` 或只在终端 `source` 过，但 Cursor 从 Dock 启动 → Hook 子进程没有 `ZH_CLOUD_TTS=1`。用上面的 `tts.local.env` 即可。

默认（未设 `ZH_CLOUD_TTS_EVENTS`）只播 **会话开始 / 本轮结束**；要全生命周期播报请设 `ZH_CLOUD_TTS_EVENTS=all`。

| 变量                        | 说明                                       |
| --------------------------- | ------------------------------------------ |
| `ZH_CLOUD_TTS=1`            | 总开关                                     |
| `ZH_CLOUD_TTS_EVENTS`       | `all` 或逗号列表（如 `sessionStart,stop`） |
| `ZH_CLOUD_TTS_VOICE`        | macOS `say` 音色                           |
| `ZH_CLOUD_TTS_MIN_INTERVAL` | `preToolUse` 等高频事件最短间隔            |
| `ZH_CLOUD_TTS_VERBOSE=1`    | 关闭防抖（会连续播报，慎用）               |

自测：`ZH_CLOUD_TTS=1 .cursor/hooks/speak-lifecycle.py sessionStart`
