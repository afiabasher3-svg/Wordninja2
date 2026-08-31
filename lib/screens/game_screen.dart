import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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

  /// 'survival' (default, 3 lives), 'time_attack' (60s countdown, no
  /// lives lost from missed balloons), or 'free_play' (no lives, no timer,
  /// endless practice — player quits manually).
  final String gameType;

  final List<WordNote>? reviewWords;

  const GameScreen({
    super.key,
    required this.mode,
    required this.topics,
    this.gameType = 'survival',
    this.reviewWords,
  });

  List<int> get topicIds => topics.map((t) => t.id).toList();
  Color get themeColor => topics.first.themeColor;
  Color get bgColor => topics.first.bgColor;
  String get topicName => topics.map((t) => t.name).join(' + ');
  String get topicEmoji => topics.map((t) => t.emoji).join(' ');

  bool get isTimeAttack => gameType == 'time_attack';
  // zen → free_play (backward-compat: দুটোই accept করে)
  bool get isFreePlay => gameType == 'free_play' || gameType == 'zen';
  bool get usesLives => gameType == 'survival';
  int get topicId => topics.first.id;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  // Dedicated FocusNode — keyboard কে manually focus করা যাবে
  final _inputFocus = FocusNode();
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

  final List<WordNote> _sessionWords = [];
  final Set<String> _sessionWordKeys = {};
  final Stopwatch _sessionStopwatch = Stopwatch();

  static const int _timeAttackSeconds = 60;
  int _secondsLeft = _timeAttackSeconds;
  Timer? _countdownTimer;

  // --- Synonym Pop (mother/burst) mode bookkeeping ---
  int _groupIdCounter = 0;
  final Set<String> _motherSpawnedForGroup = {};
  static const int _burstTotalTicks = 30;

  // --- Golden Balloon Rain (level-up celebration) ---
  late AnimationController _rainController;
  late AnimationController _levelTextController;
  List<_RainBalloon> _rainBalloons = [];
  bool _rainActive = false;
  int _lastCelebLevel = 0;

  late AnimationController _gameLoop;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);

    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _rainActive = false);
        }
      });

    _levelTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

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

  Topic _topicForWord(Map<String, dynamic> wordData) {
    final id = wordData['topic_id'];
    return widget.topics
        .firstWhere((t) => t.id == id, orElse: () => widget.topics.first);
  }

  bool get _synonymsActive => widget.mode == 'advanced';

  void _trackSessionWord({
    required String word,
    String? meaning,
    String? pronunciation,
    String? exampleSentence,
    int? topicId,
    required String status,
  }) {
    final note = WordNote(
      word: word,
      meaning: meaning ?? '',
      pronunciation: pronunciation ?? '',
      exampleSentence: exampleSentence ?? '',
      topicId: topicId ?? widget.topicId,
      mode: widget.mode,
      status: status,
    );

    if (_sessionWordKeys.add(note.sessionKey)) {
      _sessionWords.add(note);
    } else {
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
      _secondsLeft = _timeAttackSeconds;
      _spawnInterval = 160;
      _rainActive = false;
      _rainBalloons = [];
      _lastCelebLevel = 0;
      _groupIdCounter = 0;
      _motherSpawnedForGroup.clear();
    });
    _sessionStopwatch
      ..reset()
      ..start();
    _countdownTimer?.cancel();
    if (widget.isTimeAttack) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!gameActive) {
          t.cancel();
          return;
        }
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) {
          t.cancel();
          _endGame();
        }
      });
    }
    _gameLoop.forward(from: 0);
    setState(() {
      if (_synonymsActive) {
        // Synonym Pop: শুধু ১টা mother balloon দিয়ে শুরু
        _spawnMother();
      } else {
        for (int i = 0; i < 3; i++) {
          _doSpawnWord();
        }
      }
    });
    // Game শুরু হলে keyboard তুলে রাখো
    Future.microtask(() => _inputFocus.requestFocus());
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
      double speed = 0.4 + (level * 0.045) + (level * level * 0.0015);
      // Boundary line: bottom 60% of screen = fast zone,
      // top 40% = slow zone.
      final midpoint = _screenHeight * 0.4;
      const bottomHalfBoost = 4.2; // bottom (fast) zone — bumped up further
      const topHalfSlow = 0.5; // top (slow) zone

      for (var t in tiles) {
        if (t.isPopping) continue;

        if (t.burstTicksRemaining > 0) {
          // Outward burst (mother→synonym spawn animation). Both axes are
          // eased toward a fixed target offset — guarantees exact spacing
          // (horizontal) and an exact dip distance (vertical), instead of
          // relying on velocity/friction which barely moved things.
          final progress = 1 - (t.burstTicksRemaining / _burstTotalTicks);
          final eased = 1 - pow(1 - progress, 3).toDouble(); // easeOutCubic
          t.x = (t.burstStartX + t.burstTargetOffsetX * eased)
              .clamp(10.0, _screenWidth - 120.0);
          t.y = (t.burstStartY + t.burstTargetOffsetY * eased)
              .clamp(60.0, _screenHeight - 20.0);
          t.burstTicksRemaining--;
        } else {
          final base = t.isPower ? speed * 0.85 : speed;
          final effective =
              t.y > midpoint ? base * bottomHalfBoost : base * topHalfSlow;
          t.y -= effective;
        }
      }

      for (var p in particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.15;
        p.life -= 0.04;
      }
      particles.removeWhere((p) => p.life <= 0);

      int missedCount = 0;
      bool motherMissedThisTick = false;
      tiles.removeWhere((t) {
        if (t.isPopping) return false;
        if (t.y < 55) {
          missedCount++;
          if (widget.usesLives) lives--;
          HapticFeedback.heavyImpact();
          _spawnParticles(t.x + 45, 60, t.balloonColor, isSpike: true);

          final missedTrackWord = t.originalWord ?? t.word;
          final wordData = _wordPool.firstWhere(
              (w) => w['word'] == missedTrackWord,
              orElse: () => {});
          _trackSessionWord(
            word: missedTrackWord,
            meaning: wordData['meaning'] as String?,
            pronunciation: wordData['pronunciation'] as String?,
            exampleSentence: wordData['example_sentence'] as String?,
            topicId: wordData['topic_id'] as int?,
            status: 'missed',
          );

          // Mother miss = normal miss (life lost, fresh mother right away,
          // no burst). Synonym miss just counts toward its group.
          if (_synonymsActive && t.isMother) motherMissedThisTick = true;

          if (widget.usesLives && lives <= 0) _endGame();
          return true;
        }
        return false;
      });

      String typed = _controller.text.toLowerCase().trim();
      for (var t in tiles) {
        t.isActive = typed.isNotEmpty && t.word.startsWith(typed);
      }

      if (_synonymsActive) {
        if (motherMissedThisTick) _spawnMother();
        _checkGroupSpawns();
      } else {
        for (int i = 0; i < missedCount; i++) {
          _doSpawnWord();
        }
      }
    });
  }

  static const int _wordsPerLevel = 8;

  void _maybeLevelUp() {
    final newLevel = 1 + (_correctWords ~/ _wordsPerLevel);
    if (newLevel > level && newLevel <= 15) {
      level = newLevel;
      _spawnInterval = max(70, 160 - level * 8);
      if (level > _lastCelebLevel) {
        _lastCelebLevel = level;
        _triggerGoldenRain();
      }
    }
  }

  void _triggerGoldenRain() {
    final w = _screenWidth;
    _rainBalloons = List.generate(12, (i) {
      final sectionWidth = w / 12;
      return _RainBalloon(
        x: sectionWidth * i + _random.nextDouble() * sectionWidth * 0.8,
        size: 52 + _random.nextDouble() * 36,
        delay: i * 0.028 + _random.nextDouble() * 0.06,
        wobble: 18 + _random.nextDouble() * 28,
        wobblePhase: _random.nextDouble() * 2 * pi,
      );
    });
    setState(() => _rainActive = true);
    HapticFeedback.mediumImpact();
    _rainController.forward(from: 0);
    _levelTextController.forward(from: 0);
  }

  /// Overlap-safe spawn: existing active tiles-এর সাথে minimum horizontal
  /// distance নিশ্চিত করে (২০ বার চেষ্টা করে)। কোথাও পুরো gap না পেলে
  /// spawn skip করে — balloon overlap করার চেয়ে দূরে/দেরিতে spawn ভালো।
  /// (easy/normal difficulty — multi-balloon system, unchanged.)
  void _doSpawnWord() {
    if (!gameActive) return;
    final activeCount = tiles.where((t) => !t.isPopping).length;
    if (activeCount >= 3) return;
    if (_wordPool.isEmpty) return;

    // শব্দ বেছে নাও (duplicate check)
    final available = _wordPool
        .where((w) => !tiles.any((t) => t.word == w['word'] && !t.isPopping))
        .toList();
    if (available.isEmpty) return;

    final wordData = available[_random.nextInt(available.length)];
    final word = wordData['word'] as String;
    final topic = _topicForWord(wordData);

    final bestX = _overlapSafeX();
    if (bestX == null) return; // screen too crowded right now — try next tick

    tiles.add(WordTile(
      word: word,
      x: bestX,
      y: _screenHeight - 150,
      balloonColor: topic.themeColor,
      isPower: false,
    ));
  }

  /// Shared overlap-safe x-position picker. Tries 20 random candidates
  /// and keeps the one farthest from all active tiles. If even the best
  /// candidate is still too close (screen genuinely too crowded), returns
  /// null instead of forcing an overlapping placement — the caller should
  /// just skip spawning this cycle and try again shortly.
  double? _overlapSafeX() {
    const balloonWidth = 110.0; // balloon এর approximate width
    const minGap = 40.0; // দুই balloon-এর মাঝে ন্যূনতম gap — বেশি রাখা হয়েছে
    const minDist = balloonWidth + minGap;

    final activeTiles = tiles.where((t) => !t.isPopping).toList();
    if (activeTiles.isEmpty) {
      return 20 + _random.nextDouble() * (_screenWidth - balloonWidth - 20);
    }

    double bestX =
        20 + _random.nextDouble() * (_screenWidth - balloonWidth - 20);
    double bestScore = -1;

    for (int attempt = 0; attempt < 20; attempt++) {
      final candidateX =
          20 + _random.nextDouble() * (_screenWidth - balloonWidth - 20);
      double minDist2 = double.infinity;
      for (final t in activeTiles) {
        final d = (candidateX - t.x).abs();
        if (d < minDist2) minDist2 = d;
      }
      if (minDist2 > bestScore) {
        bestScore = minDist2;
        bestX = candidateX;
      }
      if (minDist2 >= minDist) break;
    }

    // Hard floor — require the FULL gap (balloonWidth + minGap), not just
    // "not touching". If we can't guarantee real spacing anywhere on
    // screen, skip this spawn entirely rather than place it too close.
    if (bestScore < minDist) return null;
    return bestX;
  }

  void _spawnWord() {
    setState(_doSpawnWord);
  }

  // ─── Synonym Pop (mother/burst) mode ─────────────────────────────────

  bool get _hasMotherOnScreen => tiles.any((t) => t.isMother && !t.isPopping);

  /// Spawns a single mother balloon. Returns false (no-op) if one is
  /// already on screen, the game isn't active, or no word is available.
  bool _spawnMother() {
    if (!gameActive || _hasMotherOnScreen) return false;
    if (_wordPool.isEmpty) return false;

    final available = _wordPool
        .where((w) => !tiles.any((t) => t.word == w['word'] && !t.isPopping))
        .toList();
    if (available.isEmpty) return false;

    final wordData = available[_random.nextInt(available.length)];
    final word = wordData['word'] as String;
    final topic = _topicForWord(wordData);
    final bestX = _overlapSafeX();
    if (bestX == null) return false; // screen too crowded — try next tick

    _groupIdCounter++;
    final groupId =
        'g$_groupIdCounter-${DateTime.now().microsecondsSinceEpoch}';

    tiles.add(WordTile(
      word: word,
      x: bestX,
      y: _screenHeight - 150,
      balloonColor: topic.themeColor,
      isPower: false,
      isMother: true,
      synonymGroupId: groupId,
    ));
    return true;
  }

  /// Called when a mother tile is popped. Bursts up to 3 synonym
  /// balloons outward (roughly -30°/0°/+30°) from the mother's position,
  /// coloured like the mother. If the word has no synonyms in the data,
  /// the group is already "resolved" — spawn the next mother immediately.
  void _burstSynonyms(WordTile mother) {
    final wordData =
        _wordPool.firstWhere((w) => w['word'] == mother.word, orElse: () => {});
    final synonyms = wordData.isNotEmpty
        ? List<String>.from(wordData['synonyms'] ?? [])
        : <String>[];
    synonyms.shuffle(_random);
    final count = min(3, synonyms.length);
    final groupId = mother.synonymGroupId!;

    if (count == 0) {
      if (_spawnMother()) _motherSpawnedForGroup.add(groupId);
      return;
    }

    final pattern = _burstPattern(count, mother.x);

    for (int i = 0; i < count; i++) {
      final dx = pattern[i][0];
      final dy = pattern[i][1];
      tiles.add(WordTile(
        word: synonyms[i],
        x: mother.x.clamp(10.0, _screenWidth - 120.0),
        y: mother.y,
        balloonColor: mother.balloonColor,
        isPower: true, // golden glow, same as before
        isMother: false,
        synonymGroupId: groupId,
        originalWord: mother.word,
        burstStartX: mother.x,
        burstTargetOffsetX: dx,
        burstStartY: mother.y,
        burstTargetOffsetY: dy,
        burstTicksRemaining: _burstTotalTicks,
      ));
    }
  }

  /// Decides where each synonym balloon ends up, adapting to how close
  /// the mother was to a screen edge when it popped:
  /// - Room on BOTH sides → full spread: left / dip-down middle / right
  ///   (or left/right for 2 synonyms), sides pushed out near the true
  ///   screen edges.
  /// - NOT enough room on one side (mother popped near an edge, so the
  ///   usual spread would clamp multiple balloons into the same corner)
  ///   → one balloon stays roughly at the mother's spot, one dips way
  ///   down, and one shifts to whichever side actually has room. Keeps
  ///   them visually separated instead of bunching up.
  /// Returns one [dx, dy] pair per synonym — dy positive = further down.
  List<List<double>> _burstPattern(int count, double motherX) {
    if (count == 1)
      return [
        [0.0, 0.0]
      ];

    // Sides pushed almost to the screen edges; the per-tick x-clamp in
    // _tick() (10 → screenWidth-120) is the real safety net, so we can
    // push this close to the full width without worrying about overflow.
    final maxSpread = _screenWidth * 0.48;
    // Deep vertical dip — a large chunk of the screen height, not a
    // small "pop". Clamped so it never dips below the miss-line area.
    final dipDepth = (_screenHeight * 0.32).clamp(180.0, 420.0);

    final leftRoom = motherX - 10.0;
    final rightRoom = (_screenWidth - 120.0) - motherX;
    final hasRoomBothSides = leftRoom >= maxSpread && rightRoom >= maxSpread;
    final side = rightRoom >= leftRoom ? 1.0 : -1.0;
    final edgeSpread =
        (leftRoom > rightRoom ? leftRoom : rightRoom).clamp(0.0, maxSpread);

    if (count == 2) {
      if (hasRoomBothSides) {
        return [
          [-maxSpread, 0.0],
          [maxSpread, 0.0],
        ];
      }
      return [
        [0.0, 0.0], // stays near mother's spot
        [side * edgeSpread, 0.0], // shifts to the side with room
      ];
    }

    // count == 3
    if (hasRoomBothSides) {
      return [
        [-maxSpread, 0.0], // left, pushed to the edge, level
        [0.0, dipDepth], // middle, dips way down
        [maxSpread, 0.0], // right, pushed to the edge, level
      ];
    }
    return [
      [0.0, 0.0], // stays at mother's spot
      [0.0, dipDepth], // dips way down
      [side * edgeSpread, 0.0], // shifts to the open side
    ];
  }

  /// Once a group's active (non-popping) synonym count drops to ≤1,
  /// spawns the next mother — as long as no mother is currently active.
  void _checkGroupSpawns() {
    if (_hasMotherOnScreen || !gameActive) return;

    final groupIds = tiles
        .where((t) => t.synonymGroupId != null && !t.isMother)
        .map((t) => t.synonymGroupId!)
        .toSet();

    for (final gid in groupIds) {
      if (_motherSpawnedForGroup.contains(gid)) continue;
      final activeInGroup = tiles
          .where((t) => t.synonymGroupId == gid && !t.isMother && !t.isPopping)
          .length;
      if (activeInGroup <= 1) {
        if (_spawnMother()) _motherSpawnedForGroup.add(gid);
        return;
      }
    }
  }

  void _checkWord() {
    final typed = _controller.text.toLowerCase().trim();
    if (typed.isEmpty) return;

    final match = tiles.where((t) => t.word == typed && !t.isPopping).toList();

    if (match.isNotEmpty) {
      final tile = match.first;
      _spawnParticles(tile.x + 45, tile.y + 50, tile.balloonColor);
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      // Synonym tiles carry the synonym text in `word` (needed for typing
      // match), but the notebook should show the real dictionary word —
      // so look up / save using originalWord when this is a synonym.
      final trackWord = tile.originalWord ?? tile.word;
      final wordData =
          _wordPool.firstWhere((w) => w['word'] == trackWord, orElse: () => {});
      _trackSessionWord(
        word: trackWord,
        meaning: wordData['meaning'] as String?,
        pronunciation: wordData['pronunciation'] as String?,
        exampleSentence: wordData['example_sentence'] as String?,
        topicId: wordData['topic_id'] as int?,
        status: tile.isPower ? 'synonym' : 'popped',
      );

      setState(() {
        tile.isPopping = true;
        score += tile.isPower ? typed.length * level * 3 : typed.length * level;
        _correctWords++;
        _maybeLevelUp();
        _controller.clear();

        if (_synonymsActive) {
          if (tile.isMother) {
            _burstSynonyms(tile);
          }
          // synonym popped → group resolution checked every tick
        } else {
          _doSpawnWord();
        }
      });

      Future.delayed(const Duration(milliseconds: 400),
          () => setState(() => tiles.remove(tile)));
    }
  }

  void _onSubmitted(String value) {
    final typed = value.toLowerCase().trim();

    // সবসময় focus রাখো — keyboard কখনো নামবে না
    _inputFocus.requestFocus();

    if (typed.isEmpty) return;

    final match = tiles.where((t) => t.word == typed && !t.isPopping).toList();

    if (match.isEmpty) {
      // ভুল word — red flash + clear, keyboard নামবে না
      _totalAttempts++;
      HapticFeedback.lightImpact();
      setState(() {
        _flashRed = true;
        _controller.clear();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _flashRed = false);
      });
    }
    // সঠিক হলে _checkWord() already handle করেছে onChanged এ
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
    _countdownTimer?.cancel();

    await SupabaseService.saveScore(
        score: score,
        accuracy: _accuracy,
        wpm: _wpm,
        timePlayed: _sessionStopwatch.elapsed.inSeconds);

    try {
      if (_sessionWords.isNotEmpty) {
        await SupabaseService.saveSessionWords(_sessionWords);
      }
    } catch (_) {}

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
    _rainController.dispose();
    _levelTextController.dispose();
    _controller.dispose();
    _inputFocus.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Free Play mode-এ quit করলে stats save করে result screen-এ যাবে
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
            // Free Play: "Finish" → result screen; অন্যরা: "Quit" → home
            if (widget.isFreePlay)
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Finish & See Results',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold)),
              )
            else
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
        _countdownTimer?.cancel();
        if (!mounted) return false;

        if (widget.isFreePlay) {
          // Free Play: result screen-এ যাও
          await _endGame();
        } else {
          // Survival / Time Attack: home-এ যাও
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
    // keyboard height: keyboard খোলা থাকলে viewInsets.bottom > 0
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // false রাখতে হবে যাতে Stack layout ঠিক থাকে,
        // কিন্তু input field keyboard-aware করব manually
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
                        Text('Score: $score   •   Lv $level',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
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
                          if (widget.usesLives)
                            Text('❤️' * lives + '🖤' * (3 - lives),
                                style: const TextStyle(fontSize: 16))
                          else if (widget.isTimeAttack)
                            Text('⏱️ ${_secondsLeft}s',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _secondsLeft <= 10
                                        ? Colors.redAccent
                                        : Colors.white))
                          else
                            // Free Play badge
                            const Text('🎮 Free Play',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70)),
                          const SizedBox(width: 4),
                          // Free Play: quit button স্পষ্ট করে দেখাও
                          if (widget.isFreePlay)
                            TextButton.icon(
                              onPressed: () async => await _onWillPop(),
                              icon: const Icon(Icons.stop_circle_outlined,
                                  color: Colors.greenAccent, size: 18),
                              label: const Text('Finish',
                                  style: TextStyle(
                                      color: Colors.greenAccent, fontSize: 13)),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 0)),
                            )
                          else
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

                  // Game area — keyboard height বাদ দিয়ে বাকি জায়গা নেবে
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
                                                  color:
                                                      p.color.withOpacity(0.6),
                                                  blurRadius: 4)
                                            ])),
                              ),
                            )),
                        ...tiles.map((tile) => Positioned(
                            left: tile.x,
                            top: tile.y,
                            child: _buildBalloon(tile))),
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
                                            ? '🟢 Word Pop'
                                            : '🔴 Synonym Pop',
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

                  // Input field — keyboard খোলা থাকলে keyboard-এর ওপরে বসে,
                  // না থাকলে স্ক্রিনের একদম নিচে থাকে।
                  // AnimatedPadding দিয়ে smooth transition দাও।
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      isKeyboardOpen
                          ? keyboardHeight + 8 // keyboard-এর ঠিক ওপরে
                          : 12, // স্ক্রিনের নিচে
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocus,
                      enabled: gameActive,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Type here...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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

            // ─── Golden Balloon Rain overlay ───────────────────────────────
            if (_rainActive)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rainController,
                  builder: (context, _) {
                    final t = _rainController.value;
                    final globalOpacity = t < 0.12
                        ? (t / 0.12).clamp(0.0, 1.0)
                        : t > 0.85
                            ? ((1.0 - t) / 0.15).clamp(0.0, 1.0)
                            : 1.0;

                    return Stack(
                      children: [
                        Container(
                          color: Colors.amber.withOpacity(0.07 * globalOpacity),
                        ),
                        ..._rainBalloons.map((b) {
                          final span = (1.0 - b.delay).clamp(0.0001, 1.0);
                          final localT = ((t - b.delay) / span).clamp(0.0, 1.0);
                          final y = -b.size * 1.4 +
                              localT * (_screenHeight + b.size * 2);
                          final wobbleX =
                              b.x + sin(t * 5.5 + b.wobblePhase) * b.wobble;
                          final balloonOpacity =
                              (globalOpacity * (0.75 + 0.25 * localT))
                                  .clamp(0.0, 1.0);

                          return Positioned(
                            left: wobbleX,
                            top: y,
                            child: Opacity(
                              opacity: balloonOpacity,
                              child: CustomPaint(
                                size: Size(b.size, b.size * 1.35),
                                painter: BalloonPainter(
                                  color: Colors.amber,
                                  isActive: false,
                                  isPower: true,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),

            // ─── "LEVEL UP" bounce banner ──────────────────────────────────
            if (_rainActive)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rainController,
                  builder: (context, _) {
                    final t = _rainController.value;
                    final textOpacity = t < 0.08
                        ? (t / 0.08).clamp(0.0, 1.0)
                        : t > 0.45
                            ? ((0.6 - t) / 0.15).clamp(0.0, 1.0)
                            : 1.0;
                    final rawScale = t < 0.08
                        ? (t / 0.08)
                        : t < 0.18
                            ? 1.0 + 0.15 * sin((t - 0.08) / 0.1 * pi)
                            : 1.0;
                    final scale = rawScale.clamp(0.0, 1.3);

                    return Center(
                      child: Opacity(
                        opacity: textOpacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.7),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🎉 LEVEL UP!',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 8,
                                          color: Colors.black45,
                                          offset: Offset(1, 2))
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Level $level',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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

class _RainBalloon {
  final double x, size, delay, wobble, wobblePhase;
  _RainBalloon({
    required this.x,
    required this.size,
    required this.delay,
    required this.wobble,
    required this.wobblePhase,
  });
}
