# 165 台账

## T1 口径

- [x] speech_to_text 7.5.0；权限拒绝不静默；两端只消费 isFinal（"不假装实时"天然成立）。
- [x] 录音模式/平台不对称/30min 上限 → 第二步。

## T2 改动

- [x] gateway（五态）+ SpeechToTextGateway（errorType 分类）+ FAB state 化 +
      Listener/Timer 长按 + overlay + 平台声明（Android/iOS）+ pubspec。

## T3 判据与探针

- [x] 6 条判据全绿；**探针**（初始化失败静默化）⇒ 权限判据红。
- [x] analyze 0 / format rc=0 / 全量 `+2144 ~26` 0 失败（raw-error 门禁修复后）。

## 判据抓到的缺陷

1. 装配缺失路径无 overlay 宿主（状态写了没有显示位）；
2. `e.toString()` 分类 —— raw-error 门禁第三次抓到我。

## 过程教训

1. **opencode 的"天然互斥"被 Draggable 的 ImmediateMultiDrag 推翻** ——
   交叉验证结论也要被实测检验；
2. **探针先确认判据路径**（第一发打在回调上，权限不走那）。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `voice_long_press_test` | 6 条全绿 |
| 反向探针 | 红 |
| `raw_error_text_gate_test` | 绿（修复后） |
| 全量（exclude golden/performance） | `+2144 ~26`，**0 失败** |
