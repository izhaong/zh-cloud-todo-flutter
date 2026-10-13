# 131 · 习惯打卡心情与日志（矩阵 #45 面 ④）

## 背景

嘀嗒《02-功能指南/05-习惯打卡/02-更好地完成习惯.md》:55-:60：

> 你能够记录每天，完成习惯的心情以及日志，方便回顾。
> 在「编辑习惯」中底部，可以将打卡日志关闭。

矩阵 #45 面 ④。

## 设计（复用优先，经 cursor-agent 交叉验证取方案 A）

- **零契约变更、零增量 SQL**：`TodoHabitCheckInDO.note` 列已能随 check-in
  落库——心情约定由客户端拆分（note 首行五档 emoji 之一 😊😐😞🤩😤 或空，
  其余为日志正文），服务端透传。独立 mood 列要增量 SQL 一整圈契约，
  原文只要记下并回头看，没有按心情筛选或统计。
- 服务端：`GET /habit/check-in/list?habitId&limit` 复用
  `selectListByHabitAndRange`（90 天窗口）按 checkedAt 倒序返回
  id/checkedAt/note/amount，越权与归属校验同 checkIn（requireOwned）。
- 客户端：打卡弹层（心情五档 + 日志文本 → 拼 note）挂在习惯详情页
  「打卡」按钮；详情页新增「打卡日志」时间轴段（HabitJournalSection）。
- 列表行一键打卡保持直达（specs/097 打卡方式档既有行为，不弹层）。

## 目标（FR）

- FR-1 服务端日志端点：倒序 + limit 裁剪 + 越权抛错。
- FR-2 打卡弹层：心情五档单选（再点取消）、日志文本、保存拼 note。
- FR-3 拆分约定：`moodAndJournal` —— 首行 emoji ⇒ (emoji, 正文)；
  无 emoji ⇒ (null, 全文)；空 note ⇒ null（不渲染）。
- FR-4 详情页「打卡日志」时间轴：日期/心情/正文逐条渲染，空不渲染。
- FR-5 弹层成功/失败可见反馈；保存后回调刷新。

## 验收（AC）

- AC-1 服务测试 3 条（倒序+limit / 越权 / note 透传），todo 模块 522 全绿。
- AC-2 拆分约定 5 条纯函数用例。
- AC-3 弹层交互可达（五档按钮 + 日志输入框）。
- AC-4 时间轴渲染日期/心情/正文，空整段不渲染。
- AC-5 门禁：analyze 0 issue、全量不回归。
