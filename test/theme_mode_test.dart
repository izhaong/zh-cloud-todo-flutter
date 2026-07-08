import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/app_theme_controller.dart';

/// G.5 暗色模式测试：切换 dark 后主题应使用 AppColors.dark token。
void main() {
  testWidgets('ThemeModeController 默认 system，可切 dark', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: _ThemeProbe()),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold));
    // 默认 system 在测试环境 → 跟随平台（现为 light），但扩展必须存在。
    expect(Theme.of(ctx).extension<AppThemeExtension>(), isNotNull);

    // 切入 dark → 应携带 dark 浅蓝 accent。
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    final ext = Theme.of(ctx).extension<AppThemeExtension>()!;
    expect(ext.colors.accent, AppColors.dark.accent);
    expect(ext.colors.background, AppColors.dark.background);
  });
}

class _ThemeProbe extends ConsumerWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      theme: ThemeData.light()
          .copyWith(extensions: const [AppThemeExtension(AppColors.light)]),
      darkTheme: ThemeData.dark()
          .copyWith(extensions: const [AppThemeExtension(AppColors.dark)]),
      themeMode: mode,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Column(
            children: [
              Text('accent=${Theme.of(ctx).extension<AppThemeExtension>()!.colors.accent.value}'),
              for (final m in ThemeMode.values)
                TextButton(
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).set(m),
                  child: Text(themeModeLabel(m)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
