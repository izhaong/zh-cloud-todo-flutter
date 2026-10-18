# 166 台账

## T1 A/B 拍定

- [x] opencode 交叉验证：**B**（合并=收成 1 条；A 已被 linkToParent 覆盖、且其引用原文不存在）。

## T2 改动

- [x] API 客户端 + 枚举/菜单 + 目标选择器（后果前置）+ apply（未同步拒）+ 文案（describeError）。

## T3 判据与探针

- [x] 2 条判据；**探针**（源静默跳过）⇒ 红（第一发假绿 —— 收紧断言为源路径独有原文后真红）。
- [x] 全量 `+2146 ~26` 0 失败；analyze 0；format rc=0。

## 过程教训

1. **raw-error 门禁第四次抓到我**（error.message 进文案）；
2. **探针要打在判据断言的那条路径**（两条文案都含"尚未同步"时断言要收紧到源独有原文）；
3. Dart 3.12 null-aware entry 在 **value** 侧（`'k': ?v`）。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `batch_merge_entry_test` | 2 条全绿 |
| 反向探针 | 红（收紧后） |
| `raw_error_text_gate_test` | 绿（修复后） |
| 全量（exclude golden/performance） | `+2146 ~26`，**0 失败** |
