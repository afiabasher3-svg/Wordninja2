import 'package:flutter/material.dart';

class BannerWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const BannerWidget({
    super.key,
    required this.message,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: textColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.45)),
        ),
      ]),
    );
  }
}
