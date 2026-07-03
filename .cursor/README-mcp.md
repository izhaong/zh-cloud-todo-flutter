# Cursor MCP 本地配置

- **勿**将含真实 **Authorization**、**MinIO AK/SK**、**站点密钥** 的 `mcp.json` 提交到 Git。
- 复制 **`zh-cloud/.cursor/mcp.json.example`** 为 **`zh-cloud/.cursor/mcp.json`**（后者已被 `.gitignore` 忽略时，仅本机存在），按注释填入真实值。
- 若需团队共享结构，只更新 **`zh-cloud/.cursor/mcp.json.example`** 中的占位符说明，不填真值。

## Jenkins MCP

- **Jenkins 官方 MCP 插件**若提供无会话端点，Cursor 中建议使用 **`/mcp-server/stateless`（Stateless HTTP）**，避免有状态会话在负载均衡下因 **`Mcp-Session-Id` 粘贴性** 丢失而连接失败；本仓库结构里对应示例为： **`type: "http"`** + 上述 URL，凭据用 **`Authorization: Basic`（`user:Jenkins API Token` 的 Base64，见 Jenkins 用户设置 → API Token）** 或后续插件支持的等价方式，**真值只放本机 `.cursor/mcp.json`（已在 `.gitignore`）**。
- 若你方 Jenkins/插件**仍只支持**有状态 Streamable 端点（如原 **`/mcp-server/mcp`**），可只改 URL 不改 `type`，以插件文档为准。
- **本仓 Job 名与 URL**（`getJob` / `getBuild` 用 `jobFullName`）：见 **`docs/engineering/01-ci-jenkins.md`**（test：`zh-cloud-test/zh-cloud-todo-flutter`；控制台 https://jenkins.zh04.com/view/test/job/zh-cloud-test/job/zh-cloud-todo-flutter/ ）。

## Cloudflare API MCP（DNS 等全量 API）

用于通过 **Codemode** 调用 Cloudflare 全量 API（含 **DNS 记录增删改查**、Workers、R2 等）。与 `cloudflare-docs` / `cloudflare-bindings` 等产品向 MCP **互补**：后三者**不能**创建 DNS 记录。

**推荐（交互）**：OAuth，无需在配置里写 Token。

```json
"cloudflare-api": {
  "type": "http",
  "url": "https://mcp.cloudflare.com/mcp"
}
```

首次连接 Cursor 会打开浏览器完成 Cloudflare 授权；权限至少包含目标 Zone 的 **DNS:Edit**（可用 Dashboard 模板「Edit zone DNS」）。

**可选（CI / 无浏览器）**：在 [API Tokens](https://dash.cloudflare.com/profile/api-tokens) 创建 Token（Zone:Read + DNS:Edit），用环境变量注入，勿提交 Git：

```json
"cloudflare-api": {
  "type": "http",
  "url": "https://mcp.cloudflare.com/mcp",
  "headers": {
    "Authorization": "Bearer ${env:CLOUDFLARE_API_TOKEN}"
  }
}
```

工具面：主要为 `search()`（查 API 端点）与 `execute()`（执行 API 调用）。示例口令：「列出 zh04.com 的 DNS 记录」「为 client-todo-test.zh04.com 添加 A 记录指向 x.x.x.x」。

官方说明：[Cloudflare's own MCP servers](https://developers.cloudflare.com/agents/model-context-protocol/cloudflare/servers-for-cloudflare/)。

## Gitea MCP

建议在本机 **`.cursor/mcp.json`** / **`.claude/mcp.json`** 配置 Gitea MCP（常用别名：`user-gitea` 或 `project-0-zh-cloud-gitea`），用于 Issue / PR / milestone / label 的程序化核对与更新。

**完整 HTTP 配置示例**（Streamable HTTP；Token 勿提交 Git）：

```json
"gitea": {
  "type": "http",
  "url": "https://mcp-gitea.zh04.com/mcp",
  "headers": {
    "Authorization": "Bearer ${env:GITEA_MCP_TOKEN}",
    "Accept": "application/json, text/event-stream",
    "Content-Type": "application/json"
  }
}
```

常用场景：

- 创建或更新工作项 Issue（对应规则：先 Issue，后一 Issue 一分支）。
- 查询 Issue、PR、评论、label、milestone 与截止日期。
- 在允许的情况下补充 Issue 评论、关闭已验收工作项、对齐本地里程碑镜像。
- 核对多仓 Issue 互链：父仓 `zh-cloud-service` 与子仓 `zh-cloud-count`、`zh-cloud-admin-vben`、`zh-cloud-admin-uniapp`。

边界：

- 分支保护、仓库默认分支、凭据、Webhook 等高权限配置仍以 Gitea / Jenkins 控制台为准；当前 MCP 不作为批量改保护规则的唯一手段。
- 本地仓库内的 `zh-cloud-service/docs/engineering/*issue*` 与 **`zh-cloud/.cursor/plans/*.plan.md`** 仍是 Agent 首读材料；只有缺编号、要核对线上状态或要写回 Issue 时才调用 Gitea MCP。
- 不要把真实 token、cookie、Authorization header 写进仓库；只放在本机 **`zh-cloud/.cursor/mcp.json`**（或用 Cursor 用户级 MCP 配置）。

详见 **`zh-cloud/.cursor/rules/ci-secrets-hygiene.mdc`**、**`zh-cloud/.cursor/rules/00-zh-cloud-core.mdc`**（敏感信息节）。
