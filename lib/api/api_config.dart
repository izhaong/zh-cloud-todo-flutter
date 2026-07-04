/// M11-B1 脚手架：基础常量
/// - 后端 base URL 与端点前缀
/// - 多端点统一封装给 api/todo_client.dart / api/member_client.dart 使用

class ApiConfig {
  ApiConfig._();

  /// 默认本地开发地址；CI/生产由 main.dart 启动时按 --dart-define 覆盖。
  static const String defaultBaseUrl = 'http://localhost:48080';

  /// 会员认证（/app-api/todo-member/**）
  static const String memberPrefix = '/app-api/todo-member';

  /// 业务 API（/app-api/todo/**）
  static const String todoPrefix = '/app-api/todo';
}