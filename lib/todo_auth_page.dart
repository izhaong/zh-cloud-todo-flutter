import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_gateway.dart';
import 'state/session_state.dart';

/// todo-member 登录 / 注册 / 找回密码（居中卡片布局，8pt 间距网格）。
///
/// 不再由上层注入 [AuthGateway]：直接读取 [authGatewayProvider]，登录成功后通过
/// [sessionProvider] 的 [SessionController.setSession] 持久化会话，go_router 的
/// redirect 会把路由从 `/login` 切到 `/`。
class TodoAuthPage extends ConsumerStatefulWidget {
  const TodoAuthPage({super.key});

  @override
  ConsumerState<TodoAuthPage> createState() => _TodoAuthPageState();
}

enum _AuthMode { password, sms, register, forgotPassword }

class _TodoAuthPageState extends ConsumerState<TodoAuthPage> {
  static const _formMaxWidth = 420.0;
  static const _horizontalPadding = 24.0;
  static const _fieldGap = 16.0;

  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  _AuthMode _mode = _AuthMode.password;
  bool _submitting = false;
  bool _sendingCode = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isBusy => _submitting || _sendingCode;

  bool get _isPasswordMode => _mode == _AuthMode.password;

  bool get _isForgotMode => _mode == _AuthMode.forgotPassword;

  bool get _isRegisterMode => _mode == _AuthMode.register;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = switch (_mode) {
      _AuthMode.password => '密码登录',
      _AuthMode.sms => '短信验证码登录',
      _AuthMode.register => '注册 Todo 账号',
      _AuthMode.forgotPassword => '找回密码',
    };
    final subtitle = switch (_mode) {
      _AuthMode.password => '使用 todo-member 手机号和密码进入任务空间',
      _AuthMode.sms => '验证码登录会复用 todo-member token',
      _AuthMode.register => '手机号验证码登录即注册，不创建独立用户池',
      _AuthMode.forgotPassword => '验证码校验后重置密码，再返回登录页',
    };

    return SingleChildScrollView(
      key: const ValueKey('todo-auth-list'),
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: 32,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _formMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthBrandHeader(theme: theme),
              const SizedBox(height: 28),
              if (_isPasswordMode || _mode == _AuthMode.sms) ...[
                SegmentedButton<_AuthMode>(
                  segments: const [
                    ButtonSegment(
                      value: _AuthMode.password,
                      icon: Icon(Icons.lock_outline, size: 18),
                      label: Text('密码'),
                    ),
                    ButtonSegment(
                      value: _AuthMode.sms,
                      icon: Icon(Icons.sms_outlined, size: 18),
                      label: Text('验证码'),
                    ),
                  ],
                  selected: {
                    _isPasswordMode || _isForgotMode
                        ? _AuthMode.password
                        : _AuthMode.sms,
                  },
                  onSelectionChanged: (selection) {
                    _switchMode(selection.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isForgotMode || _isRegisterMode)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _switchMode(_AuthMode.password),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('返回密码登录'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        if (_isForgotMode || _isRegisterMode)
                          const SizedBox(height: 8),
                        Text(
                          title,
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: _fieldGap),
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '手机号',
                            prefixIcon: Icon(Icons.phone_iphone),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: _validateMobile,
                        ),
                        const SizedBox(height: _fieldGap),
                        if (_isPasswordMode || _isForgotMode)
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: _isForgotMode
                                ? TextInputAction.next
                                : TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: _isForgotMode ? '新密码' : '密码',
                              prefixIcon: const Icon(Icons.password),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: _validatePassword,
                          ),
                        if (_isPasswordMode || _isForgotMode)
                          const SizedBox(height: _fieldGap),
                        if (!_isPasswordMode && !_isForgotMode)
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: '短信验证码',
                              prefixIcon: const Icon(Icons.verified_outlined),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TextButton(
                                  onPressed: _isBusy ? null : _sendCode,
                                  child: _sendingCode
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : const Text('发送'),
                                ),
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 64,
                                minHeight: 48,
                              ),
                            ),
                            validator: _validateCode,
                          ),
                        if (!_isPasswordMode && !_isForgotMode)
                          const SizedBox(height: _fieldGap),
                        if (_isForgotMode)
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: '短信验证码',
                              prefixIcon: const Icon(Icons.verified_outlined),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TextButton(
                                  onPressed: _isBusy ? null : _sendCode,
                                  child: _sendingCode
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : const Text('发送'),
                                ),
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 64,
                                minHeight: 48,
                              ),
                            ),
                            validator: _validateCode,
                          ),
                        if (_isForgotMode) const SizedBox(height: _fieldGap),
                        if (_message != null) ...[
                          _AuthMessage(
                            text: _message!,
                            isError: _messageIsError,
                          ),
                          const SizedBox(height: _fieldGap),
                        ],
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            key: const ValueKey('todo-auth-submit'),
                            onPressed: _isBusy ? null : _submit,
                            child: _submitting
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : Text(_submitLabel),
                          ),
                        ),
                        if (_isPasswordMode) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                key: const ValueKey('todo-auth-register-link'),
                                onPressed: () =>
                                    _switchMode(_AuthMode.register),
                                child: const Text('注册'),
                              ),
                              TextButton(
                                key: const ValueKey(
                                  'todo-auth-forgot-password-link',
                                ),
                                onPressed: () =>
                                    _switchMode(_AuthMode.forgotPassword),
                                child: const Text('忘记密码'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _submitLabel {
    return switch (_mode) {
      _AuthMode.password => '登录',
      _AuthMode.sms => '验证码登录',
      _AuthMode.register => '注册并登录',
      _AuthMode.forgotPassword => '重置密码',
    };
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _message = null;
      _messageIsError = false;
      if (mode != _AuthMode.forgotPassword) {
        _passwordController.clear();
      }
      _codeController.clear();
    });
  }

  Future<void> _sendCode() async {
    final mobileError = _validateMobile(_mobileController.text);
    if (mobileError != null) {
      setState(() {
        _message = mobileError;
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _sendingCode = true;
      _message = null;
    });
    try {
      await ref.read(authGatewayProvider).sendSmsCode(
        mobile: _mobileController.text.trim(),
        scene: _mode == _AuthMode.forgotPassword ? 4 : 1,
      );
      setState(() {
        _message = _mode == _AuthMode.forgotPassword
            ? '重置密码验证码已发送'
            : '登录验证码已发送';
        _messageIsError = false;
      });
    } on TodoAuthException catch (error) {
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } on Object catch (error) {
      setState(() {
        _message = '验证码发送失败：$error';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingCode = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      if (_mode == _AuthMode.password) {
        final session = await ref.read(authGatewayProvider).passwordLogin(
          mobile: _mobileController.text.trim(),
          password: _passwordController.text,
        );
        await ref.read(sessionProvider.notifier).setSession(session);
        return;
      }
      if (_mode == _AuthMode.forgotPassword) {
        await ref.read(authGatewayProvider).resetPassword(
          mobile: _mobileController.text.trim(),
          code: _codeController.text.trim(),
          password: _passwordController.text,
        );
        setState(() {
          _mode = _AuthMode.password;
          _passwordController.clear();
          _codeController.clear();
          _message = '密码已重置，请使用新密码登录';
          _messageIsError = false;
        });
        return;
      }
      final session = await ref.read(authGatewayProvider).smsLogin(
        mobile: _mobileController.text.trim(),
        code: _codeController.text.trim(),
      );
      await ref.read(sessionProvider.notifier).setSession(session);
    } on TodoAuthException catch (error) {
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } on Object catch (error) {
      setState(() {
        _message = '账号请求失败：$error';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String? _validateMobile(String? value) {
    final mobile = value?.trim() ?? '';
    if (mobile.isEmpty) {
      return '请输入手机号';
    }
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      return '请输入 11 位手机号';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return _mode == _AuthMode.forgotPassword ? '请输入新密码' : '请输入密码';
    }
    if (password.length < 4 || password.length > 16) {
      return '密码长度为 4-16 位';
    }
    return null;
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) {
      return '请输入短信验证码';
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(code)) {
      return '验证码为 4-6 位数字';
    }
    return null;
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              Icons.task_alt,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Todo 账号入口',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '登录后同步任务、日历与效率工具',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
