import 'package:flutter/material.dart';
import 'topic_selection_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  static const _bg = Color(0xFF0A0A14);
  static const _card = Color(0xFF1A1A2E);
  static const _border = Color(0xFF2A2A45);
  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFF9D5CF6);
  static const _accent = Color(0xFFC084FC);
  static const _textSecondary = Color(0xFF8B8BAD);

  // 'survival' | 'time_attack' | 'zen'
  String _gameType = 'survival';

  void _goToTopics(String mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TopicSelectionScreen(mode: mode, gameType: _gameType),
      ),
    );
  }

  Widget _gameTypeChip(String value, String emoji, String label) {
    final selected = _gameType == value;
    return GestureDetector(
      onTap: () => setState(() => _gameType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _purple.withOpacity(0.25) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _purpleLight : _border,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : _textSecondary,
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  const Text(
                    'Select Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your challenge level',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // Game type selector
                  const Text('Game Type',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _gameTypeChip('survival', '❤️', 'Survival')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _gameTypeChip(
                              'time_attack', '⏱️', 'Time Attack')),
                      const SizedBox(width: 10),
                      Expanded(child: _gameTypeChip('zen', '🧘', 'Zen')),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Word Pop Mode Card
                  _ModeCard(
                    emoji: '🟢',
                    title: 'Word Pop',
                    subtitle: 'Perfect for beginners',
                    description:
                        'Balloons rise from the bottom. Type the word to pop it before it reaches the top.',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderColor: const Color(0xFF52B788),
                    glowColor: const Color(0xFF52B788),
                    onTap: () => _goToTopics('easy'),
                  ),
                  const SizedBox(height: 20),

                  // Synonym Pop Mode Card
                  _ModeCard(
                    emoji: '🔴',
                    title: 'Synonym Pop',
                    subtitle: 'For IELTS warriors',
                    description:
                        'Pop the word, then its synonym balloon appears. Chain reactions test your vocabulary depth.',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B1A1A), Color(0xFFB91C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderColor: const Color(0xFFEF4444),
                    glowColor: const Color(0xFFEF4444),
                    onTap: () => _goToTopics('advanced'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final LinearGradient gradient;
  final Color borderColor;
  final Color glowColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    required this.borderColor,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: glowColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13)),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.6), size: 18),
              ],
            ),
            const SizedBox(height: 16),
            Text(description,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}
