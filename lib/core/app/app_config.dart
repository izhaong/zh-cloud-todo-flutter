/// 应用配置
class AppConfig {
  static const String appName = 'zh-cloud Todo';
  static const String version = '1.0.5+6';
  
  // API 配置
  static const String baseUrl = 'https://api.zh04.com';
  static const String appApiPrefix = '/app-api/todo';
  
  // 同步配置
  static const int syncBatchSize = 50;
  static const Duration syncTimeout = Duration(seconds: 30);
  static const Duration syncRetryDelay = Duration(seconds: 5);
  
  // 本地存储配置
  static const String databaseName = 'todo_app.db';
  static const int databaseVersion = 1;
  
  // 网络配置
  static const Duration networkTimeout = Duration(seconds: 15);
  static const Duration connectTimeout = Duration(seconds: 10);
  
  // UI 配置
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double borderRadius = 8.0;
}