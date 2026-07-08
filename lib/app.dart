import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';
import 'state/session_state.dart';
import 'todo_auth_page.dart';

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
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeShell(),
      ),
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
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapped = ref.watch(sessionBootstrappedProvider);
    if (!bootstrapped) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'zh-cloud todo',
        theme: _theme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'zh-cloud todo',
      theme: _theme(),
      routerConfig: router,
    );
  }

  ThemeData _theme() => ThemeData(
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
        side: BorderSide(color: AppColors.light.border, width: 0.5),
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
  );
}
