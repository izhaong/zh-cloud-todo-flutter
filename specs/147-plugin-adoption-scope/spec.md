# 147 · 插件采用范围收口：三个已用、一个删除（原 FL #562）

## 背景

FL #562 主张把手写的平台能力换成社区插件，点名四件：`share_plus`、`home_widget`、
`wakelock_plus`、`table_calendar`（月视图网格）。

## 现读取证

| 插件 | pubspec 声明 | `lib/`+`test/` 引用文件数 | 处置 |
| --- | --- | --- | --- |
| `share_plus` | 有 | 1 | 保留（已用） |
| `home_widget` | 有 | 1 | 保留（已用） |
| `wakelock_plus` | 有 | 3 | 保留（已用） |
| `table_calendar` | 有 | **0** | **删除** |

即：三条替换早已落地；`table_calendar` 是**声明了但从未被引用**的纯负债。

## 为什么删依赖、而不是按原单换成它的实现

1. **月网格只有骨架是通用的**：`calendar_view.dart` 的 `_MonthGrid` 做的是
   「周首 + 周行 + 月内/月外」这点布局（约 100 行）；真正的内容在自绘的 `_DayCell`——
   拖拽改期（`DragTarget<TodoTask>`）、农历与节假日、习惯打卡点、
   按优先级/清单/标签三种着色轴。换库只能替掉骨架，这些仍要写 `calendarBuilders` 粘回去。
2. **另一处月网格不在覆盖范围**：`habit_month_grid.dart`（225 行）是独立的习惯月网格，
   原单自己也写明「年视图、周列、日程、列表全景仍是产品视图，table_calendar 不覆盖」。
3. **它还逼出了 `dependency_overrides`**（`table_calendar 3.3` 要求 `intl ^0.20.3`，而 Flutter SDK 的
   `flutter_localizations` 钉死 `intl 0.20.2` ⇒ 本仓不得不写 `dependency_overrides: intl: 0.20.3`。
   删掉它之后 `intl` 自然回到 SDK 的 `0.20.2`。

   复跑命令（下面这组命令就是上一条主张的判据）：

   ```bash
   # 删之前：只有 1 条覆盖，且成因就是 table_calendar
   git show HEAD:pubspec.yaml | grep -c "^dependency_overrides"        # ⇒ 1
   git show HEAD:pubspec.yaml | grep -A1 "^dependency_overrides"       # ⇒ intl: 0.20.3
   # 删之后：0 条覆盖，intl 回落到 SDK 原值
   grep -c "^dependency_overrides" pubspec.yaml                        # ⇒ 0
   grep -A4 "name: intl" pubspec.lock | grep version                   # ⇒ 0.20.2
   ```

⇒ 引入的收益抵不上改造与回归风险，故**删依赖**而不是**换实现**。

## 边界

- 不改 `_MonthGrid` / `_DayCell` / `habit_month_grid.dart` 的任何实现（它们本来就在跑）。
- 不新增插件。
- `share_plus` / `home_widget` / `wakelock_plus` 的三条替换早已落地，本切片只做「范围收口」。

## 验证

| 门 | 读数 |
| --- | --- |
| `flutter pub get` | `table_calendar` 与 `simple_gesture_detector` 一并移出，`Changed 3 dependencies!` |
| `pubspec.lock` | `intl` = **0.20.2**（SDK 原值），`table_calendar` 命中 0 处 |
| `grep -c "package:table_calendar/" lib test` | **0**（删前也证明它没被用） |
| `flutter analyze` | `No issues found!` |
| 全量测试 | 见 `tasks.md` |
