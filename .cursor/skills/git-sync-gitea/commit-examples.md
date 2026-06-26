# Commit message 速查

## 格式

```text
<type>(<scope>): <中文摘要>
```

## type

`feat` `fix` `refactor` `perf` `docs` `style` `test` `chore` `ci` `build` `revert`

## scope 示例（zh-cloud）

| 仓库                         | scope 示例                                   |
| ---------------------------- | -------------------------------------------- |
| zh-cloud-service             | `count`、`member`、`告警`                    |
| zh-cloud-admin-vben          | `@vben/web-antd`、`ci`（Pipeline 一律 `ci`） |
| docs（Gitea: zh-cloud-docs） | `docs`、`platform`                           |
| 父 zh-cloud                  | `cursor`、`顶层`                             |

## 示例

```text
feat(count): 新增设备列表分页接口
fix(告警): 修复分页未刷新的问题
docs(platform): 补充 plan-naming Hook 说明
chore(cursor): 新增 git-sync-gitea skill
refactor(count): 抽取同步状态枚举
```

## PR 标题

与**首个**或**最主要** commit 摘要一致；可略扩写 scope。

## 禁止

- 空洞英文：`update code`、`fix bug`
- 一行混多个不相关变更（应拆 commit 或拆 PR）
