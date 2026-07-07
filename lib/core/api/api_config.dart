/// 全局常量：后端 base URL、端点前缀、默认租户。
///
/// - `TODO_API_BASE_URL` / `TODO_TENANT_ID` 由 `--dart-define` 覆盖，
///   默认指向本地后端 `http://127.0.0.1:48080`、租户 `1`。
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = String.fromEnvironment(
    'TODO_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:48080',
  );

  static const String defaultTenantId = String.fromEnvironment(
    'TODO_TENANT_ID',
    defaultValue: '1',
  );

  /// 会员认证（`/app-api/todo-member/**`）。
  static const String memberPrefix = '/app-api/todo-member';

  /// 业务 API（`/app-api/todo/**`）。
  static const String todoPrefix = '/app-api/todo';

  /// 离线同步（`/app-api/todo/sync`）。
  static const String syncPrefix = '/app-api/todo/sync';
}
