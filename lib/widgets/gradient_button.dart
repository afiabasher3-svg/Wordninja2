import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool loading;

  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFF9D5CF6);
  static const _card = Color(0xFF1A1A2E);

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: loading
              ? null
              : const LinearGradient(
                  colors: [_purple, Color(0xFF9D3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          color: loading ? _card : null,
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                      color: _purple.withOpacity(0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13))),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: _purpleLight, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4)),
        ),
      ),
    );
  }
}
