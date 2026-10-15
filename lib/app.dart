import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/update/desktop_update.dart';
import 'features/home/home_shell.dart';
import 'features/shell/app_theme_controller.dart';
import 'state/session_state.dart';
import 'todo_auth_page.dart';

/// 框架自带文案（返回键、溢出菜单、日期/时间选择器、长按菜单）走中文。
///
/// 不挂 delegate 时 MaterialApp 只会拿到英文的 `GlobalMaterialLocalizations`，
/// 界面上就会混进「Back」「Show menu」这类英文（Issue #471）。
const List<LocalizationsDelegate<dynamic>> kLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const List<Locale> kSupportedLocales = [Locale('zh'), Locale('en')];

const Locale kLocale = Locale('zh');

/// 应用根路由：依据 [sessionProvider] / [sessionBootstrappedProvider] 在登录页与
/// 主壳之间重定向。
///
/// 路由不变式：
/// - 未完成会话初次校验（[sessionBootstrappedProvider] == false）时停留在当前页；
///   应用根会在 bootstrapped 前展示 loading（见 [TodoFlutterApp]），避免登录页闪现。
/// - 未登录 → `/login`；已登录 → `/`。
final goRouterProvider = Provider<GoRouter>((ref) {
  String? redirectLogin(GoRouterState state) {
    final bootstrapped = ref.read(sessionBootstrappedProvider);
    if (!bootstrapped) return null;
    final signedIn = ref.read(sessionProvider) != null;
    final goingLogin = state.matchedLocation == '/login';
    if (!signedIn && !goingLogin) return '/login';
    if (signedIn && goingLogin) return '/';
    return null;
  }

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefreshListenable(ref),
    redirect: (context, state) => redirectLogin(state),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const TodoAuthPage(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// 把 Riverpod provider 变更桥接为 GoRouter 的 [Listenable]（路由重算触发器）。
///
/// 监听 [sessionBootstrappedProvider] / [sessionProvider]，任一变化即触发
/// [GoRouter] 重跑 [redirect]，把用户从 `/login` ↔ `/` 之间正确调度。
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    ref.listen(sessionBootstrappedProvider, (_, _) => notifyListeners());
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

/// 应用根组件：ProviderScope 之下的 MaterialApp.router + 会话门禁。
class TodoFlutterApp extends ConsumerStatefulWidget {
  const TodoFlutterApp({super.key});

  @override
  ConsumerState<TodoFlutterApp> createState() => _TodoFlutterAppState();
}

class _TodoFlutterAppState extends ConsumerState<TodoFlutterApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sessionProvider.notifier).bootstrap());
    Future.microtask(prepareDesktopUpdate);
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapped = ref.watch(sessionBootstrappedProvider);
    final themeMode = ref.watch(themeModeProvider);
    if (!bootstrapped) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'zh-cloud todo',
        locale: kLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kLocalizationsDelegates,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'zh-cloud todo',
      locale: kLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

/// 应用暗色主题。
///
/// 公开（去掉下划线）是为了让 golden / 视觉回归测试能渲染**与真实应用一致**的
/// 主题；此前测试各自 `ThemeData.light()`，测出来的观感与用户看到的不是一回事。
ThemeData buildDarkTheme() => ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: AppColors.dark.accent,
    onPrimary: AppColors.dark.accentForeground,
    secondary: AppColors.dark.accent,
    surface: AppColors.dark.surface,
    error: AppColors.dark.destructive,
    onSurface: AppColors.dark.foreground,
  ),
  scaffoldBackgroundColor: AppColors.dark.background,
  useMaterial3: true,
  extensions: const [AppThemeExtension(AppColors.dark)],
  textTheme: _appTextTheme(AppColors.dark),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    },
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.dark.background,
    foregroundColor: AppColors.dark.foreground,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.dark.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: AppColors.dark.border, width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.dark.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.dark.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.dark.border),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.dark.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(color: AppColors.dark.border, width: 1),
    ),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColors.dark.surface,
    elevation: 0,
    modalElevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    showDragHandle: true,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: AppColors.dark.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: AppColors.dark.border, width: 1),
    ),
    textStyle: TextStyle(fontSize: 13, color: AppColors.dark.foreground),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.dark.ink,
    contentTextStyle: TextStyle(
      fontSize: 13,
      color: AppColors.dark.background,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: const CircleBorder(),
    side: BorderSide(color: AppColors.dark.mutedForeground, width: 1.5),
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.dark.accent
          : Colors.transparent,
    ),
  ),
  chipTheme: _chipTheme(AppColors.dark),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: AppColors.dark.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.dark.accentForeground
          : AppColors.dark.muted,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.dark.accent
          : AppColors.dark.border,
    ),
  ),
);

/// 应用浅色主题（公开理由同 [buildDarkTheme]）。
ThemeData buildLightTheme() => ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: AppColors.light.accent,
    onPrimary: AppColors.light.accentForeground,
    secondary: AppColors.light.accent,
    surface: AppColors.light.surface,
    error: AppColors.light.destructive,
    onSurface: AppColors.light.foreground,
  ),
  scaffoldBackgroundColor: AppColors.light.background,
  useMaterial3: true,
  extensions: const [AppThemeExtension(AppColors.light)],
  textTheme: _appTextTheme(AppColors.light),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    },
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.light.background,
    foregroundColor: AppColors.light.foreground,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.light.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: AppColors.light.border, width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.light.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.light.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.light.border),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.light.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(color: AppColors.light.border, width: 0.5),
    ),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColors.light.surface,
    elevation: 0,
    modalElevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    showDragHandle: true,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: AppColors.light.surface,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: AppColors.light.border, width: 0.5),
    ),
    textStyle: TextStyle(fontSize: 13, color: AppColors.light.foreground),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.light.ink,
    contentTextStyle: TextStyle(
      fontSize: 13,
      color: AppColors.light.background,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: const CircleBorder(),
    side: BorderSide(color: AppColors.light.mutedForeground, width: 1.5),
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.light.accent
          : Colors.transparent,
    ),
  ),
  chipTheme: _chipTheme(AppColors.light),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: AppColors.light.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.light.accentForeground
          : AppColors.light.surface,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.light.accent
          : AppColors.light.border,
    ),
  ),
);

/// 全局文字层级兜底：正文 13 / 小字 11 / 页面标题 15，随明暗配色。
///
/// 内嵌品牌字体暂缺（pubspec 无字体资源），先收敛字号层级；
/// 后续接入 MiSans / HarmonyOS Sans 时只改这里。
TextTheme _appTextTheme(AppColors colors) => TextTheme(
  titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.ink),
  titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink),
  bodyLarge: TextStyle(fontSize: 15, color: colors.foreground),
  bodyMedium: TextStyle(fontSize: 13, color: colors.foreground),
  bodySmall: TextStyle(fontSize: 11, color: colors.mutedForeground),
  labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.foreground),
  labelMedium: TextStyle(fontSize: 11, color: colors.mutedForeground),
  labelSmall: TextStyle(fontSize: 10, color: colors.mutedForeground),
);

/// 统一 chip 观感：细边框 + 小圆角，选中态交给业务侧 AppChip。
ChipThemeData _chipTheme(AppColors colors) => ChipThemeData(
  side: BorderSide(color: colors.border),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
  ),
  labelStyle: TextStyle(fontSize: 12, color: colors.foreground),
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: 2,
  ),
);
