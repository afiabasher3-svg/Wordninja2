import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mode_selection_screen.dart';
import 'login_screen.dart';
import 'word_notes_screen.dart';
import 'history_screen.dart';
import 'progress_chart_screen.dart';
import '../widgets/gradient_button.dart';
import '../widgets/badge_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  static const _bg = Color(0xFF0A0A14);
  static const _card = Color(0xFF1A1A2E);
  static const _border = Color(0xFF2A2A45);
  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFF9D5CF6);
  static const _accent = Color(0xFFC084FC);
  static const _textSecondary = Color(0xFF8B8BAD);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      setState(() {
        _profile = data;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _onExitConfirm() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Want to exit?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to close the app?',
            style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: _purpleLight, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (exit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final highscore = (_profile?['highscore'] ?? 0) as int;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onExitConfirm();
      },
      child: Scaffold(
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
                        color: _purple.withOpacity(0.2)))),
            Positioned(
                bottom: -100,
                right: -60,
                child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withOpacity(0.12)))),
            SafeArea(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF7C3AED)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, ${_profile?['username'] ?? 'Ninja'}! 👋',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Ready to type?',
                                      style: TextStyle(
                                          color: _textSecondary, fontSize: 13)),
                                ],
                              ),
                              IconButton(
                                onPressed: _logout,
                                icon: const Icon(Icons.logout_rounded,
                                    color: _textSecondary),
                                tooltip: 'Logout',
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // App logo (uploaded image)
                          Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _card,
                                border: Border.all(
                                    color: _purple.withOpacity(0.6), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: _purple.withOpacity(0.4),
                                      blurRadius: 30,
                                      spreadRadius: 5)
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/playstore.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                                    colors: [_purpleLight, _accent])
                                .createShader(bounds),
                            child: const Text('Word Ninja',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1)),
                          ),
                          const SizedBox(height: 32),

                          // Stats
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statItem('🏆', 'Best Score', '$highscore'),
                                _divider(),
                                _statItem('🎯', 'Accuracy',
                                    '${(_profile?['accuracy'] ?? 0.0).toStringAsFixed(1)}%'),
                                _divider(),
                                _statItem('⚡', 'WPM',
                                    '${(_profile?['wpm'] ?? 0.0).toStringAsFixed(1)}'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Play button
                          SizedBox(
                            height: 58,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C3AED),
                                      Color(0xFF9D3AED)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                boxShadow: [
                                  BoxShadow(
                                      color: _purple.withOpacity(0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6))
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ModeSelectionScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16))),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('🎮', style: TextStyle(fontSize: 22)),
                                    SizedBox(width: 10),
                                    Text('Play Now',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Vocabulary Notebook
                          GradientButton(
                            label: 'Vocabulary Notebook 📓',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const WordNotesScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Result History
                          GradientButton(
                            label: 'Result History 📊',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HistoryScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Accuracy Progress Graph
                          GradientButton(
                            label: 'Accuracy Progress 📈',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ProgressChartScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // How to play
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('How to Play',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                _howToItem(
                                    '🎈', 'Balloons rise from the bottom'),
                                _howToItem(
                                    '⌨️', 'Type the word to pop the balloon'),
                                _howToItem(
                                    '⚡', 'Golden balloons give bonus points'),
                                _howToItem('💀',
                                    'Miss 3 balloons and it\'s game over'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Badge — সবসময় home screen-এর কোনায় দেখা যাবে
            if (!_loading) BadgeCorner(highscore: highscore),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String emoji, String label, String value) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
    ]);
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: _border);
  }

  Widget _howToItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: _textSecondary, fontSize: 13)),
      ]),
    );
  }
}
