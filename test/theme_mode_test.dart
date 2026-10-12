import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/app_theme_controller.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row.dart';

/// G.5 暗色模式测试：切换 dark 后主题应使用 AppColors.dark token。
void main() {
  testWidgets('ThemeModeController 默认 system，可切 dark', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _ThemeProbe()));
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

  for (final brightness in Brightness.values) {
    final modeLabel = brightness == Brightness.light ? '浅色' : '深色';

    testWidgets('$modeLabel selected 状态与 hover 可区分且标题可读', (tester) async {
      const selectedTitle = '已选中任务';

      await _pumpRows(
        tester,
        brightness: brightness,
        rows: [
          _row(_taskData(id: 'selected', title: selectedTitle), selected: true),
        ],
      );

      final selectedSurface = find.byKey(
        const Key('task-row-surface-selected'),
      );
      final selectedColor = _surfaceColor(tester, selectedSurface);
      final selectedSemantics = tester.widget<Semantics>(
        find.byKey(const Key('task-row-selected-selected')),
      );
      expect(selectedSemantics.properties.selected, isTrue);
      expect(selectedColor, isNot(Colors.transparent));
      expect(
        _contrastRatio(_textColor(tester, selectedTitle), selectedColor),
        greaterThanOrEqualTo(4.5),
      );

      await _pumpRows(
        tester,
        brightness: brightness,
        rows: [_row(_taskData(id: 'hovered', title: '悬停任务'), hovered: true)],
      );

      expect(
        selectedColor,
        isNot(
          _surfaceColor(
            tester,
            find.byKey(const Key('task-row-surface-hovered')),
          ),
        ),
        reason: 'selected 不能与 hover 只呈现同一背景状态',
      );
    });

    testWidgets('$modeLabel due 语义色彼此可区分且文字对比度达标', (tester) async {
      final now = DateTime(2026, 7, 11, 9);
      await _pumpRows(
        tester,
        brightness: brightness,
        rows: [
          _row(
            _taskData(
              id: 'overdue',
              title: '逾期任务',
              dueAt: DateTime(2026, 7, 10, 9),
            ),
            now: now,
          ),
          _row(
            _taskData(
              id: 'today',
              title: '今日任务',
              dueAt: DateTime(2026, 7, 11, 15),
            ),
            now: now,
          ),
          _row(
            _taskData(
              id: 'future',
              title: '未来任务',
              dueAt: DateTime(2026, 7, 12, 9),
            ),
            now: now,
          ),
        ],
      );

      final dueColors = [
        _textColor(tester, '昨天'),
        _textColor(tester, '今天'),
        _textColor(tester, '明天'),
      ];
      expect(dueColors.toSet(), hasLength(3));
      final background = _colorsFor(brightness).surface;
      final dueContrast = <String, double>{
        'overdue': _contrastRatio(dueColors[0], background),
        'today': _contrastRatio(dueColors[1], background),
        'future': _contrastRatio(dueColors[2], background),
      };
      expect(
        dueContrast.values,
        everyElement(greaterThanOrEqualTo(4.5)),
        reason: '$modeLabel due 文字需达到 WCAG AA 普通文本对比度，实测 $dueContrast',
      );
    });

    testWidgets('$modeLabel 高优先级具有可见且可读的非文字指示', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpRows(
          tester,
          brightness: brightness,
          rows: [
            _row(_taskData(id: 'normal-priority', title: '整理收集箱')),
            _row(_taskData(id: 'high-priority', title: '提交发布说明', priority: 3)),
          ],
        );

        expect(find.bySemanticsLabel(RegExp('高优先级')), findsOneWidget);
        final highSurface = find.byKey(
          const Key('task-row-surface-high-priority'),
        );
        final normalSurface = find.byKey(
          const Key('task-row-surface-normal-priority'),
        );
        final highIndicator = find.descendant(
          of: highSurface,
          matching: find.byType(Icon),
        );
        expect(highIndicator, findsOneWidget);
        expect(
          find.descendant(of: normalSurface, matching: find.byType(Icon)),
          findsNothing,
        );
        final indicatorColor = tester.widget<Icon>(highIndicator).color;
        expect(indicatorColor, isNotNull);
        expect(
          _contrastRatio(indicatorColor!, _colorsFor(brightness).surface),
          greaterThanOrEqualTo(3),
          reason: '状态图形与背景需有至少 3:1 对比度',
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('$modeLabel completed 状态同时使用勾选、删除线与可读文字', (tester) async {
      const activeTitle = '未完成任务';
      const completedTitle = '已完成任务';
      await _pumpRows(
        tester,
        brightness: brightness,
        rows: [
          _row(_taskData(id: 'active', title: activeTitle)),
          _row(
            _taskData(id: 'completed', title: completedTitle, completed: true),
          ),
        ],
      );

      final activeText = tester.widget<Text>(find.text(activeTitle));
      final completedText = tester.widget<Text>(find.text(completedTitle));
      expect(completedText.style?.decoration, TextDecoration.lineThrough);
      expect(completedText.style?.color, isNot(activeText.style?.color));
      expect(
        find.descendant(
          of: find.byKey(const Key('task-row-surface-completed')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        _contrastRatio(
          completedText.style!.color!,
          _colorsFor(brightness).surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('$modeLabel keyboard focus 提供高对比边框而非只改背景', (tester) async {
      await _pumpRows(
        tester,
        brightness: brightness,
        rows: [_row(_taskData(id: 'focused', title: '键盘聚焦任务'), focused: true)],
      );

      final decoration = _surfaceDecoration(
        tester,
        find.byKey(const Key('task-row-surface-focused')),
      );
      final border = decoration.border as Border?;
      expect(border, isNotNull);
      expect(border!.top.width, greaterThan(0));
      expect(
        _contrastRatio(border.top.color, decoration.color!),
        greaterThanOrEqualTo(3),
        reason: '键盘焦点边框需在当前行背景上清晰可见',
      );
    });

    testWidgets('$modeLabel reduced motion 禁用 hover 与 selection 过渡', (
      tester,
    ) async {
      await _pumpRows(
        tester,
        brightness: brightness,
        disableAnimations: true,
        rows: [
          _row(_taskData(id: 'reduced-hover', title: '减少动效悬停'), hovered: true),
          _row(
            _taskData(id: 'reduced-selected', title: '减少动效选中'),
            selected: true,
          ),
        ],
      );

      for (final id in ['reduced-hover', 'reduced-selected']) {
        final surface = tester.widget<AnimatedContainer>(
          find.byKey(Key('task-row-surface-$id')),
        );
        expect(
          surface.duration,
          Duration.zero,
          reason: 'MediaQuery.disableAnimations 下状态变化应立即呈现',
        );
      }
    });
  }
}

class _ThemeProbe extends ConsumerWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: const [AppThemeExtension(AppColors.light)],
      ),
      darkTheme: ThemeData.dark().copyWith(
        extensions: const [AppThemeExtension(AppColors.dark)],
      ),
      themeMode: mode,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Column(
            children: [
              Text(
                'accent=${Theme.of(ctx).extension<AppThemeExtension>()!.colors.accent.toARGB32()}',
              ),
              for (final m in ThemeMode.values)
                TextButton(
                  onPressed: () => ref.read(themeModeProvider.notifier).set(m),
                  child: Text(themeModeLabel(m)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TaskRowData _taskData({
  required String id,
  required String title,
  bool completed = false,
  int priority = 0,
  DateTime? dueAt,
}) {
  return TaskRowData(
    id: id,
    title: title,
    completed: completed,
    isPinned: false,
    priority: priority,
    dueAt: dueAt,
    subtaskCount: 0,
    tagNames: const [],
  );
}

TaskRow _row(
  TaskRowData data, {
  bool selected = false,
  bool hovered = false,
  bool focused = false,
  DateTime? now,
}) {
  return TaskRow(
    data: data,
    selected: selected,
    hovered: hovered,
    focused: focused,
    now: now,
    onToggleComplete: _noop,
    onTap: _noop,
    onPin: _noop,
  );
}

Future<void> _pumpRows(
  WidgetTester tester, {
  required Brightness brightness,
  required List<TaskRow> rows,
  bool disableAnimations = false,
}) async {
  final colors = _colorsFor(brightness);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
          surface: colors.surface,
        ),
        scaffoldBackgroundColor: colors.surface,
        extensions: [AppThemeExtension(colors)],
      ),
      builder: (context, child) {
        final media = MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations);
        return MediaQuery(data: media, child: child!);
      },
      home: Scaffold(
        backgroundColor: colors.surface,
        body: ListView(children: rows),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppColors _colorsFor(Brightness brightness) =>
    brightness == Brightness.dark ? AppColors.dark : AppColors.light;

BoxDecoration _surfaceDecoration(WidgetTester tester, Finder surface) {
  return tester.widget<AnimatedContainer>(surface).decoration! as BoxDecoration;
}

Color _surfaceColor(WidgetTester tester, Finder surface) {
  return _surfaceDecoration(tester, surface).color!;
}

Color _textColor(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style!.color!;
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void _noop() {}
