import 'package:flutter/material.dart';

class WordTile {
  String word;
  double x, y;
  bool isActive, isPower, isPopping;
  Color balloonColor;

  WordTile({
    required this.word,
    required this.x,
    required this.y,
    this.isActive = false,
    this.isPower = false,
    this.isPopping = false,
    required this.balloonColor,
  });
}
