# 165 · 长按「+」语音输入（FL #342 v1）

## 判据源

《01-添加任务.md》`:104-107`「长按模式：长按「+」按钮启动语音输入…松手即可完成任务创建」
+ `:114`「按住『+』可能会触发系统权限请求」。

## 口径（产品裁决 + opencode 两轮，其中一处被实测推翻、一处被修正）

| 项 | 口径 |
| --- | --- |
| 依赖 | `speech_to_text 7.5.0`（平台原生 STT；不上云 ASR） |
| 权限拒绝 | 文案「需要麦克风权限才能语音添加」，**禁止静默失败** |
| **Android"暂不支持实时转写"** | **v1 不上屏**（opencode 修正裁决）：**两端都只消费 `isFinal==true`**，中间态不上屏、文案不写「实时」⇒「不假装实时」天然成立，无平台判断；`:114` 的不对称留第二步 |
| **长按手势实现** | **Listener + 手动 500ms Timer**（不是 GestureDetector —— 被实测推翻，见下） |
| 录音模式（:116-119）/`:123` 30 分钟上限 | **第二步**（opencode：上限从未可达，建议届时直接删） |
| 网关未注入（装配缺失） | 终态化「当前设备不支持语音输入」，不假装可用 |

## ⚠️ opencode 的"天然互斥"论被实测推翻（本刀最重要的发现）

opencode 两轮都说「LongPress（不动）与 Draggable（移动）**天然互斥**」。
实测：**GestureDetector 的长按根本不触发** —— `Draggable` 用的是
`ImmediateMultiDragGestureRecognizer`（pointer-down 当场认领、竞技场关闭），
长按超时永远等不到。判据（overlay=0）钉死这一事实。

⇒ 修法：**Listener（原始指针事件，不进竞技场）+ 手动 500ms Timer**。
`onPointerDown` 起表、`onPointerUp/Cancel` 走 `_holdEnded`（不到 500ms 取消
=一次普通点击；到过则结束语音会话）。**交叉验证的结论也要被实测检验。**

## 改动

1. `VoiceInputGateway`（接口 + 五态枚举：available/listening/permissionDenied/
   deviceNotSupported/error）+ `SpeechToTextGateway`（错误分类按 `errorType`，
   **不取异常原文** —— raw-error 门禁第三次抓到我）；
2. `MobileQuickAddButton` → StatefulWidget；`_startVoiceSession/_endVoiceSession`
   + `_holdEnded` + overlay（按 `_voiceStatus` 显示对应文案）；
3. 平台声明：Android `RECORD_AUDIO` + iOS `NSMicrophoneUsageDescription`/
   `NSSpeechRecognitionUsageDescription`（opencode：平台文件一次到位）；
4. pubspec：speech_to_text ^7.5.0。

## 判据（6 条）与探针

| 判据 | 咬什么 |
| --- | --- |
| 按住 500ms ⇒ overlay「说出你要做的事…」 | `:104` 长按启动 |
| 权限被拒 ⇒ 文案上屏（裁决②原文） | 禁止静默 |
| 设备不支持 ⇒ 终态文案 | 不假装 |
| **松手** ⇒ stop + isFinal 文本经 onSubmit 建任务（`:104` 松手即建） | 全链 |
| 装配缺失（gateway null）⇒「不支持」而非静默 | 兜底 |
| **点 + 仍打开快速添加表**（拖/点/长按三通道并存） | 不弄红既有 |

**反向探针**：初始化失败静默化（关 overlay 不留文案）⇒ **权限判据红**。
（⚠️ 第一发探针打错路径 —— 改了 `_onVoiceStatus` 回调，而权限走的是
`_startVoiceSession` 的 initialize 分支；**探针前先确认判据经过哪条路径**。）

## 判据当场抓到的缺陷（两处）

1. **装配缺失路径没有 overlay 宿主**：`setState(_voiceStatus=…)` 写了状态但
   `_voiceSessionActive` 还是 false ⇒ 文案永远不显示 ⇒ 修成"先激活会话再判终态"；
2. `e.toString()` 分类异常 —— **raw-error 门禁第三次抓到我**（#344 一次、本刀一次
   —— 这把尺子每次都咬）⇒ 改按 `errorType` 字段分类。

## 过程教训

1. **交叉验证的结论也要被实测检验**（opencode 的"天然互斥"被 Draggable 的
   ImmediateMultiDrag 当场推翻）；
2. **探针前先确认判据经过哪条路径**（第一发打在回调上，权限判据根本不走那）；
3. heredoc 里引号/`\$` 转义多次让脚本静默失败 —— 复杂编辑用行号定位。

## 边界（第二步）

- 录音模式（`:116-119` 左右滑切换、iOS 17+）；`:114` 平台不对称的逐字上屏；
- 30 分钟上限（opencode 建议届时直接删 —— 从未可达）。
