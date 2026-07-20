import 'package:flutter/material.dart';
import 'banner_widget.dart';
import 'gradient_button.dart';

class OtpCard extends StatelessWidget {
  final TextEditingController otpController;
  final String pendingEmail;
  final String error;
  final bool loading;
  final VoidCallback onVerify;
  final VoidCallback onBack;

  static const _surface = Color(0xFF12121F);
  static const _card = Color(0xFF1A1A2E);
  static const _border = Color(0xFF2A2A45);
  static const _purple = Color(0xFF7C3AED);
  static const _accent = Color(0xFFC084FC);
  static const _textPrimary = Color(0xFFF1F0FF);
  static const _textSecondary = Color(0xFF8B8BAD);

  const OtpCard({
    super.key,
    required this.otpController,
    required this.pendingEmail,
    required this.error,
    required this.loading,
    required this.onVerify,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 32,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.mark_email_read_outlined, color: _accent, size: 48),
        const SizedBox(height: 12),
        const Text('Verify Your Email',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('We sent an OTP to\n$pendingEmail',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
              color: _textPrimary,
              fontSize: 28,
              letterSpacing: 10,
              fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: const TextStyle(color: _textSecondary, letterSpacing: 8),
            counterText: '',
            filled: true,
            fillColor: _card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 1.5)),
          ),
        ),
        const SizedBox(height: 8),
        if (error.isNotEmpty)
          BannerWidget(
            message: error,
            icon: Icons.warning_amber_rounded,
            bgColor: Colors.redAccent.withOpacity(0.10),
            borderColor: Colors.redAccent.withOpacity(0.35),
            textColor: const Color(0xFFFF8A8A),
          ),
        const SizedBox(height: 16),
        GradientButton(
            label: 'Verify OTP ✓', onPressed: onVerify, loading: loading),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onBack,
          child:
              const Text('← Back to Login', style: TextStyle(color: _accent)),
        ),
      ]),
    );
  }
}
