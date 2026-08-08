import 'dart:math';
import 'package:flutter/material.dart';
import '../models/topic.dart';

/// A single decorative emoji placed in the background pattern.
class _Motif {
  final String emoji;
  final double left; // 0..1 fraction of width
  final double top; // 0..1 fraction of height
  final double size;
  final double opacity;
  final double angle;

  _Motif({
    required this.emoji,
    required this.left,
    required this.top,
    required this.size,
    required this.opacity,
    required this.angle,
  });
}

/// Renders a background gradient blended from the given topics, with a
/// scattered low-opacity emoji motif pattern layered on top. The pattern is
/// generated once (seeded by the topic ids) so it stays stable across the
/// rapid setState() calls the game loop triggers.
class TopicBackground extends StatelessWidget {
  final List<Topic> topics;
  final List<_Motif>? _cachedMotifs;

  TopicBackground({super.key, required this.topics})
      : _cachedMotifs = _buildMotifs(topics);

  static List<_Motif> _buildMotifs(List<Topic> topics) {
    if (topics.isEmpty) return [];
    final seed = topics.fold<int>(0, (acc, t) => acc + t.id * 97);
    final rnd = Random(seed);
    final motifs = <_Motif>[];
    const perTopic = 6;
    for (final topic in topics) {
      for (int i = 0; i < perTopic; i++) {
        motifs.add(_Motif(
          emoji: topic.emoji,
          left: rnd.nextDouble(),
          top: rnd.nextDouble(),
          size: 28 + rnd.nextDouble() * 34,
          opacity: 0.05 + rnd.nextDouble() * 0.08,
          angle: (rnd.nextDouble() - 0.5) * 0.8,
        ));
      }
    }
    motifs.shuffle(rnd);
    return motifs;
  }

  /// Blended gradient: each selected topic contributes a translucent color
  /// stop, fading into the app's base dark color at the bottom.
  LinearGradient get _gradient {
    const base = Color(0xFF0A0A14);
    if (topics.length <= 1) {
      final c = topics.isNotEmpty ? topics.first.bgColor : base;
      return LinearGradient(
        colors: [c.withOpacity(0.22), base],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    final colors = <Color>[
      for (final t in topics) t.bgColor.withOpacity(0.20),
      base,
    ];
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(gradient: _gradient)),
            ...?_cachedMotifs?.map((m) => Positioned(
                  left: m.left * w,
                  top: m.top * h,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: m.opacity,
                      child: Transform.rotate(
                        angle: m.angle,
                        child:
                            Text(m.emoji, style: TextStyle(fontSize: m.size)),
                      ),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

