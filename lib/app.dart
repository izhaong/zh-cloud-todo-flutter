import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'features/task/clipboard_add_task_flow.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/todo_layout_tokens.dart';
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
    // FL #343：冷启动读剪贴板（默认关，见 `ClipboardAddTaskSetting`）。
    // 放在 post-frame 里：要等第一帧有 Scaffold 才弹得出提示。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runClipboardAddTaskFlow(context, ref);
    });
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
  // 角色补齐理由同 [buildLightTheme]：只填 6 个会让其余角色回落到 Material
  // 兜底值（errorContainer 纯红、outlineVariant 纯黑等），观感立刻掉档。
  colorScheme: ColorScheme.dark(
    primary: AppColors.dark.accent,
    onPrimary: AppColors.dark.accentForeground,
    primaryContainer: TodoLayoutTokens.darkSelectedRowTint,
    onPrimaryContainer: AppColors.dark.accent,
    secondary: AppColors.dark.accent,
    onSecondary: AppColors.dark.accentForeground,
    secondaryContainer: TodoLayoutTokens.darkSelectedRowTint,
    onSecondaryContainer: AppColors.dark.accent,
    surface: AppColors.dark.surface,
    onSurface: AppColors.dark.foreground,
    surfaceContainerHighest: AppColors.dark.muted,
    onSurfaceVariant: AppColors.dark.mutedForeground,
    outline: AppColors.dark.border,
    outlineVariant: AppColors.dark.border,
    error: AppColors.dark.destructive,
    onError: AppColors.dark.destructiveForeground,
    errorContainer: AppColors.dark.dangerSurface,
    onErrorContainer: AppColors.dark.dangerOnSurface,
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
    labelStyle: TextStyle(fontSize: 13, color: AppColors.dark.mutedForeground),
    floatingLabelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.dark.accent,
    ),
    hintStyle: TextStyle(fontSize: 13, color: AppColors.dark.mutedForeground),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.dark.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.dark.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.dark.accent, width: 1.5),
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
    contentTextStyle: TextStyle(fontSize: 13, color: AppColors.dark.background),
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
  // 只填 6 个角色时，其余角色会回落到 Material 兜底值 —— 实测
  // `errorContainer` 变成纯红、`outlineVariant` 变成**纯黑**、
  // `surfaceContainerHighest` 变成纯白，界面就会「看着不像成品」
  // （登录页的错误块刺眼、输入框边框发黑都是这个原因）。
  // 所以这里把用得到的容器/描边角色一起按品牌色板补齐。
  colorScheme: ColorScheme.light(
    primary: AppColors.light.accent,
    onPrimary: AppColors.light.accentForeground,
    // 容器色：淡品牌蓝底（用于选中态、模式切换器、提示块）。
    primaryContainer: TodoLayoutTokens.lightSelectedRowTint,
    onPrimaryContainer: AppColors.light.accent,
    secondary: AppColors.light.accent,
    onSecondary: AppColors.light.accentForeground,
    secondaryContainer: TodoLayoutTokens.lightSelectedRowTint,
    onSecondaryContainer: AppColors.light.accent,
    surface: AppColors.light.surface,
    onSurface: AppColors.light.foreground,
    // 三级表面：浅灰，供 chips / 次级分区使用。
    surfaceContainerHighest: AppColors.light.muted,
    onSurfaceVariant: AppColors.light.mutedForeground,
    // 描边：浅灰分割线（此前回落到纯黑，输入框像描了黑边）。
    outline: AppColors.light.border,
    outlineVariant: AppColors.light.border,
    error: AppColors.light.destructive,
    onError: AppColors.light.destructiveForeground,
    // 错误容器：淡红底 + 深红字，而不是 Material 兜底的纯红块。
    errorContainer: AppColors.light.dangerSurface,
    onErrorContainer: AppColors.light.dangerOnSurface,
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
    // 输入框统一：淡灰描边 + 品牌蓝聚焦 + 浮起标签不压边线。
    // labelStyle 显式给字号/颜色，避免默认 16px 黑字压在边框上显得「土」
    // （Issue #650 用户截图反馈）。
    labelStyle: TextStyle(fontSize: 13, color: AppColors.light.mutedForeground),
    floatingLabelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.light.accent,
    ),
    hintStyle: TextStyle(fontSize: 13, color: AppColors.light.mutedForeground),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.light.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.light.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.light.accent, width: 1.5),
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
  titleLarge: TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: colors.ink,
  ),
  titleMedium: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: colors.ink,
  ),
  bodyLarge: TextStyle(fontSize: 15, color: colors.foreground),
  bodyMedium: TextStyle(fontSize: 13, color: colors.foreground),
  bodySmall: TextStyle(fontSize: 11, color: colors.mutedForeground),
  labelLarge: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: colors.foreground,
  ),
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
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
);
