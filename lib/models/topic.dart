import 'package:flutter/material.dart';

class Topic {
  final int id;
  final String name;
  final String emoji;
  final Color bgColor;
  final Color themeColor;

  Topic({
    required this.id,
    required this.name,
    required this.emoji,
    required this.bgColor,
    required this.themeColor,
  });

  static Color hexToColor(String hex) => Color(int.parse('FF$hex', radix: 16));

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as int,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      bgColor: hexToColor(map['bg_color'] as String),
      themeColor: hexToColor(map['theme_color'] as String),
    );
  }
}

