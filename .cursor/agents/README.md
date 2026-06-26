# zh-cloud Agent 索引（`.claude/agents/`）

本目录存放 **项目级 subagent** —— Claude Code / Cursor 在调度时按 `subagent_type` 选用的专家角色。
Agent 文件以 `name` + `description`（frontmatter）声明身份，正文为该角色的**工作手册**（权威参考、路由、流程、输出格式）。

> 规则与 Skills 见 `../rules/README.md` 与 `../skills/`；本目录**只放 Agent**。
> 个人全局 Agent 放 `~/.claude/agents/`，本目录 Agent 跟随仓库进 Git（团队共享）。
> Cursor 侧镜像：`.cursor/agents/`（内容应与 `.claude/agents/` 保持同步）。
> **各独立 Git 子仓**在 **`<repo>/.cursor/agents/`** 提交本仓用到的 Agent **副本**（非符号链接），单独克隆子仓即可调度 Subagent。

## 优先：按仓库选用（推荐）

| 仓库路径                         | Subagent `name`            | 技术栈                       |
| -------------------------------- | -------------------------- | ---------------------------- |
| `zh-cloud-service/`              | **`service-dev`**          | Java / Spring Boot / MyBatis |
| `zh-cloud-client/`               | **`client-dev`**           | React / Vite / shadcn        |
| `zh-cloud-admin-vben/`           | **`admin-vben-dev`**       | Vben AbpVue                  |
| `zh-cloud-admin-uniapp/`         | **`admin-uniapp-dev`**     | Admin UniApp                 |
| `zh-cloud-mall-uniapp/`          | **`mall-uniapp-dev`**      | 商城 UniApp                  |
| `zh-cloud-todo-flutter/`         | **`todo-flutter-dev`**     | Todo Flutter                 |
| `zh-cloud-beecount-flutter/`     | **`beecount-flutter-dev`** | BeeCount Flutter             |
| `zh-cloud-count/`                | **`count-flutter-dev`**    | Count + flutter_cloud_sync   |
| `zh-cloud-docs/`                 | **`docs-dev`**             | 知识库 / dev-docs            |
| `zh-cloud-rail-broadcast-web/`   | **`rail-broadcast-dev`**   | 轨交广播 Web                 |
| `zh-cloud/`（父仓 `.cursor` 等） | **`workspace-dev`**        | 规则 / Plan / MCP 配置       |

## 跨仓角色（兜底 / 流程）

| 触发场景                         | 推荐 Agent            | 备注                                                                  |
| -------------------------------- | --------------------- | --------------------------------------------------------------------- |
| 后端通用模式、手册、cwd 未明确   | `backend-java-dev`    | 单仓实现优先 **`service-dev`**                                        |
| 前端通用模式、多栈对照           | `frontend-dev`        | 单仓优先 **`client-dev`** / **`admin-*-dev`** / **`mall-uniapp-dev`** |
| Flutter 通用模式、Dart MCP       | `flutter-dev`         | 单仓优先 **`*-flutter-dev`**                                          |
| JUnit、接口冒烟、回归            | `qa-engineer`         |                                                                       |
| 跨仓规划、里程碑、RAID、状态报告 | **`project-manager`** | 不写业务代码                                                          |
| 架构调研、跨模块方案             | `Plan`                | 系统内置                                                              |
| 仓库扫描定位（只读）             | `Explore`             | 系统内置                                                              |
| 库文档查询                       | `docs-researcher`     | 系统内置                                                              |

## 角色边界

- **`product-manager-role.mdc`（Rule）**：产品视角 ——「做对的东西」
- **`project-manager`（Agent）**：项目管理 ——「把东西做对、按时、不出乱子」
- **`zh-cloud-mb-cycle` Skill**：长跑交付 B 切片执行循环

三者互补：产品定做什么，PM 盯怎么做，mb-cycle 跑批量执行。

## 添加新 Agent 的约定

1. 文件名 = `name`（kebab-case），frontmatter `name` 字段同步
2. `description` 一行写清**身份 + 核心能力 + 主动使用场景**（含 **cwd / 仓库路径**）
3. 正文结构：**仓库定位 → 会话启动 → 命令/路径表 → 边界 → 输出格式**；跨仓共性引用角色兜底 agent，避免重复粘贴
4. 中文交流，遵循 `.claude/rules/00-zh-cloud-core.mdc`
5. 提交后在本 README 两表登记；同步 `.cursor/agents/` 与 `AGENTS.md` 路由
6. 新领域优先考虑 **Rule**（持续门禁）还是 **Agent**（按需调度）
