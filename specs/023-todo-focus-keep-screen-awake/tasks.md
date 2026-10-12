# Todo 专注屏幕常亮任务

- [x] T001 本地偏好与旧 JSON 兼容合同。
- [x] T002 Dart 原生通道安全降级合同。
- [x] T003 Android/iOS 原生开关与 Android 参数合同。
- [x] T004 页面会话、生命周期与去重接线。
- [ ] T005 全量验证、独立复核与 Gitea PR。

## 阻塞与验收

- 2026-08-09：T001 红测确认旧实现在访问 `keepScreenAwake` 时失败；实现后 `focus_immersion_settings_test.dart` 6/6 通过，定向分析无问题。任务级审查确认旧 JSON 保持 `autoEnter/style`、缺失或错误字段回退 `false`、存储 key 不变，且无越界改动。
- 2026-08-09：T002 红测确认 Dart API 缺失；实现后 `native_entry_page_test.dart` 9/9 与定向分析通过。任务级审查确认只复用 `zh_cloud_todo/native`，精确发送 `{enabled: bool}`，缺失通道、平台异常和所有非 `true` 返回均为安全失败，未影响其它 native intent。
- 2026-08-09：T003 以 Android 参数解析器缺失完成红测；JDK 17 下 Android JVM 合同测试 8 项通过，`:app:compileDebugKotlin` 通过。完整 iOS Runner 编译因本机未安装 iOS 26.5 Platform Support 被 Xcode 拒绝，`swiftc -parse ios/Runner/AppDelegate.swift` 通过但不替代 Runner 编译。任务级审查确认 Android `FLAG_KEEP_SCREEN_ON` 与 iOS `isIdleTimerDisabled` 的严格布尔映射和无效参数路径。
- 2026-08-09：T004 以 13 项新增页面合同完成 RED/GREEN，最终 `pomodoro_page_contract_test.dart` 57/57、相关范围静态分析通过。三轮独立只读审查后确认：严格 RUNNING/前台条件、暂停/清会话/完成取消/后台/销毁关闭、恢复与同一 desired 去重、原生失败不重试、未知生命周期恢复，以及首次设置读取与销毁交错时的字段级合并和持久化。末轮仅提出未直接断言 write 次数的非阻断 Minor。
- 2026-08-09：T005 本地重新验证通过：diff/格式检查、`flutter analyze`、`flutter test --concurrency=1`（719 passed、26 环境跳过）、Web build，以及显式 JDK 17 下 Android JVM 测试和 Kotlin 编译。首次因本机磁盘仅剩 177 MiB 令 Flutter test cache 写入失败；仅清理本仓可再生的 `build/.dart_tool` 后复跑通过。默认 JDK 25 开发线未改变。
- 2026-08-09：T005 外部验收仍未完成：Xcode 缺 iOS 26.5 Platform Support，iOS Runner build 不能启动；Claude CLI 对五段合同均返回 API 402 Token 额度不足，无 `VERDICT: PASS`；Android/iOS 物理设备自动锁屏效果未验收；Jenkins 控制器健康但按本仓 URL/当前分支未找到 SCM Job，故无 CI SUCCESS 证据。上述均不得被本地编译替代。
- 2026-09-22：T005 的「独立复核」与「Gitea PR」两项缺口已补齐，「全量验证」只补齐 Dart 侧，故整项仍未勾选。已证实部分：Issue [#256](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/issues/256) 关闭，PR [#257](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/257) `merged=true` 合入 `develop`，合并提交即当前 HEAD `a1d7733`；Claude CLI 2.1.216 以只读 `plan` 模式（仅 `Read`/`Grep`/`Glob`）复核六项重点全部成立并返回 `VERDICT: PASS`（无 Blocker/Important）：非 RUNNING/暂停/后台/完成/销毁五条件与运算关闭常亮（`pomodoro_page.dart:810-817`）、同值与「首次未请求」双守卫去重（`:818-821`）、通道缺失与平台异常安全降级（`native_intents.dart:149-161`）、Android 参数双重安全转换（`NativeIntentContract.kt:58-61`）与 iOS `CFBooleanGetTypeID` 严格判定（`AppDelegate.swift:51-60`）、旧 JSON 只保留合法 `autoEnter/style` 且 `keepScreenAwake` 回退 `false`、`dispose` 先置后台再关常亮并递增 5 个请求序号使在途 async 早退，且交叉核对 SDK 源码确认 `PageView` 默认 `keepPage: true` 不会因切页误 dispose。Dart 侧全量门禁同日在 `a1d7733` 复跑全绿：`git diff --check` 干净、`flutter analyze` `No issues found!`、`flutter test --exclude-tags 'golden || performance' --concurrency=1` `+712 ~26: All tests passed!`、golden 9/9、test 配置 Web release `✓ Built build/web`。
- 2026-09-22：该复核另提 4 项 Minor，登记后**不在本切片改动**：① `native_intents.dart:156-160` 只吞 `PlatformException`/`MissingPluginException`，理论上 `StandardMethodCodec` 解码失败会抛 `FormatException`、debug 期 `BinaryMessenger` 失效会抛 `FlutterError`，而调用方以 `unawaited` 发起 —— 判定为当前通道载荷（`{enabled: bool}` 与原生端严格布尔回包）不可达，按仓库「不为不可能场景加防御代码」的约定不补 `catch (_)`；② `_lastKeepScreenAwakeDesired` 在发出前乐观更新且失败不重试，持续性失败会让常亮整页生命周期静默失效 —— 规格明确要求不重试，UI 信号留待后续；③ `dispose` 是本页唯一关闭防线，`home_shell.dart:481`、`efficiency_hub_page.dart:49`、`task_detail_pane.dart:812` 各自推入独立 `PomodoroPage` 当前互不干扰，后续再增持会话态页面时需重估；④ `spec.md` 状态行「实现完成」与本未勾选的 T005 口径不一致，已于本日把该状态行改写为「实现已合入 `develop`、验收未完成」并显式禁止读作验收完成。

- 2026-09-22：T005 的剩余门槛逐条更新。**iOS Runner 编译**：2026-08-09 记录的「Xcode 缺 iOS 26.5 Platform Support」已不再是阻塞——本机现为 Xcode 27.0，`xcodebuild -showsdks` 列出 `iOS 27.0 (-sdk iphoneos27.0)` 与 `Simulator - iOS 27.0`；但 `flutter build ios --no-codesign --debug` 停在 `Adding Swift Package Manager integration...` 约 12 分钟后人工终止，其子进程 `xcodebuild -clonedSourcePackagesDirPath build/ios/SourcePackages … -list` 派生的 `git-remote-https origin https://github.com/zhangao0086/DKImagePickerController` 全程无进展，同机 `curl "https://github.com/.../info/refs?service=git-upload-pack"` 15 秒连接超时、内网代理 `192.168.3.94:7890` 亦不可达。故 iOS Runner 仍未编译通过，阻塞点由「缺 Platform Support」变更为「本机到 github.com 不可达，SPM 依赖无法解析」；`swiftc -parse ios/Runner/AppDelegate.swift` 不替代 Runner 编译。该尝试只写入可再生的 `build/`，`git status` 确认 `ios/` 与工程文件零改动。**Android 侧**：2026-08-09 用于 Android JVM 测试与 `:app:compileDebugKotlin` 的 JDK 17 已不在本机（`/usr/libexec/java_home -V` 只注册 `ms-25.0.4.1`，无 Android Studio 自带 JBR），当日结论无法原样复现，未用 JDK 25 强跑冒充。**真机**：无可登录 test 环境的第二台物理设备，自动锁屏阻止效果仍未验收。**远端 CI**：`develop` runs `4675`/`4676`/`4677` 全部 `conclusion=failure`，日志终点为 runner 容器创建失败 `NanoCPUs can not be set, as your kernel does not support CPU CFS scheduler or the cgroup is not mounted`，Flutter 命令未执行；Jenkins `zh-cloud-todo-flutter` Job 本会话不可达。以上四项均不得由本地 Dart 门禁替代，T005 保持未勾选。
- Android/iOS 的真实自动锁屏阻止效果需要物理设备；编译或 Dart Mock 不替代该验收。
- iOS 本机若缺少 Platform Support / Simulator runtime，只记录编译或设备门槛，不伪造 iOS 通过。
- 当前 Gradle/Kotlin 组合不能以本机 JDK 25.0.3 配置 Android；本切片 Android JVM 与 Kotlin 编译明确使用 JDK 17，JDK 25 的运行时开发线不因此改变。
## 2026-10-07 复校（FL !521 之后）

- iOS Runner 编译不再受阻：`flutter build ios --release --no-codesign` 在 develop `9ac64c7` 返回 rc=0 并产出 `build/ios/iphoneos/Runner.app`（arm64）。当时记的「卡 SPM」真因是 workspace 缺 Pods 工程引用，已由 FL !521 补进仓库；判据 `git show origin/develop:ios/Runner.xcworkspace/contents.xcworkspacedata | grep -c "Pods.xcodeproj"` 现读 1。
- github 的 git 协议本轮现测可达：`git ls-remote https://github.com/zhangao0086/DKImagePickerController` 返回 HEAD `0bdfeace`，这条只对本轮负责，复现前需重测。
- JDK 前提变化：`/usr/libexec/java_home -V` 现注册 ms-25.0.4.1 与 ms-21.0.12.1 两个，Gradle 8.14 需以 21 启动；以 25 启动时构建报 `What went wrong: 25.0.4.1`，仓内不写绝对路径的 java.home。
- T005 继续保持未勾选：自动锁屏的真机效果与远端 CI 两项本轮仍无证据。
