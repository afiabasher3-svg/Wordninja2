import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'game_screen.dart';

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
  static const _surface = Color(0xFF12121F);
  static const _card = Color(0xFF1A1A2E);
  static const _border = Color(0xFF2A2A45);
  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFF9D5CF6);
  static const _accent = Color(0xFFC084FC);
  static const _textPrimary = Color(0xFFF1F0FF);
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
        if (_usernameController.text.trim().isEmpty) {
          setState(() {
            _error = 'Username দিতে হবে।';
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
          _success = 'OTP পাঠানো হয়েছে! Email check করুন।';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
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
        _error = 'OTP ভুল অথবা মেয়াদ শেষ।';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _error = 'Email লিখে তারপর press করুন।';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _success = '';
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      setState(() {
        _success = 'Password reset link পাঠানো হয়েছে!';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
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
        title: const Text('Account Delete?',
            style: TextStyle(color: Colors.white)),
        content: const Text('এই কাজ উল্টানো যাবে না।',
            style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: _accent))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
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
        _success = 'Account delete হয়ে গেছে।';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
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
                        _otpSent ? _buildOtpCard() : _buildCard(),
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
      Text(_isLogin ? 'Welcome back, Ninja' : 'Begin your journey',
          style: const TextStyle(color: _textSecondary, fontSize: 14)),
    ]);
  }

  // OTP verification card
  Widget _buildOtpCard() {
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
        const Icon(Icons.mark_email_read_outlined, color: _accent, size: 48),
        const SizedBox(height: 12),
        const Text('OTP Verify করুন',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('$_pendingEmail এ OTP পাঠানো হয়েছে',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 13)),
        const SizedBox(height: 24),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
              color: _textPrimary,
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: const TextStyle(color: _textSecondary, letterSpacing: 8),
            counterText: '',
            filled: true,
            fillColor: _card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 1.5)),
          ),
        ),
        const SizedBox(height: 8),
        if (_error.isNotEmpty)
          _buildBanner(
              message: _error,
              icon: Icons.warning_amber_rounded,
              bgColor: Colors.redAccent.withOpacity(0.10),
              borderColor: Colors.redAccent.withOpacity(0.35),
              textColor: const Color(0xFFFF8A8A)),
        const SizedBox(height: 16),
        _buildGradientButton('Verify OTP', _verifyOtp),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _otpSent = false;
            _error = '';
          }),
          child: const Text('← Back', style: TextStyle(color: _accent)),
        ),
      ]),
    );
  }

  Widget _buildCard() {
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
        _buildTabSwitcher(),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!_isLogin) ...[
              _buildField(_usernameController, 'Username',
                  Icons.person_outline_rounded),
              const SizedBox(height: 12),
            ],
            _buildField(_emailController, 'Email', Icons.email_outlined,
                isEmail: true),
            const SizedBox(height: 12),
            _buildPasswordField(),
          ]),
        ),
        if (_isLogin) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _forgotPassword,
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
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBanner(
              message: _error,
              icon: Icons.warning_amber_rounded,
              bgColor: Colors.redAccent.withOpacity(0.10),
              borderColor: Colors.redAccent.withOpacity(0.35),
              textColor: const Color(0xFFFF8A8A)),
        ],
        if (_success.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBanner(
              message: _success,
              icon: Icons.check_circle_outline_rounded,
              bgColor: Colors.greenAccent.withOpacity(0.08),
              borderColor: Colors.greenAccent.withOpacity(0.30),
              textColor: const Color(0xFF6EE7B7)),
        ],
        const SizedBox(height: 20),
        _buildGradientButton(_isLogin ? 'Login' : 'Create Account', _submit),
        if (_isLogin) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : _deleteAccount,
            child: const Text('Delete Account',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ]),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
      child:
          Row(children: [_tab('Login', _isLogin), _tab('Register', !_isLogin)]),
    );
  }

  Widget _tab(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: active ? null : _switchMode,
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

  Widget _buildField(TextEditingController c, String hint, IconData icon,
      {bool isEmail = false}) {
    return TextField(
      controller: c,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      decoration: _inputDecoration(hint, icon),
      cursorColor: _purpleLight,
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passController,
      obscureText: !_showPassword,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      cursorColor: _purpleLight,
      decoration: _inputDecoration('Password', Icons.lock_outline_rounded,
          suffix: IconButton(
            icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _textSecondary,
                size: 20),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          )),
    );
  }

  Widget _buildBanner(
      {required String message,
      required IconData icon,
      required Color bgColor,
      required Color borderColor,
      required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: textColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style:
                    TextStyle(color: textColor, fontSize: 13, height: 1.45))),
      ]),
    );
  }

  Widget _buildGradientButton(String label, VoidCallback onPressed) {
    return SizedBox(
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
          onPressed: _loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13))),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: _purpleLight, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4)),
        ),
      ),
    );
  }
}
