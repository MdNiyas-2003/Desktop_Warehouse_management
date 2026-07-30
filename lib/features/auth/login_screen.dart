import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _loginUsernameController =
      TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupUsernameController =
      TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();

  bool _isSignup = false;
  bool _rememberMe = true;
  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupUsernameController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F3FA), Color(0xFFE8EDF9)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final maxHeight = constraints.maxHeight;
              final isCompact = maxWidth < 980;

              final cardWidth = isCompact
                  ? maxWidth.clamp(320.0, 520.0)
                  : maxWidth.clamp(760.0, 900.0);
              final cardHeight = isCompact
                  ? maxHeight.clamp(700.0, 900.0)
                  : maxHeight.clamp(480.0, 560.0);

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth,
                      maxHeight: cardHeight,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A28324F),
                            blurRadius: 36,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: isCompact
                            ? Column(
                                children: [
                                  Expanded(
                                    flex: 52,
                                    child: _LeftPanel(compact: true),
                                  ),
                                  Expanded(
                                    flex: 48,
                                    child: _RightPanel(
                                      isSignup: _isSignup,
                                      rememberMe: _rememberMe,
                                      obscureLoginPassword:
                                          _obscureLoginPassword,
                                      obscureSignupPassword:
                                          _obscureSignupPassword,
                                      isBusy: _busy,
                                      message: _message,
                                      loginUsernameController:
                                          _loginUsernameController,
                                      loginPasswordController:
                                          _loginPasswordController,
                                      signupEmailController:
                                          _signupEmailController,
                                      signupUsernameController:
                                          _signupUsernameController,
                                      signupPasswordController:
                                          _signupPasswordController,
                                      onRememberChanged: (value) =>
                                          setState(() => _rememberMe = value),
                                      onToggleLoginPassword: () => setState(
                                        () => _obscureLoginPassword =
                                            !_obscureLoginPassword,
                                      ),
                                      onToggleSignupPassword: () => setState(
                                        () => _obscureSignupPassword =
                                            !_obscureSignupPassword,
                                      ),
                                      onSubmit: _isSignup
                                          ? _handleSignup
                                          : _handleLogin,
                                      onToggleMode: _toggleMode,
                                      onForgotPassword: _handleForgotPassword,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  const Expanded(
                                    flex: 50,
                                    child: _LeftPanel(compact: false),
                                  ),
                                  Expanded(
                                    flex: 50,
                                    child: _RightPanel(
                                      isSignup: _isSignup,
                                      rememberMe: _rememberMe,
                                      obscureLoginPassword:
                                          _obscureLoginPassword,
                                      obscureSignupPassword:
                                          _obscureSignupPassword,
                                      isBusy: _busy,
                                      message: _message,
                                      loginUsernameController:
                                          _loginUsernameController,
                                      loginPasswordController:
                                          _loginPasswordController,
                                      signupEmailController:
                                          _signupEmailController,
                                      signupUsernameController:
                                          _signupUsernameController,
                                      signupPasswordController:
                                          _signupPasswordController,
                                      onRememberChanged: (value) =>
                                          setState(() => _rememberMe = value),
                                      onToggleLoginPassword: () => setState(
                                        () => _obscureLoginPassword =
                                            !_obscureLoginPassword,
                                      ),
                                      onToggleSignupPassword: () => setState(
                                        () => _obscureSignupPassword =
                                            !_obscureSignupPassword,
                                      ),
                                      onSubmit: _isSignup
                                          ? _handleSignup
                                          : _handleLogin,
                                      onToggleMode: _toggleMode,
                                      onForgotPassword: _handleForgotPassword,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleMode() {
    if (_busy) {
      return;
    }
    setState(() {
      _isSignup = !_isSignup;
      _message = null;
    });
  }

  Future<void> _handleLogin() async {
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _message = 'Please enter username and password.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await _authService.loginWithUsername(
        username: username,
        password: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Login successful.';
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleSignup() async {
    final email = _signupEmailController.text.trim();
    final username = _signupUsernameController.text.trim();
    final password = _signupPasswordController.text;

    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      setState(
        () => _message = 'Signup requires Email, Username and Password.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await _authService.registerWithEmailUsername(
        email: email,
        username: username,
        password: password,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSignup = false;
        _message =
            'Account created successfully. Login now with username and password.';
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final username = _loginUsernameController.text.trim();
    if (username.isEmpty) {
      setState(
        () => _message = 'Enter username first, then click Forgot password.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await _authService.sendPasswordResetByUsername(username);
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Password reset email sent.';
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: Colors.white,
      fontSize: compact ? 30 : 36,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );

    final subtitleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.92),
      fontWeight: FontWeight.w500,
    );

    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Colors.white.withValues(alpha: 0.93),
      height: 1.45,
      fontSize: compact ? 12.5 : 13,
      fontWeight: FontWeight.w500,
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3E69F6), Color(0xFF2557E5), Color(0xFF1E49CC)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: compact ? 22 : 26,
            top: compact ? 24 : 30,
            child: _DotGrid(
              dotSize: compact ? 4 : 5,
              spacing: compact ? 9 : 11,
            ),
          ),
          Positioned(
            right: compact ? -54 : -62,
            top: compact ? -44 : -58,
            child: Container(
              width: compact ? 172 : 214,
              height: compact ? 172 : 214,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            left: compact ? -56 : -64,
            bottom: compact ? -54 : -62,
            child: Container(
              width: compact ? 144 : 176,
              height: compact ? 144 : 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 22 : 30,
              compact ? 24 : 26,
              compact ? 20 : 28,
              compact ? 22 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 1),
                Container(
                  width: compact ? 56 : 62,
                  height: compact ? 56 : 62,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.query_stats_rounded,
                    color: const Color(0xFF2A56DC),
                    size: compact ? 30 : 34,
                  ),
                ),
                SizedBox(height: compact ? 14 : 16),
                Text('WareHouse Management', style: headingStyle),
                const SizedBox(height: 4),
                Text('Salesman Orders Warehouse', style: subtitleStyle),
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF48D3FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                Text(
                  'A complete solution to manage\nsales orders, customers, inventory\nand deliveries efficiently.',
                  style: bodyStyle,
                ),
                const Spacer(flex: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Expanded(
                      child: _LeftFeatureItem(
                        icon: Icons.shopping_cart_outlined,
                        label: 'Order\nManagement',
                      ),
                    ),
                    Expanded(
                      child: _LeftFeatureItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Inventory\nControl',
                      ),
                    ),
                    Expanded(
                      child: _LeftFeatureItem(
                        icon: Icons.group_outlined,
                        label: 'Customer\nManagement',
                      ),
                    ),
                    Expanded(
                      child: _LeftFeatureItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Sales\nReports',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.isSignup,
    required this.rememberMe,
    required this.obscureLoginPassword,
    required this.obscureSignupPassword,
    required this.isBusy,
    required this.message,
    required this.loginUsernameController,
    required this.loginPasswordController,
    required this.signupEmailController,
    required this.signupUsernameController,
    required this.signupPasswordController,
    required this.onRememberChanged,
    required this.onToggleLoginPassword,
    required this.onToggleSignupPassword,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onForgotPassword,
  });

  final bool isSignup;
  final bool rememberMe;
  final bool obscureLoginPassword;
  final bool obscureSignupPassword;
  final bool isBusy;
  final String? message;
  final TextEditingController loginUsernameController;
  final TextEditingController loginPasswordController;
  final TextEditingController signupEmailController;
  final TextEditingController signupUsernameController;
  final TextEditingController signupPasswordController;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onToggleLoginPassword;
  final VoidCallback onToggleSignupPassword;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDFEFF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 314),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isSignup ? 'Create Account' : 'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1A2442),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSignup
                        ? 'Signup with Email, Username and Password'
                        : 'Sign in with Username and Password',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isSignup) ...[
                    const _FieldLabel('Email'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: signupEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _FieldLabel('Username'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: signupUsernameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your username',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _FieldLabel('Password'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: signupPasswordController,
                      obscureText: obscureSignupPassword,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: onToggleSignupPassword,
                          icon: Icon(
                            obscureSignupPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const _FieldLabel('Username'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: loginUsernameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your username',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _FieldLabel('Password'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: loginPasswordController,
                      obscureText: obscureLoginPassword,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: onToggleLoginPassword,
                          icon: Icon(
                            obscureLoginPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: rememberMe,
                            onChanged: (value) =>
                                onRememberChanged(value ?? false),
                            activeColor: AppColors.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: isBusy ? null : onForgotPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isBusy ? null : onSubmit,
                      child: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isSignup ? 'Create account' : 'Login',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            message!.toLowerCase().contains('successful') ||
                                message!.toLowerCase().contains('verified') ||
                                message!.toLowerCase().contains('sent')
                            ? const Color(0xFF0B8A4B)
                            : const Color(0xFFB3261E),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isSignup
                            ? 'Already have an account? '
                            : "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: isBusy ? null : onToggleMode,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isSignup ? 'Login' : 'Sign up',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4A5877),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LeftFeatureItem extends StatelessWidget {
  const _LeftFeatureItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.25,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid({required this.dotSize, required this.spacing});

  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Row(
            children: List.generate(
              5,
              (_) => Padding(
                padding: EdgeInsets.only(right: spacing),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
