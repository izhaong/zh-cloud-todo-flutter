import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  required Widget child,
  Brightness brightness = Brightness.light,
}) async {
  await tester.runAsync(_ensureVisualFontsLoaded);
  final fixture = await TodoVisualFixture.create(set: fixtureSet);
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
  }();
}
