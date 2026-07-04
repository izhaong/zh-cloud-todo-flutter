/// M11-B1 脚手架：基础常量
/// - 后端 base URL 与端点前缀
/// - 多端点统一封装给 api/todo_client.dart / api/member_client.dart 使用

class ApiConfig {
  ApiConfig._();

  /// 默认本地开发地址；与 [TodoMemberAuthClient] 使用同一组 --dart-define。
  static const String defaultBaseUrl = String.fromEnvironment(
    'TODO_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:48080',
  );

  /// 默认租户；与 [TodoMemberAuthClient] 使用同一组 --dart-define。
  static const String defaultTenantId = String.fromEnvironment(
    'TODO_TENANT_ID',
    defaultValue: '1',
  );

  /// 会员认证（/app-api/todo-member/**）
  static const String memberPrefix = '/app-api/todo-member';

  /// 业务 API（/app-api/todo/**）
  static const String todoPrefix = '/app-api/todo';
}
