import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_gateway.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';

/// 已登录用户修改密码。
///
/// 短信验证码使用会员场景 3（MEMBER_UPDATE_PASSWORD）；后端会按当前会话
/// 查询绑定手机号，客户端传入的手机号仅用于保持统一认证网关契约。
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _sendingCode = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sendingCode) return;
    setState(() => _sendingCode = true);
    try {
      await ref
          .read(authGatewayProvider)
          .sendSmsCode(
            mobile: ref.read(sessionProvider)?.mobile ?? '',
            scene: 3,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('验证码已发送')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败：${_messageOf(error)}')));
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(todoApiProvider)
          .security
          .changePassword(
            code: _codeController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      _codeController.clear();
      _passwordController.clear();
      _confirmController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已修改')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('修改失败：${_messageOf(error)}')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateCode(String? value) {
    final code = value ?? '';
    if (!RegExp(r'^\d{4,6}$').hasMatch(code)) {
      return '请输入 4-6 位数字验证码';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 4 || password.length > 16) {
      return '密码长度为 4-16 位';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改密码')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '验证当前账号绑定的手机号后设置新密码。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('change-password-code'),
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: '短信验证码',
                      prefixIcon: const Icon(Icons.sms_outlined),
                      suffixIcon: TextButton(
                        key: const ValueKey('change-password-send-code'),
                        onPressed: _sendingCode ? null : _sendCode,
                        child: Text(_sendingCode ? '发送中' : '获取验证码'),
                      ),
                    ),
                    validator: _validateCode,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('change-password-new'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: '新密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? '显示新密码' : '隐藏新密码',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('change-password-confirm'),
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: '确认新密码',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirm ? '显示确认密码' : '隐藏确认密码',
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validateConfirm,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('change-password-submit'),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.password_outlined),
                      label: const Text('确认修改'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _messageOf(Object error) {
  if (error is TodoAuthException) return error.message;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['msg'] != null) {
      return data['msg'].toString();
    }
  }
  final message = error.toString().replaceFirst('Exception: ', '');
  return message.isEmpty ? '请稍后重试' : message;
}
