import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_gateway.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/widgets/auth_brand_panel.dart';
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
  static const _wideBreakpoint = 900.0;
  static const _formMaxWidth = 420.0;
  static const _fieldGap = 16.0;

  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  _AuthMode _mode = _AuthMode.password;
  bool _submitting = false;
  bool _sendingCode = false;
  bool _obscurePassword = true;
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
    final title = switch (_mode) {
      _AuthMode.password => '欢迎回来',
      _AuthMode.sms => '验证码登录',
      _AuthMode.register => '创建 Todo 账号',
      _AuthMode.forgotPassword => '重置密码',
    };
    final subtitle = switch (_mode) {
      _AuthMode.password => '登录后继续安排任务与日程',
      _AuthMode.sms => '输入手机号，我们会发送登录验证码',
      _AuthMode.register => '验证手机号后即可开始使用',
      _AuthMode.forgotPassword => '验证手机号并设置新密码',
    };

    final colors = theme.extension<AppThemeExtension>()?.colors;
    final canvas = colors?.background ?? theme.scaffoldBackgroundColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final verticalPadding = isWide ? 40.0 : AppSpacing.xl;
        final form = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _formMaxWidth),
          child: _buildAuthForm(theme, title: title, subtitle: subtitle),
        );
        final content = isWide
            ? Row(
                key: const ValueKey('todo-auth-wide-layout'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: AuthBrandPanel(compact: false)),
                  const SizedBox(width: 48),
                  SizedBox(width: _formMaxWidth, child: form),
                ],
              )
            : Column(
                key: const ValueKey('todo-auth-compact-layout'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandPanel(compact: true),
                  const SizedBox(height: AppSpacing.xl),
                  form,
                ],
              );

        return ColoredBox(
          color: canvas,
          child: SafeArea(
            child: SingleChildScrollView(
              key: const ValueKey('todo-auth-list'),
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48 : AppSpacing.lg,
                vertical: verticalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 1180,
                    minHeight: isWide
                        ? constraints.maxHeight - (verticalPadding * 2)
                        : 0,
                  ),
                  child: isWide ? Center(child: content) : content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthForm(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    final colorScheme = theme.colorScheme;
    final colors = theme.extension<AppThemeExtension>()?.colors;
    final surface = colors?.surface ?? colorScheme.surface;
    final border = colors?.border ?? colorScheme.outlineVariant;

    return Material(
      color: surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isForgotMode || _isRegisterMode) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _switchMode(_AuthMode.password),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('返回密码登录'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  title,
                  key: const ValueKey('todo-auth-title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (_isPasswordMode || _mode == _AuthMode.sms) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildModeSwitch(),
                ],
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    hintText: '请输入 11 位手机号',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                  validator: _validateMobile,
                ),
                const SizedBox(height: _fieldGap),
                if (_isPasswordMode || _isForgotMode) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: [
                      _isForgotMode
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: _isForgotMode
                        ? TextInputAction.next
                        : TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _isForgotMode ? '新密码' : '密码',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        key: const ValueKey('todo-auth-password-visibility'),
                        tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: _fieldGap),
                ],
                if (!_isPasswordMode || _isForgotMode) ...[
                  _buildCodeField(colorScheme),
                  const SizedBox(height: _fieldGap),
                ],
                if (_message != null) ...[
                  _AuthMessage(text: _message!, isError: _messageIsError),
                  const SizedBox(height: _fieldGap),
                ],
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('todo-auth-submit'),
                    onPressed: _isBusy ? null : _submit,
                    child: _submitting
                        ? SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text(_submitLabel),
                  ),
                ),
                if (_isPasswordMode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        key: const ValueKey('todo-auth-register-link'),
                        onPressed: () => _switchMode(_AuthMode.register),
                        child: const Text('注册'),
                      ),
                      TextButton(
                        key: const ValueKey('todo-auth-forgot-password-link'),
                        onPressed: () => _switchMode(_AuthMode.forgotPassword),
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
    );
  }

  Widget _buildModeSwitch() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_AuthMode>(
        segments: const [
          ButtonSegment(value: _AuthMode.password, label: Text('密码')),
          ButtonSegment(value: _AuthMode.sms, label: Text('验证码')),
        ],
        selected: {_isPasswordMode ? _AuthMode.password : _AuthMode.sms},
        onSelectionChanged: (selection) => _switchMode(selection.first),
        showSelectedIcon: false,
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }

  Widget _buildCodeField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      decoration: InputDecoration(
        labelText: '短信验证码',
        prefixIcon: const Icon(Icons.verified_outlined),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: TextButton(
            onPressed: _isBusy ? null : _sendCode,
            child: _sendingCode
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : const Text('发送'),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 72,
          minHeight: 48,
        ),
      ),
      validator: _validateCode,
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
      _obscurePassword = true;
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
      await ref
          .read(authGatewayProvider)
          .sendSmsCode(
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
    } on Object {
      setState(() {
        _message = '暂时无法发送验证码，请稍后重试';
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
        final session = await ref
            .read(authGatewayProvider)
            .passwordLogin(
              mobile: _mobileController.text.trim(),
              password: _passwordController.text,
            );
        await ref.read(sessionProvider.notifier).setSession(session);
        return;
      }
      if (_mode == _AuthMode.forgotPassword) {
        await ref
            .read(authGatewayProvider)
            .resetPassword(
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
      final session = await ref
          .read(authGatewayProvider)
          .smsLogin(
            mobile: _mobileController.text.trim(),
            code: _codeController.text.trim(),
          );
      await ref.read(sessionProvider.notifier).setSession(session);
    } on TodoAuthException catch (error) {
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } on Object {
      setState(() {
        _message = '暂时无法完成请求，请稍后重试';
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

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;
    return Semantics(
      key: const ValueKey('todo-auth-message'),
      container: true,
      liveRegion: true,
      excludeSemantics: true,
      label: isError ? '错误：$text' : '提示：$text',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.info_outline,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(text, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
