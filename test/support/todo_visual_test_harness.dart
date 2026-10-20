import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';

import 'todo_visual_fixture.dart';

abstract final class TodoVisualViewports {
  static const wide = Size(1440, 900);
  static const compact = Size(1280, 800);
  static const tablet = Size(1024, 768);
  static const mobile = Size(390, 844);
  static const mobileMin = Size(360, 800);
}

const todoVisualRootKey = Key('todo-visual-root');

Future<void>? _visualFontsLoaded;

String todoGoldenPath(String scenarioId) =>
    '../goldens/todo_workspace/$scenarioId.png';

Future<TodoVisualFixture> pumpTodoVisualScenario(
  WidgetTester tester, {
  required Size viewport,
  required TodoVisualFixtureSet fixtureSet,
  List<Override> Function(AppDatabase database)? overridesBuilder,
  required Widget child,
  Brightness brightness = Brightness.light,
}) async {
  await tester.runAsync(_ensureVisualFontsLoaded);
  // #708：workspace_companion 等读 SharedPreferences 的组件在无插件通道的
  // 测试环境会抛 MissingPluginException（golden 曾整条 tablet-list 直接炸）。
  // harness 是视觉/契约测试的公共入口 —— 在这里统一 mock，一次修全场景。
  SharedPreferences.setMockInitialValues({});
  final fixture = await TodoVisualFixture.create(
    set: fixtureSet,
    overridesBuilder: overridesBuilder,
  );
  addTearDown(fixture.dispose);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _visualTheme(Brightness.light),
        darkTheme: _visualTheme(Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        builder: (context, appChild) {
          final media = MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true);
          return MediaQuery(data: media, child: appChild!);
        },
        home: RepaintBoundary(key: todoVisualRootKey, child: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return fixture;
}

ThemeData _visualTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  return ThemeData(
    brightness: brightness,
    fontFamily: 'TodoGoldenSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      surface: colors.surface,
      error: colors.destructive,
    ),
    scaffoldBackgroundColor: colors.background,
    useMaterial3: true,
    extensions: [AppThemeExtension(colors)],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

Future<void> _ensureVisualFontsLoaded() {
  return _visualFontsLoaded ??= () async {
    final textBytes = await File('test/fonts/TodoGoldenSans.ttf').readAsBytes();
    final textLoader = FontLoader('TodoGoldenSans')
      ..addFont(Future.value(ByteData.sublistView(textBytes)));
    await textLoader.load();

    final iconBytes = await File(
      'test/fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await iconLoader.load();

    // 清单图标用彩色 emoji（对齐滴答参照图）。测试环境默认字体不含 emoji 字形，
    // 不加载就会拍成一排方块 —— 那样的 golden「绿」得毫无意义。
    // 按平台探测系统 emoji 字体；本机找不到就跳过（CI 缺字体不该让用例红，
    // 但本机必须能拍到真字形，见 [visualEmojiFontLoaded]）。
    for (final path in const [
      '/System/Library/Fonts/Apple Color Emoji.ttc', // macOS
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', // Linux
      r'C:\Windows\Fonts\seguiemj.ttf', // Windows
    ]) {
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        final emojiLoader = FontLoader('Apple Color Emoji')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await emojiLoader.load();
        _emojiFontLoaded = true;
        break;
      } on Object {
        // 引擎不接受该格式（彩色位图字体）时跳过：此时 golden 会拍到方块，
        // 由 golden 用例里的显式断言提示，而不是悄悄放过。
        continue;
      }
    }
  }();
}

/// 是否成功加载了 emoji 字体（供 golden 用例决定能否断言 emoji 字形）。
bool visualEmojiFontLoaded() => _emojiFontLoaded;
bool _emojiFontLoaded = false;
