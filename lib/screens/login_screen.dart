import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'game_screen.dart';
import '../widgets/otp_card.dart';
import '../widgets/login_card.dart';
import '../utils/error_helper.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _showPassword = false;
  bool _otpSent = false;
  String _error = '';
  String _success = '';
  String _pendingEmail = '';
  String _pendingUsername = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _bg = Color(0xFF0A0A14);
  static const _card = Color(0xFF1A1A2E);
  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFF9D5CF6);
  static const _accent = Color(0xFFC084FC);
  static const _textSecondary = Color(0xFF8B8BAD);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _usernameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _switchMode() {
    _animController.reset();
    setState(() {
      _isLogin = !_isLogin;
      _error = '';
      _success = '';
      _otpSent = false;
    });
    _animController.forward();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = '';
      _success = '';
    });
    try {
      if (_isLogin) {
        if (!isValidEmail(_emailController.text.trim())) {
          setState(() {
            _error = '📧 Please enter a valid email address.';
          });
          return;
        }
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );
        if (res.user != null) {
          final existing = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', res.user!.id)
              .maybeSingle();
          if (existing == null) {
            await Supabase.instance.client.from('profiles').insert({
              'id': res.user!.id,
              'username': res.user!.email!.split('@')[0],
              'highscore': 0,
              'accuracy': 0.0,
              'wpm': 0.0,
            });
          }
          if (mounted) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const GameScreen()));
          }
        }
      } else {
        if (!isValidEmail(_emailController.text.trim())) {
          setState(() {
            _error = '📧 Please enter a valid email address.';
          });
          return;
        }
        if (_usernameController.text.trim().isEmpty) {
          setState(() {
            _error = '⚠️ Please enter a username.';
          });
          return;
        }
        _pendingEmail = _emailController.text.trim();
        _pendingUsername = _usernameController.text.trim();
        await Supabase.instance.client.auth.signUp(
          email: _pendingEmail,
          password: _passController.text.trim(),
        );
        setState(() {
          _otpSent = true;
          _success = '✅ OTP sent! Please check your email.';
        });
      }
    } catch (e) {
      setState(() {
        _error = friendlyError(e.toString());
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        email: _pendingEmail,
        token: _otpController.text.trim(),
        type: OtpType.signup,
      );
      if (res.user != null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': res.user!.id,
          'username': _pendingUsername,
          'highscore': 0,
          'accuracy': 0.0,
          'wpm': 0.0,
        });
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const GameScreen()));
        }
      }
    } catch (e) {
      setState(() {
        _error = '❌ Invalid or expired OTP. Please try again.';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'This action is permanent and cannot be undone. All your progress will be lost.',
            style: TextStyle(color: Color(0xFF8B8BAD))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFC084FC)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _loading = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .delete()
            .eq('id', user.id);
        await Supabase.instance.client.auth.admin.deleteUser(user.id);
      }
      await Supabase.instance.client.auth.signOut();
      setState(() {
        _success = '✅ Account deleted successfully.';
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e.toString());
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
              child: _glowBlob(_purple.withOpacity(0.25), 380)),
          Positioned(
              bottom: -100,
              right: -60,
              child: _glowBlob(_accent.withOpacity(0.15), 300)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _otpSent
                            ? OtpCard(
                                otpController: _otpController,
                                pendingEmail: _pendingEmail,
                                error: _error,
                                loading: _loading,
                                onVerify: _verifyOtp,
                                onBack: () => setState(() {
                                  _otpSent = false;
                                  _error = '';
                                }),
                              )
                            : LoginCard(
                                isLogin: _isLogin,
                                loading: _loading,
                                showPassword: _showPassword,
                                error: _error,
                                success: _success,
                                emailController: _emailController,
                                passController: _passController,
                                usernameController: _usernameController,
                                onSubmit: _submit,
                                onSwitchMode: _switchMode,
                                onForgotPassword: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen())),
                                onDeleteAccount: _deleteAccount,
                                onTogglePassword: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _buildHeader() {
    return Column(children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _card,
          border: Border.all(color: _purple.withOpacity(0.6), width: 2),
          boxShadow: [
            BoxShadow(
                color: _purple.withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: 2)
          ],
        ),
        child: const Center(child: Text('🥷', style: TextStyle(fontSize: 36))),
      ),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (bounds) =>
            const LinearGradient(colors: [_purpleLight, _accent])
                .createShader(bounds),
        child: const Text('Word Ninja',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5)),
      ),
      const SizedBox(height: 6),
      Text(_isLogin ? 'Welcome back, Ninja! 🥷' : 'Join the dojo today! ⚔️',
          style: const TextStyle(color: _textSecondary, fontSize: 14)),
    ]);
  }
}
