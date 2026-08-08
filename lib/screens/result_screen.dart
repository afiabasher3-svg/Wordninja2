import 'package:flutter/material.dart';
import '../models/word_note.dart';
import '../services/supabase_service.dart';
import '../widgets/gradient_button.dart';
import 'mode_selection_screen.dart';
import 'home_screen.dart';
import 'word_notes_screen.dart';

const Color kBgDark = Color(0xFF0A0A14);
const Color kBgCard = Color(0xFF1A1A2E);
const Color kPurplePrimary = Color(0xFF7C3AED);
const Color kPurpleAccent = Color(0xFF9D5CF6);
const Color kPurpleLight = Color(0xFFC084FC);

class ResultScreen extends StatefulWidget {
  final String topicEmoji;
  final String topicName;
  final int topicId;
  final String mode;
  final int finalScore;
  final double accuracy;
  final double wpm;
  final int levelReached;
  final int wordsPopped;
  final int wordsMissed;
  final int synonymsCompleted;
  final Duration timePlayed;
  final List<WordNote> sessionWords;

  const ResultScreen({
    super.key,
    required this.topicEmoji,
    required this.topicName,
    required this.topicId,
    required this.mode,
    required this.finalScore,
    required this.accuracy,
    required this.wpm,
    required this.levelReached,
    required this.wordsPopped,
    required this.wordsMissed,
    required this.synonymsCompleted,
    required this.timePlayed,
    this.sessionWords = const [],
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final Set<String> _savedWords = {};

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  Future<void> _toggleSave(WordNote note) async {
    final word = note.word;
    final newSaved = !_savedWords.contains(word);
    setState(() {
      if (newSaved) {
        _savedWords.add(word);
      } else {
        _savedWords.remove(word);
      }
    });
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.client
          .from('word_notes')
          .update({'saved': newSaved})
          .eq('user_id', userId)
          .eq('word', word)
          .eq('topic_id', note.topicId)
          .eq('mode', note.mode);
    } catch (_) {}
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'popped':
        return const Color(0xFF34D399);
      case 'missed':
        return const Color(0xFFF87171);
      case 'synonym':
        return const Color(0xFFFBBF24);
      default:
        return kPurpleLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'popped':
        return '✅ Popped';
      case 'missed':
        return '❌ Missed';
      case 'synonym':
        return '⭐ Synonym';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Text(widget.topicEmoji,
                    style: const TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(widget.topicName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  widget.mode == 'advanced'
                      ? '🔴 Advanced Mode'
                      : '🟢 Easy Mode',
                  style: const TextStyle(
                      color: kPurpleLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              _buildScoreHero(),
              const SizedBox(height: 20),
              _buildStatsGrid(),
              const SizedBox(height: 28),

              // Word Gallery
              if (widget.sessionWords.isNotEmpty) ...[
                const Text('Word Gallery',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Swipe to browse • 🔖 to save to notebook',
                    style: TextStyle(color: Color(0xFF8B8BAD), fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: widget.sessionWords.length,
                    controller: PageController(viewportFraction: 0.88),
                    itemBuilder: (context, index) {
                      final note = widget.sessionWords[index];
                      final isSaved = _savedWords.contains(note.word);
                      final color = _statusColor(note.status);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kBgCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: color.withOpacity(0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: color.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(note.word,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold)),
                                        if (note.pronunciation.isNotEmpty)
                                          Text('/${note.pronunciation}/',
                                              style: const TextStyle(
                                                  color: kPurpleLight,
                                                  fontSize: 13,
                                                  fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _toggleSave(note),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSaved
                                            ? kPurplePrimary
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: isSaved
                                                ? kPurplePrimary
                                                : Colors.white38,
                                            width: 1.5),
                                      ),
                                      child: Icon(
                                        isSaved
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: isSaved
                                            ? Colors.white
                                            : Colors.white38,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: color.withOpacity(0.4)),
                                ),
                                child: Text(_statusLabel(note.status),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Text(note.meaning,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                    overflow: TextOverflow.fade),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Play Again
              GradientButton(
                label: 'Play Again 🎮',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ModeSelectionScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Home
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('🏠 Home',
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreHero() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPurplePrimary, kPurpleAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: kPurplePrimary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          const Text('FINAL SCORE',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text('${widget.finalScore}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatItem('Accuracy', '${widget.accuracy.toStringAsFixed(0)}%',
          Icons.gps_fixed),
      _StatItem('WPM', '${widget.wpm.toStringAsFixed(0)}', Icons.speed),
      _StatItem('Level Reached', '${widget.levelReached}', Icons.stairs),
      _StatItem('Time Played', _formatDuration(widget.timePlayed),
          Icons.timer_outlined),
      _StatItem(
          'Words Popped', '${widget.wordsPopped}', Icons.check_circle_outline),
      _StatItem('Words Missed', '${widget.wordsMissed}', Icons.cancel_outlined),
      _StatItem('Synonyms', '${widget.synonymsCompleted}', Icons.auto_awesome),
    ];

    return Column(
      children: stats
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: kBgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kPurplePrimary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(s.icon, color: kPurpleLight, size: 20),
                      const SizedBox(width: 12),
                      Text(s.label,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14)),
                      const Spacer(),
                      Text(s.value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  _StatItem(this.label, this.value, this.icon);
}

