import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/todo_client.dart';
import '../api/member_auth_client.dart';
import '../db/app_database.dart';

/// M11-B1 全局 provider 容器
///
/// - dio 客户端：业务 + 认证
/// - 本地数据库
/// - 后续 B 系在 lib/state/ 中扩展：authController / listController / taskController / syncEngine

final todoApiClientProvider = Provider<TodoApiClient>((ref) {
  return TodoApiClient();
});

final memberAuthClientProvider = Provider<MemberAuthClient>((ref) {
  return MemberAuthClient();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});