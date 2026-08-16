import 'package:flutter/material.dart';

class WordTile {
  String word;
  double x, y;
  bool isActive, isPower, isPopping;
  Color balloonColor;

  // --- Synonym Pop (mother/burst) mode fields ---

  /// True if this tile is a "mother" balloon — popping it triggers a
  /// burst of up to 3 synonym balloons.
  bool isMother;

  /// Links a mother tile and the synonyms it burst into. Null outside
  /// synonym-pop mode. Used to know when a group is "mostly resolved"
  /// (popped or missed) so the next mother can spawn.
  String? synonymGroupId;

  /// For synonym tiles only: the mother's original word (e.g. "marinate"
  /// while [word] holds the synonym text like "steep"). [word] still
  /// drives typing/matching — this is only used when saving to the
  /// notebook, so the notebook shows the real word and its real
  /// meaning/pronunciation/example instead of a blank synonym entry.
  String? originalWord;

  /// Mother's x at the moment of burst — the horizontal animation
  /// interpolates from here toward [burstStartX] + [burstTargetOffsetX].
  double burstStartX;

  /// Final horizontal offset (px) from [burstStartX] this synonym settles
  /// at once the burst finishes — fixed per-slot so the 3 synonyms always
  /// end up spaced apart, never overlapping.
  double burstTargetOffsetX;

  /// Vertical burst-impulse velocity (px/tick), decays via friction each
  /// tick. Only the vertical "pop" is physics-based; horizontal is eased
  /// toward [burstTargetOffsetX] for guaranteed spacing.
  double vy;

  /// Ticks left in the outward burst animation. Once 0, the tile floats
  /// up normally like any other balloon.
  int burstTicksRemaining;

  WordTile({
    required this.word,
    required this.x,
    required this.y,
    this.isActive = false,
    this.isPower = false,
    this.isPopping = false,
    required this.balloonColor,
    this.isMother = false,
    this.synonymGroupId,
    this.originalWord,
    this.burstStartX = 0,
    this.burstTargetOffsetX = 0,
    this.vy = 0,
    this.burstTicksRemaining = 0,
  });
}
