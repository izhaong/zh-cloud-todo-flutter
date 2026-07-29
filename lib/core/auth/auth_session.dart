import 'package:flutter/foundation.dart';

/// 登录会话。
///
/// - [tenantId]：登录所用租户（由登录请求的 `tenant-id` header 决定，后端登录响应
///   不返回租户）。用于多租户本地库隔离命名（`todo_t<tenant>_u<user>.sqlite`）。
/// - [accessToken] / [refreshToken] / [userId] / [expiresTime]：后端
///   `AppAuthLoginRespVO` 返回字段。
@immutable
class TodoAuthSession {
  const TodoAuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.tenantId,
    required this.mobile,
    this.expiresTime,
  });

  factory TodoAuthSession.fromResponse(
    Map<String, dynamic> data, {
    required String mobile,
    required String tenantId,
  }) {
    final accessToken = data['accessToken']?.toString();
    final refreshToken = data['refreshToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw const TodoAuthException('登录响应缺少 accessToken');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const TodoAuthException('登录响应缺少 refreshToken');
    }
    return TodoAuthSession(
      userId: int.tryParse(data['userId']?.toString() ?? '') ?? 0,
      accessToken: accessToken,
      refreshToken: refreshToken,
      tenantId: tenantId,
      expiresTime: data['expiresTime']?.toString(),
      mobile: mobile,
    );
  }

  factory TodoAuthSession.fromJson(Map<String, dynamic> json) {
    return TodoAuthSession(
      userId: json['userId'] as int? ?? 0,
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '1',
      expiresTime: json['expiresTime'] as String?,
      mobile: json['mobile'] as String? ?? '',
    );
  }

  final int userId;
  final String accessToken;
  final String refreshToken;
  final String tenantId;
  final String? expiresTime;
  final String mobile;

  bool get isValid =>
      accessToken.isNotEmpty && refreshToken.isNotEmpty && userId > 0;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tenantId': tenantId,
    'expiresTime': expiresTime,
    'mobile': mobile,
  };
}

class TodoAuthException implements Exception {
  const TodoAuthException(this.message, {this.code});

  static const int twoFactorRequiredCode = 1099110104;
  static const int twoFactorInvalidCode = 1099110105;

  final String message;
  final int? code;

  @override
  String toString() => message;
}
