# 153 台账

## T1 取证

- [x] 现读 `_upsertLocalViewPreference`：`valueJson: jsonEncode(localPayload)` 整行覆盖。
- [x] 现读单机侧 `_write`：早已是"读旧行 → 按键合并 → 写回"，并有用例钉「两个开关写同一行」。
- [x] 现读两条调用路：冲突回写（**不回推**）与 pul 常态 —— 只有后者能合并。

## T2 改动

- [x] `preferenceKeyMap()`：两种形状都吃的读半边。
- [x] `_mergedValueJson()`：只对 `SIDEBAR_VISIBILITY` 且 `mergeLocalKeys` 时做并集。
- [x] `_upsertLocalViewPreference(..., mergeLocalKeys: false)` 默认关；**只有 pull 调用点传 true**。
- [x] 写回后按「并集 != 来料」回推一条 `view_preference`。

## T3 判据与探针

- [x] 新用例（真库 + 真 coordinator + 罐头 pull）：本地键在 / 来料键在 / 有回推。
- [x] **反向探针**：关掉合并 ⇒ `showTags` 变 `null`，转红。
- [x] 探针第一次**没命中锚点**（格式化后写法不同）⇒ 差点被当成"判据没咬住"；
      重做并**确认改到**之后才作数。

## 过程教训

1. **探针"没生效"和"判据没咬住"长得一模一样**：第一次探针替换因锚点不匹配而空跑，
   结果是"探针下仍然绿"。若不核探针本身，就会得出「判据无效」的错误结论，
   甚至可能去把判据改松。**改完探针要确认它真的改到了。**
2. **合并这类逻辑要问"谁回推"**：只在本地合并是**假修好** ——
   本机看着对了、对端仍旧缺。判据必须含"并集推回"这一条，否则它只证明了半件事。
3. **别在冲突路径上顺手合并**：那条路径不回推，合并会造出"双方 revision 相同但内容不同"的
   永不分叉态，而且判据只驱动 pull 就能绿。**同一函数、两条路、语义相反 ⇒ 必须显式开关。**

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 该文件 | `+7 All tests passed!`（含新增 1 条） |
| 反向探针 | 转红（`showTags` 变 null） |
| `flutter analyze` | `No issues found!` |
| 全量（exclude golden/performance） | `+2107 ~26`，**0 失败**（较修前 +1 = 本单新增） |
