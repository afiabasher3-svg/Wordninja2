import 'package:flutter/material.dart';
import 'dart:math';
import '../models/word_tile.dart';
import '../models/word_note.dart';
import '../models/topic.dart';
import '../painters/balloon_painter.dart';
import '../services/supabase_service.dart';
import '../painters/topic_background.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final String mode;
  final List<Topic> topics;

  /// Part 9: when set, the game should be seeded from these words
  /// instead of (or in addition to) the normal topic pool.
  final List<WordNote>? reviewWords;

  const GameScreen({
    super.key,
    required this.mode,
    required this.topics,
    this.reviewWords,
  });

  // Convenience accessors so the rest of the screen reads naturally when
  // one or several topics are in play.
  List<int> get topicIds => topics.map((t) => t.id).toList();
  Color get themeColor => topics.first.themeColor;
  Color get bgColor => topics.first.bgColor;
  String get topicName => topics.map((t) => t.name).join(' + ');
  String get topicEmoji => topics.map((t) => t.emoji).join(' ');

  /// Primary topic id — used for session tracking / result screen when a
  /// single representative topic id is needed (e.g. multi-topic sessions
  /// are recorded under their first topic).
  int get topicId => topics.first.id;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _random = Random();
  List<WordTile> tiles = [];
  List<_Particle> particles = [];
  int score = 0, lives = 3, level = 1;
  bool gameActive = false, gameOver = false;
  int _tickCount = 0, _spawnInterval = 160;
  int _totalAttempts = 0, _correctWords = 0;
  DateTime? _gameStart;
  double _wpm = 0, _accuracy = 0;
  bool _flashRed = false;
  List<Map<String, dynamic>> _wordPool = [];

  // --- Vocabulary Notebook session tracking (Part 3) ---
  final List<WordNote> _sessionWords = [];
  final Set<String> _sessionWordKeys = {}; // de-dup guard
  final Stopwatch _sessionStopwatch = Stopwatch();

  late AnimationController _gameLoop;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);
    _loadWords();
  }

  Future<void> _loadWords() async {
    final data = await SupabaseService.client
        .from('words')
        .select()
        .inFilter('topic_id', widget.topicIds)
        .eq('difficulty', widget.mode);
    setState(() {
      _wordPool = List<Map<String, dynamic>>.from(data);
    });
  }

  /// Looks up a word's own topic so multi-topic games can color/tag each
  /// balloon by the topic it actually belongs to.
  Topic _topicForWord(Map<String, dynamic> wordData) {
    final id = wordData['topic_id'];
    return widget.topics
        .firstWhere((t) => t.id == id, orElse: () => widget.topics.first);
  }

  // Synonym balloons unlock once the player has leveled up a bit, on top of
  // the existing advanced-mode behavior.
  static const int _synonymUnlockLevel = 3;
  bool get _synonymsActive => widget.mode == 'advanced';

  /// status must be one of: 'popped' | 'missed' | 'synonym'
  void _trackSessionWord({
    required String word,
    String? meaning,
    String? pronunciation,
    int? topicId,
    required String status,
  }) {
    final note = WordNote(
      word: word,
      meaning: meaning ?? '',
      pronunciation: pronunciation ?? '',
      topicId: topicId ?? widget.topicId,
      mode: widget.mode,
      status: status,
    );

    // Avoid duplicate entries for the same word+topic+mode within one session.
    if (_sessionWordKeys.add(note.sessionKey)) {
      _sessionWords.add(note);
    } else {
      // Word already tracked this session — upgrade its status if the
      // new interaction is "better" (popped/synonym should win over missed).
      final idx =
          _sessionWords.indexWhere((w) => w.sessionKey == note.sessionKey);
      if (idx != -1 &&
          _sessionWords[idx].status == 'missed' &&
          status != 'missed') {
        _sessionWords[idx] = _sessionWords[idx].copyWith(status: status);
      }
    }
  }

  void startGame() {
    if (_wordPool.isEmpty) return;
    setState(() {
      tiles.clear();
      particles.clear();
      score = 0;
      lives = 3;
      level = 1;
      gameActive = true;
      gameOver = false;
      _tickCount = 0;
      _totalAttempts = 0;
      _correctWords = 0;
      _sessionWords.clear();
      _sessionWordKeys.clear();
      _gameStart = DateTime.now();
      _controller.clear();
      _flashRed = false;
    });
    _sessionStopwatch
      ..reset()
      ..start();
    _gameLoop.forward(from: 0);
    _spawnWord();
  }

  double get _screenHeight => MediaQuery.of(context).size.height;
  double get _screenWidth => MediaQuery.of(context).size.width;

  void _spawnParticles(double x, double y, Color color,
      {bool isSpike = false}) {
    for (int i = 0; i < 12; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 2 + _random.nextDouble() * 4;
      particles.add(_Particle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: isSpike ? Colors.redAccent : color,
        life: 1.0,
        isSpike: isSpike,
      ));
    }
  }

  void _tick() {
    if (!gameActive) return;
    _tickCount++;
    setState(() {
      // Speed climbs faster with each level so higher levels feel
      // noticeably more intense, not just marginally quicker.
      double speed = 0.7 + (level * 0.10) + (level * level * 0.005);
      for (var t in tiles) {
        if (!t.isPopping) t.y -= t.isPower ? speed * 0.85 : speed;
      }

      for (var p in particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.15;
        p.life -= 0.04;
      }
      particles.removeWhere((p) => p.life <= 0);

      tiles.removeWhere((t) {
        if (t.isPopping) return false;
        if (t.y < 55) {
          lives--;
          _spawnParticles(t.x + 45, 60, t.balloonColor, isSpike: true);

          // session words এ missed হিসেবে যোগ করো
          final wordData = _wordPool.firstWhere((w) => w['word'] == t.word,
              orElse: () => {});
          _trackSessionWord(
            word: t.word,
            meaning: wordData['meaning'] as String?,
            pronunciation: wordData['pronunciation'] as String?,
            topicId: wordData['topic_id'] as int?,
            status: 'missed',
          );

          if (lives <= 0) _endGame();
          return true;
        }
        return false;
      });

      String typed = _controller.text.toLowerCase().trim();
      for (var t in tiles) {
        t.isActive = typed.isNotEmpty && t.word.startsWith(typed);
      }

      if (_tickCount % _spawnInterval == 0) {
        _spawnWord();
      }
      if (_tickCount % 500 == 0 && level < 15) {
        level++;
        _spawnInterval = max(70, 160 - level * 8);
      }
    });
  }

  void _spawnWord() {
    if (!gameActive) return;
    if (tiles.length >= 4) return;
    if (_wordPool.isEmpty) return;

    final wordData = _wordPool[_random.nextInt(_wordPool.length)];
    final word = wordData['word'] as String;

    // একই word দুইবার না আসে
    if (tiles.any((t) => t.word == word)) return;

    final x = 20 + _random.nextDouble() * (_screenWidth - 140);
    final topic = _topicForWord(wordData);

    setState(() => tiles.add(WordTile(
          word: word,
          x: x,
          y: _screenHeight - 150,
          balloonColor: topic.themeColor,
          isPower: false,
        )));
  }

  void _spawnSynonymBalloon(String synonym) {
    if (!mounted) return;
    final x = 20 + _random.nextDouble() * (_screenWidth - 140);
    setState(() {
      tiles.add(WordTile(
        word: synonym,
        x: x,
        y: _screenHeight - 150,
        balloonColor: Colors.amber,
        isPower: true,
      ));
    });
  }

  void _checkWord() {
    final typed = _controller.text.toLowerCase().trim();
    if (typed.isEmpty) return;

    final match = tiles.where((t) => t.word == typed && !t.isPopping).toList();

    if (match.isNotEmpty) {
      final tile = match.first;
      _spawnParticles(tile.x + 45, tile.y + 50, tile.balloonColor);

      // session words এ track করো (pool এ থাকুক বা না থাকুক — synonym balloon
      // এর word pool এ নাও থাকতে পারে, সেক্ষেত্রে meaning/pronunciation ফাঁকা যাবে)
      final wordData =
          _wordPool.firstWhere((w) => w['word'] == tile.word, orElse: () => {});
      _trackSessionWord(
        word: tile.word,
        meaning: wordData['meaning'] as String?,
        pronunciation: wordData['pronunciation'] as String?,
        topicId: wordData['topic_id'] as int?,
        status: tile.isPower ? 'synonym' : 'popped',
      );

      setState(() {
        tile.isPopping = true;
        score += tile.isPower ? typed.length * level * 3 : typed.length * level;
        _correctWords++;
        _controller.clear();
      });

      // Synonym balloon spawns once unlocked (advanced mode, or any mode
      // after leveling up)
      if (_synonymsActive && !tile.isPower) {
        final original = _wordPool.firstWhere((w) => w['word'] == tile.word,
            orElse: () => {});
        if (original.isNotEmpty) {
          final synonyms = List<String>.from(original['synonyms'] ?? []);
          if (synonyms.isNotEmpty) {
            final synonym = synonyms[_random.nextInt(synonyms.length)];
            Future.delayed(const Duration(milliseconds: 500), () {
              _spawnSynonymBalloon(synonym);
            });
          }
        }
      }

      Future.delayed(const Duration(milliseconds: 400),
          () => setState(() => tiles.remove(tile)));
    }
  }

  void _onSubmitted(String value) {
    final typed = value.toLowerCase().trim();
    if (typed.isEmpty) return;

    final match = tiles.where((t) => t.word == typed && !t.isPopping).toList();

    if (match.isEmpty) {
      // ভুল word — red flash + clear
      _totalAttempts++;
      setState(() => _flashRed = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _flashRed = false);
      });
      _controller.clear();
    }
  }

  void _calculateStats() {
    final elapsed = DateTime.now().difference(_gameStart!).inSeconds;
    _wpm = elapsed > 0 ? (_correctWords / elapsed * 60) : 0;
    _accuracy = (_totalAttempts + _correctWords) > 0
        ? (_correctWords / (_totalAttempts + _correctWords) * 100)
        : 0;
  }

  Future<void> _endGame() async {
    _calculateStats();
    setState(() {
      gameActive = false;
      gameOver = true;
    });
    _gameLoop.stop();
    _sessionStopwatch.stop();

    await SupabaseService.saveScore(
        score: score, accuracy: _accuracy, wpm: _wpm);

    // Part 8: save the session's words to Supabase before navigating.
    // Non-fatal if this fails — don't block the player from seeing
    // their results just because the notebook sync failed.
    try {
      if (_sessionWords.isNotEmpty) {
        await SupabaseService.saveSessionWords(_sessionWords);
      }
    } catch (_) {
      // TODO: hook into your existing ErrorHelper if you want visibility.
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          topicEmoji: widget.topicEmoji,
          topicName: widget.topicName,
          topicId: widget.topicId,
          mode: widget.mode,
          finalScore: score,
          accuracy: _accuracy,
          wpm: _wpm,
          levelReached: level,
          wordsPopped: _sessionWords.where((w) => w.status == 'popped').length,
          wordsMissed: _sessionWords.where((w) => w.status == 'missed').length,
          synonymsCompleted:
              _sessionWords.where((w) => w.status == 'synonym').length,
          timePlayed: _sessionStopwatch.elapsed,
          sessionWords: _sessionWords,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (gameActive) {
      _calculateStats();
      final quit = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Quit Game?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to quit?',
                  style: TextStyle(color: Color(0xFF8B8BAD))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  _dialogStatRow('🏆 Score', '$score', Colors.amber),
                  _dialogStatRow('🎯 Accuracy',
                      '${_accuracy.toStringAsFixed(1)}%', Colors.greenAccent),
                  _dialogStatRow(
                      '⚡ WPM', _wpm.toStringAsFixed(1), Colors.cyanAccent),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Playing',
                  style: TextStyle(
                      color: Color(0xFFC084FC), fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quit',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (quit == true) {
        _gameLoop.stop();
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
      return false;
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            TopicBackground(topics: widget.topics),
            if (_flashRed) Container(color: Colors.red.withOpacity(0.15)),
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Score: $score',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white)),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${widget.topicEmoji} ${widget.topicName}',
                              style: TextStyle(
                                  fontSize: 13, color: widget.themeColor),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Row(children: [
                          Text('❤️' * lives + '🖤' * (3 - lives),
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.home_rounded,
                                color: Colors.white38, size: 20),
                            onPressed: () async => await _onWillPop(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.white38, size: 20),
                            onPressed: () async {
                              await SupabaseService.signOut();
                              if (mounted) {
                                Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()));
                              }
                            },
                          ),
                        ]),
                      ],
                    ),
                  ),

                  // Game area
                  Expanded(
                    child: Stack(
                      children: [
                        // Spikes
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: CustomPaint(
                            size: Size(_screenWidth, 50),
                            painter: SpikesPainter(),
                          ),
                        ),

                        // Particles
                        ...particles.map((p) => Positioned(
                              left: p.x,
                              top: p.y,
                              child: Opacity(
                                opacity: p.life.clamp(0.0, 1.0),
                                child: p.isSpike
                                    ? Transform.rotate(
                                        angle: p.life * 5,
                                        child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                                color: p.color,
                                                shape: BoxShape.rectangle)))
                                    : Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                            color: p.color,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color:
                                                      p.color.withOpacity(0.6),
                                                  blurRadius: 4)
                                            ])),
                              ),
                            )),

                        // Balloons
                        ...tiles.map((tile) => Positioned(
                            left: tile.x,
                            top: tile.y,
                            child: _buildBalloon(tile))),

                        // Start / Game Over overlay
                        if (!gameActive)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        gameOver
                                            ? 'Game Over! 💀'
                                            : '${widget.topicEmoji} ${widget.topicName}',
                                        style: const TextStyle(
                                            fontSize: 26,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(
                                        widget.mode == 'easy'
                                            ? '🟢 Easy Mode'
                                            : '🔴 Advanced Mode',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: widget.themeColor)),
                                    if (gameOver) ...[
                                      const SizedBox(height: 12),
                                      const Divider(color: Colors.white24),
                                      _statRow(
                                          '🏆 Score', '$score', Colors.amber),
                                      _statRow(
                                          '🎯 Accuracy',
                                          '${_accuracy.toStringAsFixed(1)}%',
                                          Colors.greenAccent),
                                      _statRow('⚡ WPM', _wpm.toStringAsFixed(1),
                                          Colors.cyanAccent),
                                      const SizedBox(height: 8),
                                    ],
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed:
                                          _wordPool.isEmpty ? null : startGame,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.themeColor,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 40, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                          gameOver
                                              ? 'Play Again'
                                              : 'Start Game',
                                          style: const TextStyle(fontSize: 18)),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const HomeScreen())),
                                      child: const Text('🏠 Home',
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 14)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Input field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: TextField(
                      controller: _controller,
                      enabled: gameActive,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Type here...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.white24)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: widget.themeColor)),
                      ),
                      onChanged: (_) => _checkWord(),
                      onSubmitted: _onSubmitted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _dialogStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBalloon(WordTile tile) {
    final typed = _controller.text.toLowerCase().trim();
    if (tile.isPopping) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 3.0),
        duration: const Duration(milliseconds: 350),
        builder: (context, scale, child) => Opacity(
          opacity: (3.0 - scale) / 2.0,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tile.balloonColor.withOpacity(0.5),
                boxShadow: [
                  BoxShadow(
                      color: tile.balloonColor, blurRadius: 20, spreadRadius: 5)
                ],
              ),
            ),
          ),
        ),
      );
    }

    double w = tile.isPower ? 115.0 : 95.0;
    double h = w * 1.3;

    return SizedBox(
      width: w,
      child: CustomPaint(
        size: Size(w, h),
        painter: BalloonPainter(
          color: tile.balloonColor,
          isActive: tile.isActive,
          isPower: tile.isPower,
        ),
        child: SizedBox(
          width: w,
          height: h,
          child: Padding(
            padding: EdgeInsets.fromLTRB(6, h * 0.15, 6, h * 0.28),
            child: Center(
              child: tile.isActive && typed.isNotEmpty
                  ? RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(children: [
                        TextSpan(
                          text: tile.word.substring(0, typed.length),
                          style: TextStyle(
                            color: tile.isPower
                                ? Colors.amber
                                : Colors.greenAccent,
                            fontSize: tile.isPower ? 17 : 15,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                  blurRadius: 8,
                                  color: tile.isPower
                                      ? Colors.amber
                                      : Colors.greenAccent),
                              const Shadow(
                                  blurRadius: 4, color: Colors.black87),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: tile.word.substring(typed.length),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: tile.isPower ? 17 : 15,
                            shadows: const [
                              Shadow(blurRadius: 4, color: Colors.black87)
                            ],
                          ),
                        ),
                      ]),
                    )
                  : Text(tile.word,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tile.isPower ? Colors.amber : Colors.white,
                        fontSize: tile.isPower ? 17 : 15,
                        fontWeight:
                            tile.isPower ? FontWeight.bold : FontWeight.normal,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black87)
                        ],
                      )),
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  double x, y, vx, vy, life;
  Color color;
  bool isSpike;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
    this.isSpike = false,
  });
}
