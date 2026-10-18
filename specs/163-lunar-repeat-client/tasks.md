# 163 台账

## T1 口径修正（opencode 交叉验证）

- [x] 「客户端不上行农历月日」⇒ **上行的是意图，反解是兜底**（数学仍只有服务端一份）。
- [x] 闰月 v1 不提供（字段没有 isLeapMonth；给选择就是给静默塌陷）。
- [x] A（客户端农历表）按 specs/024 既有先例否决。

## T2 改动

- [x] Drift 两列 + schema 32 + 19 处迁移测试版本号。
- [x] 入站/出站 sync payload；repository 白名单 + 守卫 + save 签名。
- [x] UI 两 chip + 文案 + 选择器（key 消歧）+ `_lunarDayText` + 保存守卫。

## T3 判据与探针

- [x] widget 3 + wire 1 + 直调 1（四个拒签子句）。
- [x] **反向探针**：白名单拿掉 ⇒ 2 红；lunarDay 旁路 ⇒ 直调红。
- [x] 全量门禁（后台跑完确认）。

## 过程教训

1. **探针脚本必须带 assert + grep 确认**（dart format 重排让两次 replace 静默失败 ⇒ 假绿）；
2. **弹中弹按钮配 key**（`.last` 会在弹层顺序变化时点错）；
3. **直调判据补牙齿**（widget 版碰巧绿——repository 层先抛）；
4. **每条守卫都要有对应子句**（缺 MONTHLY-null 子句时探针仍绿）；
5. schema bump 牵连 19 处硬编码版本号。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `task_repeat_lunar_test` | 4 条全绿 |
| `repeat_frequency_wire_test` | 5 条全绿 |
| `app_database_migration_test` | 19 条全绿（v32） |
| 反向探针 | 白名单 2 红 / lunarDay 旁路 1 红 |
| 全量（exclude golden/performance） | 后台跑完确认 |
