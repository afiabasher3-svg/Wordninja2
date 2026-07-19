import 'package:flutter/material.dart';
import 'dart:math';
import '../models/word_tile.dart';
import '../painters/balloon_painter.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
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
  int _totalWords = 0, _correctWords = 0;
  DateTime? _gameStart;
  double _wpm = 0, _accuracy = 0;

  final List<Color> balloonColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.cyanAccent,
    Colors.orangeAccent,
  ];

  final List<String> normalWords = [
    "slice",
    "ninja",
    "blade",
    "swift",
    "sharp",
    "speed",
    "focus",
    "words",
    "grace",
    "power",
    "flash",
    "quest",
    "tiger",
    "storm",
    "brave",
    "craft",
    "agile",
    "skill",
    "laser",
    "punch",
    "flame",
    "crest",
    "glide",
    "snipe",
    "dodge",
  ];

  final List<String> powerWords = [
    "keyboard",
    "practice",
    "velocity",
    "accuracy",
    "reaction",
    "destroy",
    "achieve",
    "warrior",
    "champion",
    "precision",
    "challenge",
    "lightning",
  ];

  late AnimationController _gameLoop;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);
  }

  void startGame() {
    setState(() {
      tiles.clear();
      particles.clear();
      score = 0;
      lives = 3;
      level = 1;
      gameActive = true;
      gameOver = false;
      _tickCount = 0;
      _totalWords = 0;
      _correctWords = 0;
      _gameStart = DateTime.now();
      _controller.clear();
    });
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
      double speed = 0.4 + (level * 0.06);
      for (var t in tiles) {
        if (!t.isPopping) t.y -= t.isPower ? speed * 0.7 : speed;
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
          _totalWords++;
          lives--;
          _spawnParticles(t.x + 45, 60, t.balloonColor, isSpike: true);
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
        if (_tickCount % (_spawnInterval * 5) == 0) _spawnPowerWord();
      }
      if (_tickCount % 500 == 0 && level < 10) {
        level++;
        _spawnInterval = max(100, 160 - level * 8);
      }
    });
  }

  void _spawnWord() {
    if (!gameActive) return;
    if (tiles.length >= 4) return;
    final word = normalWords[_random.nextInt(normalWords.length)];
    final x = 20 + _random.nextDouble() * (_screenWidth - 140);
    final color = balloonColors[_random.nextInt(balloonColors.length)];
    setState(() => tiles.add(WordTile(
          word: word,
          x: x,
          y: _screenHeight - 150,
          balloonColor: color,
        )));
  }

  void _spawnPowerWord() {
    if (!gameActive) return;
    if (tiles.length >= 4) return;
    final word = powerWords[_random.nextInt(powerWords.length)];
    final x = 20 + _random.nextDouble() * (_screenWidth - 180);
    setState(() => tiles.add(WordTile(
          word: word,
          x: x,
          y: _screenHeight - 150,
          isPower: true,
          balloonColor: Colors.amber,
        )));
  }

  void _checkWord() {
    final typed = _controller.text.toLowerCase().trim();
    final match = tiles.where((t) => t.word == typed && !t.isPopping).toList();
    if (match.isNotEmpty) {
      final tile = match.first;
      _spawnParticles(tile.x + 45, tile.y + 50, tile.balloonColor);
      setState(() {
        tile.isPopping = true;
        score += tile.isPower ? typed.length * level * 3 : typed.length * level;
        _totalWords++;
        _correctWords++;
        _controller.clear();
      });
      Future.delayed(const Duration(milliseconds: 400),
          () => setState(() => tiles.remove(tile)));
    }
  }

  void _calculateStats() {
    final elapsed = DateTime.now().difference(_gameStart!).inSeconds;
    _wpm = elapsed > 0 ? (_correctWords / elapsed * 60) : 0;
    _accuracy = _totalWords > 0 ? (_correctWords / _totalWords * 100) : 0;
  }

  void _endGame() async {
    _calculateStats();
    setState(() {
      gameActive = false;
      gameOver = true;
    });
    _gameLoop.stop();
    await SupabaseService.saveScore(
        score: score, accuracy: _accuracy, wpm: _wpm);
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (gameActive) {
          _calculateStats();
          final quit = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Quit Game?',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
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
                      _dialogStatRow(
                          '🎯 Accuracy',
                          '${_accuracy.toStringAsFixed(1)}%',
                          Colors.greenAccent),
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
                          color: Color(0xFFC084FC),
                          fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Quit',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (quit == true) {
            _gameLoop.stop();
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()));
            }
          }
          return false;
        }
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Score: $score',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white)),
                    Text('Level: $level',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.amber)),
                    Row(children: [
                      Text('❤️' * lives + '🖤' * (3 - lives),
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.home_rounded,
                            color: Colors.white38, size: 20),
                        onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen())),
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
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        size: Size(_screenWidth, 50),
                        painter: SpikesPainter(),
                      ),
                    ),
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
                                              color: p.color.withOpacity(0.6),
                                              blurRadius: 4)
                                        ])),
                          ),
                        )),
                    ...tiles.map((tile) => Positioned(
                        left: tile.x, top: tile.y, child: _buildBalloon(tile))),
                    if (!gameActive)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            margin: const EdgeInsets.symmetric(horizontal: 32),
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
                                        : 'Word Ninja 🎯',
                                    style: const TextStyle(
                                        fontSize: 28,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                if (gameOver) ...[
                                  const Divider(color: Colors.white24),
                                  const SizedBox(height: 8),
                                  _statRow('🏆 Score', '$score', Colors.amber),
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
                                  onPressed: startGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 40, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                      gameOver ? 'Play Again' : 'Start Game',
                                      style: const TextStyle(fontSize: 18)),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const HomeScreen())),
                                  child: const Text('🏠 Home',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
                        borderSide: const BorderSide(color: Colors.white24)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.deepPurple)),
                  ),
                  onChanged: (_) => _checkWord(),
                ),
              ),
            ],
          ),
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
