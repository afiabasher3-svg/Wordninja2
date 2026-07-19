import 'package:flutter/material.dart';
import 'banner_widget.dart';
import 'gradient_button.dart';
import 'package:wordninja/widgets/banner_widget.dart';
import 'package:wordninja/widgets/gradient_button.dart';

class LoginCard extends StatelessWidget {
  final bool isLogin;
  final bool loading;
  final bool showPassword;
  final String error;
  final String success;
  final TextEditingController emailController;
  final TextEditingController passController;
  final TextEditingController usernameController;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchMode;
  final VoidCallback onForgotPassword;
  final VoidCallback onDeleteAccount;
  final VoidCallback onTogglePassword;

  static const _surface = Color(0xFF12121F);
  static const _card = Color(0xFF1A1A2E);
  static const _border = Color(0xFF2A2A45);
  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFF9D5CF6);
  static const _accent = Color(0xFFC084FC);
  static const _textPrimary = Color(0xFFF1F0FF);
  static const _textSecondary = Color(0xFF8B8BAD);

  const LoginCard({
    super.key,
    required this.isLogin,
    required this.loading,
    required this.showPassword,
    required this.error,
    required this.success,
    required this.emailController,
    required this.passController,
    required this.usernameController,
    required this.onSubmit,
    required this.onSwitchMode,
    required this.onForgotPassword,
    required this.onDeleteAccount,
    required this.onTogglePassword,
  });

  InputDecoration _inputDecoration(String hint, IconData icon,
      {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: _textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _card,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 32,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Tab switcher
        Container(
          height: 44,
          decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
          child: Row(children: [
            _tab('Login', isLogin),
            _tab('Register', !isLogin),
          ]),
        ),
        const SizedBox(height: 24),

        // Fields
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!isLogin) ...[
              TextField(
                controller: usernameController,
                style: const TextStyle(color: _textPrimary, fontSize: 15),
                decoration:
                    _inputDecoration('Username', Icons.person_outline_rounded),
                cursorColor: _purpleLight,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              decoration: _inputDecoration('Email', Icons.email_outlined),
              cursorColor: _purpleLight,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: !showPassword,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              cursorColor: _purpleLight,
              decoration:
                  _inputDecoration('Password', Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _textSecondary,
                            size: 20),
                        onPressed: onTogglePassword,
                      )),
            ),
          ]),
        ),

        if (isLogin) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ? null : onForgotPassword,
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Forgot Password?',
                  style: TextStyle(color: _accent, fontSize: 13)),
            ),
          ),
        ],

        if (error.isNotEmpty) ...[
          const SizedBox(height: 16),
          BannerWidget(
            message: error,
            icon: Icons.warning_amber_rounded,
            bgColor: Colors.redAccent.withOpacity(0.10),
            borderColor: Colors.redAccent.withOpacity(0.35),
            textColor: const Color(0xFFFF8A8A),
          ),
        ],
        if (success.isNotEmpty) ...[
          const SizedBox(height: 16),
          BannerWidget(
            message: success,
            icon: Icons.check_circle_outline_rounded,
            bgColor: Colors.greenAccent.withOpacity(0.08),
            borderColor: Colors.greenAccent.withOpacity(0.30),
            textColor: const Color(0xFF6EE7B7),
          ),
        ],

        const SizedBox(height: 20),
        GradientButton(
          label: isLogin ? 'Login 🥷' : 'Create Account ⚔️',
          onPressed: onSubmit,
          loading: loading,
        ),

        if (isLogin) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: loading ? null : onDeleteAccount,
            child: const Text('Delete Account',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ]),
    );
  }

  Widget _tab(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: active ? null : onSwitchMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? _purple : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: _purple.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : _textSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14))),
        ),
      ),
    );
  }
}
