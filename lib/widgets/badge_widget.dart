import 'package:flutter/material.dart';

class BadgeTier {
  final String name;
  final String emoji;
  final Color color;
  const BadgeTier(this.name, this.emoji, this.color);
}

// ─── থ্রেশহোল্ড এখানে বদলাতে পারবেন (highscore ভিত্তিক) ───
const List<int> badgeThresholds = [500, 1000, 2000];

const List<BadgeTier> badgeTiers = [
  BadgeTier('Bronze', '🥉', Color(0xFFCD7F32)),
  BadgeTier('Silver', '🥈', Color(0xFFC0C0C0)),
  BadgeTier('Gold', '🥇', Color(0xFFFFD700)),
  BadgeTier('Platinum', '💎', Color(0xFF9D5CF6)),
];

BadgeTier getBadgeForScore(int highscore) {
  if (highscore >= badgeThresholds[2]) return badgeTiers[3];
  if (highscore >= badgeThresholds[1]) return badgeTiers[2];
  if (highscore >= badgeThresholds[0]) return badgeTiers[1];
  return badgeTiers[0];
}

class BadgeCorner extends StatelessWidget {
  final int highscore;
  const BadgeCorner({super.key, required this.highscore});

  @override
  Widget build(BuildContext context) {
    final tier = getBadgeForScore(highscore);
    return Positioned(
      top: 12,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tier.color, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: tier.color.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tier.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(tier.name,
                style: TextStyle(
                    color: tier.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

