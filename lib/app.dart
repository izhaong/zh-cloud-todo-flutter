import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_shell.dart';
import 'state/session_state.dart';
import 'todo_auth_page.dart';

/// 应用根组件：ProviderScope 之下的 MaterialApp + 登录态门禁。
///
/// - 启动时先校验本地会话（[SessionController.bootstrap]），校验期间显示
///   loading，避免登录页闪现。
/// - 未登录 → [TodoAuthPage]；已登录 → [HomeShell]。
class TodoFlutterApp extends StatelessWidget {
  const TodoFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'zh-cloud todo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF155EEF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sessionProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapped = ref.watch(sessionBootstrappedProvider);
    if (!bootstrapped) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return TodoAuthPage(
        authClient: ref.watch(authGatewayProvider),
        onAuthenticated: (session, action) =>
            ref.read(sessionProvider.notifier).setSession(session),
      );
    }
    return const HomeShell();
  }
}
