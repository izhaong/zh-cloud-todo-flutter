import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class TodoMemberAuthGateway {
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
  });

  Future<void> sendSmsCode({required String mobile, required int scene});

  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
  });

  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  });

  Future<void> logout(String accessToken);

  /// 校验 accessToken 是否仍被后端认可；网络失败时返回 false。
  Future<bool> validateSession(String accessToken);

  void close();
}

class TodoMemberAuthClient implements TodoMemberAuthGateway {
  TodoMemberAuthClient({
    String baseUrl = const String.fromEnvironment(
      'TODO_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:48080',
    ),
    this.tenantId = const String.fromEnvironment(
      'TODO_TENANT_ID',
      defaultValue: '1',
    ),
    http.Client? httpClient,
  }) : _baseUri = Uri.parse(baseUrl),
       _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final Uri _baseUri;
  final String tenantId;
  final http.Client _httpClient;
  final bool _ownsClient;

  @override
  Future<TodoAuthSession> passwordLogin({
    required String mobile,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/app-api/todo-member/auth/login',
      body: {'mobile': mobile, 'password': password},
      includeTerminal: true,
    );
    return TodoAuthSession.fromResponse(data, mobile: mobile);
  }

  @override
  Future<void> sendSmsCode({required String mobile, required int scene}) async {
    await _request(
      'POST',
      '/app-api/todo-member/auth/send-sms-code',
      body: {'mobile': mobile, 'scene': scene},
    );
  }

  @override
  Future<TodoAuthSession> smsLogin({
    required String mobile,
    required String code,
  }) async {
    final data = await _request(
      'POST',
      '/app-api/todo-member/auth/sms-login',
      body: {'mobile': mobile, 'code': code},
      includeTerminal: true,
    );
    return TodoAuthSession.fromResponse(data, mobile: mobile);
  }

  @override
  Future<void> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) async {
    await _request(
      'PUT',
      '/app-api/todo-member/user/reset-password',
      body: {'mobile': mobile, 'code': code, 'password': password},
    );
  }

  @override
  Future<void> logout(String accessToken) async {
    await _request(
      'POST',
      '/app-api/todo-member/auth/logout',
      accessToken: accessToken,
    );
  }

  @override
  Future<bool> validateSession(String accessToken) async {
    if (accessToken.isEmpty) {
      return false;
    }
    try {
      await _request(
        'GET',
        '/app-api/todo-member/user/get',
        accessToken: accessToken,
      );
      return true;
    } on TodoMemberAuthException {
      return false;
    }
  }

  @override
  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
    bool includeTerminal = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'tenant-id': tenantId,
      if (includeTerminal) 'terminal': '30',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final requestBody = body == null ? null : jsonEncode(body);
    final uri = _resolve(path);
    final response = switch (method) {
      'GET' => await _httpClient.get(uri, headers: headers),
      'POST' => await _httpClient.post(
        uri,
        headers: headers,
        body: requestBody,
      ),
      'PUT' => await _httpClient.put(uri, headers: headers, body: requestBody),
      _ => throw TodoMemberAuthException('不支持的请求方法：$method'),
    };

    final decoded = response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TodoMemberAuthException('请求失败（HTTP ${response.statusCode}）');
    }
    if (decoded is Map<String, dynamic> && decoded.containsKey('code')) {
      final code = decoded['code'];
      if (code != 0) {
        throw TodoMemberAuthException(
          decoded['msg']?.toString() ??
              decoded['message']?.toString() ??
              '账号请求失败',
        );
      }
      return decoded['data'];
    }
    return decoded;
  }

  Uri _resolve(String path) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return _baseUri.replace(path: '$basePath$normalizedPath');
  }
}

class TodoAuthSession {
  const TodoAuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.mobile,
    this.expiresTime,
  });

  factory TodoAuthSession.fromResponse(dynamic data, {required String mobile}) {
    if (data is! Map) {
      throw TodoMemberAuthException('登录响应缺少用户凭证');
    }
    final accessToken = data['accessToken']?.toString();
    final refreshToken = data['refreshToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw TodoMemberAuthException('登录响应缺少 accessToken');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw TodoMemberAuthException('登录响应缺少 refreshToken');
    }
    return TodoAuthSession(
      userId: int.tryParse(data['userId']?.toString() ?? '') ?? 0,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresTime: data['expiresTime']?.toString(),
      mobile: mobile,
    );
  }

  factory TodoAuthSession.fromJson(Map<String, dynamic> json) {
    return TodoAuthSession(
      userId: json['userId'] as int? ?? 0,
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresTime: json['expiresTime'] as String?,
      mobile: json['mobile'] as String? ?? '',
    );
  }

  final int userId;
  final String accessToken;
  final String refreshToken;
  final String? expiresTime;
  final String mobile;

  bool get isValid =>
      accessToken.isNotEmpty && refreshToken.isNotEmpty && userId > 0;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresTime': expiresTime,
    'mobile': mobile,
  };
}

class TodoMemberAuthException implements Exception {
  TodoMemberAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
