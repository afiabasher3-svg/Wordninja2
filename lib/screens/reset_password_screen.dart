import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _loading = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String _error = '';
  String _success = '';

  static const _bg = Color(0xFF0A0A14);
  static const _surface = Color(0xFF12121F);
  static const _card = Color(0xFF1A1A2E);
  static const _border = Color(0xFF2A2A45);
  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFF9D5CF6);
  static const _accent = Color(0xFFC084FC);
  static const _textPrimary = Color(0xFFF1F0FF);
  static const _textSecondary = Color(0xFF8B8BAD);

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() {
        _error = '⚠️ Please fill in all fields.';
      });
      return;
    }
    if (newPass.length < 6) {
      setState(() {
        _error = '⚠️ Password must be at least 6 characters.';
      });
      return;
    }
    if (newPass != confirmPass) {
      setState(() {
        _error = '❌ Passwords do not match.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _success = '';
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      setState(() {
        _success = '✅ Password updated successfully!';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      setState(() {
        _error = '⚠️ Something went wrong. Please try again.';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned(
              top: -120,
              left: -80,
              child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _purple.withOpacity(0.25)))),
          Positioned(
              bottom: -100,
              right: -60,
              child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withOpacity(0.15)))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Column(children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _card,
                          border: Border.all(
                              color: _purple.withOpacity(0.6), width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: _purple.withOpacity(0.35),
                                blurRadius: 24,
                                spreadRadius: 2)
                          ],
                        ),
                        child: const Center(
                            child: Icon(Icons.lock_reset_rounded,
                                color: Color(0xFFC084FC), size: 36)),
                      ),
                      const SizedBox(height: 16),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                                colors: [_purpleLight, _accent])
                            .createShader(bounds),
                        child: const Text('Reset Password',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 6),
                      const Text('Enter your new password below',
                          style:
                              TextStyle(color: _textSecondary, fontSize: 14)),
                    ]),
                    const SizedBox(height: 36),

                    // Card
                    Container(
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
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // New password
                            TextField(
                              controller: _newPassController,
                              obscureText: !_showNew,
                              style: const TextStyle(
                                  color: _textPrimary, fontSize: 15),
                              cursorColor: _purpleLight,
                              decoration: InputDecoration(
                                hintText: 'New Password',
                                hintStyle: const TextStyle(
                                    color: _textSecondary, fontSize: 14),
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: _textSecondary,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _showNew
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _textSecondary,
                                      size: 20),
                                  onPressed: () =>
                                      setState(() => _showNew = !_showNew),
                                ),
                                filled: true,
                                fillColor: _card,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: _border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: _border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: _purple, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Confirm password
                            TextField(
                              controller: _confirmPassController,
                              obscureText: !_showConfirm,
                              style: const TextStyle(
                                  color: _textPrimary, fontSize: 15),
                              cursorColor: _purpleLight,
                              decoration: InputDecoration(
                                hintText: 'Confirm Password',
                                hintStyle: const TextStyle(
                                    color: _textSecondary, fontSize: 14),
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: _textSecondary,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _showConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _textSecondary,
                                      size: 20),
                                  onPressed: () => setState(
                                      () => _showConfirm = !_showConfirm),
                                ),
                                filled: true,
                                fillColor: _card,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: _border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: _border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: _purple, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_error.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.redAccent
                                            .withOpacity(0.35))),
                                child: Row(children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFFF8A8A), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(_error,
                                          style: const TextStyle(
                                              color: Color(0xFFFF8A8A),
                                              fontSize: 13,
                                              height: 1.45))),
                                ]),
                              ),

                            if (_success.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.greenAccent
                                            .withOpacity(0.30))),
                                child: Row(children: [
                                  const Icon(Icons.check_circle_outline_rounded,
                                      color: Color(0xFF6EE7B7), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(_success,
                                          style: const TextStyle(
                                              color: Color(0xFF6EE7B7),
                                              fontSize: 13,
                                              height: 1.45))),
                                ]),
                              ),

                            const SizedBox(height: 20),

                            // Button
                            SizedBox(
                              height: 50,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  gradient: _loading
                                      ? null
                                      : const LinearGradient(
                                          colors: [_purple, Color(0xFF9D3AED)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                  color: _loading ? _card : null,
                                  boxShadow: _loading
                                      ? null
                                      : [
                                          BoxShadow(
                                              color: _purple.withOpacity(0.45),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4))
                                        ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _resetPassword,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(13))),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: _purpleLight,
                                              strokeWidth: 2.5))
                                      : const Text('Update Password 🔐',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.4)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen())),
                              child: const Text('← Back to Login',
                                  style: TextStyle(color: _accent)),
                            ),
                          ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
