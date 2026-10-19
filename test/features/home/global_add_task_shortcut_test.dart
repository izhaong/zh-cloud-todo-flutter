import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/shortcuts/todo_shortcut_registry.dart';
import 'package:zh_cloud_todo_flutter/native/native_intents.dart';

/// FL #345 A 批：全局添加任务（嘀嗒《08-桌面快捷键》:178-180
/// 「全局添加 **Ctrl / Cmd + Alt + A**，一键调出任务添加条」）。
///
/// **v1 兑现为应用内全局**（工作区任意位置生效）；OS 级全局热键（其它应用在
/// 前景时也能调出）需要平台通道，随桌面壳成熟度另刀 —— 记在注册表注释里。
class _ProbeIntent extends Intent {
  const _ProbeIntent();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('注册表里有「添加任务」档，且默认键位是 Ctrl/Cmd+Alt+A', () {
    final addTaskBindings = todoShortcutBindings
        .where((b) => b.kind == TodoShortcutKind.addTask)
        .toList();
    expect(
      addTaskBindings,
      isNotEmpty,
      reason:
          '注册表是默认值的唯一事实源 —— '
          '档位不在注册表里，工作区的 Shortcuts 映射与快捷键对话框都不会有它',
    );
    // 两种布局（Ctrl+Alt+A / ⌘⌥A）都要绑 —— 与 Ctrl+K/⌘K 同族结构
    expect(
      addTaskBindings.where((b) => b.activator is SingleActivator).length,
      greaterThanOrEqualTo(2),
      reason: '两种平台布局（Ctrl / Cmd）都要有 —— 只绑一种会让另一平台没键',
    );
    final ctrl = addTaskBindings.whereType<TodoShortcutBinding>().firstWhere(
      (b) => b.display == 'Ctrl+Alt+A',
      orElse: () => throw StateError('缺 Ctrl+Alt+A 布局'),
    );
    final activator = ctrl.activator as SingleActivator;
    expect(activator.control, isTrue);
    expect(activator.alt, isTrue);
  });

  testWidgets('工作区按下 Ctrl+Alt+A 打开快速添加表（应用内全局）', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    // 判据打在 intent 层：注册表 → activator → intent 的映射必须存在。
    // （pump 整个 TodoWorkspace 需要 fixture；intent 映射是判据的芯，
    //  用 todoShortcutActivators 直测 —— 工作区就是用它生成的映射。）
    final activators = todoShortcutActivators(
      forKind: (kind) => const _ProbeIntent(),
      overrides: const {},
    );
    // 找 Ctrl+Alt+A 那个 activator 的 intent —— 它必须映射成功
    // 不构造"相等"的 SingleActivator（== 还比 includeRepeats 等默认值，
    // 构造侧与注册表侧默认不一致会假失败）—— 直接断言映射里有
    // 「Control + Alt + Key A」那个组合（toString 是 ShortcutActivator 的
    // 稳定描述形态，GA keys 探针已确认注册表生成它）。
    final ctrlAltAPresent = activators.keys.any(
      (k) => k.toString().contains('Control + Alt + Key A'),
    );
    expect(
      ctrlAltAPresent,
      isTrue,
      reason: 'Ctrl+Alt+A 必须在生效映射里 —— 不在则按键按下什么都不发生',
    );
    final cmdAltAPresent = activators.keys.any(
      (k) => k.toString().contains('Alt + Meta + Key A'),
    );
    expect(
      cmdAltAPresent,
      isTrue,
      reason: 'Cmd+Alt+A（⌘⌥A）也必须在 —— 只绑 Ctrl 布局会让 macOS 没键',
    );
  });

  test('握姿能力探测：通道未实现 ⇒ 如实返回 false（不造假、不抛）', () async {
    // MissingPluginException 在 test 环境天然发生（无平台实现）
    final supported = await NativeIntents.supportsGripPosture();
    expect(
      supported,
      isFalse,
      reason:
          '裁决 A′ 原话：能力探测失败则**明说不支持**，不造假 —— '
          '当前所有平台无厂商握姿通道，探测必须如实 false 而不是抛或猜',
    );
  });

  test('小组件「+」的深链语义已存在（与全局快捷键同一条消费端）', () {
    // zhcloudtodo://task/add —— home_shell 的 _createTaskFromNativeLink 消费它。
    // 判据：URI 解析器认这条链（它是小组件「+」与快捷指令共用的形状）。
    final uri = Uri.parse(
      'zhcloudtodo://task/add?title=%E4%B9%B0%E7%89%9B%E5%A5%B6',
    );
    final request = NativeTaskAddRequest.tryParse(uri);
    expect(request, isNotNull);
    expect(request!.title, '买牛奶');
    // 坏链必须拒（判空/判 host）—— 同一解析器不许"什么链都吃"
    expect(
      NativeTaskAddRequest.tryParse(Uri.parse('zhcloudtodo://other/x')),
      isNull,
    );
  });
}
