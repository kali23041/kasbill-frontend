import 'package:flutter/material.dart';

import '../theme/ratnex_theme.dart';

/// Full-bleed hero + light bottom sheet layout (ElevenLabs-style, light theme).
class AuthLandingShell extends StatelessWidget {
  final Widget bottom;
  final double heroFlex;

  const AuthLandingShell({
    super.key,
    required this.bottom,
    this.heroFlex = 0.42,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroH = size.height * heroFlex;
    const overlap = 28.0;

    return Scaffold(
      backgroundColor: RatnexColors.panel,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroH,
            child: Image.asset(
              'assets/images/auth_hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned(
            top: heroH - overlap,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: RatnexColors.panel,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: bottom,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthBrandBlock extends StatelessWidget {
  final String title;
  final String tagline;
  final String description;

  const AuthBrandBlock({
    super.key,
    required this.title,
    required this.tagline,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: RatnexTheme.brand(size: 36),
        ),
        const SizedBox(height: 10),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: RatnexTheme.label(
            size: 17,
            weight: FontWeight.w700,
            color: RatnexColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.center,
          style: RatnexTheme.label(
            size: 13,
            color: RatnexColors.muted,
          ).copyWith(height: 1.45),
        ),
      ],
    );
  }
}

class AuthPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool filled;
  final bool loading;

  const AuthPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.filled = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? Colors.white : RatnexColors.ink,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  style: RatnexTheme.label(
                    size: 15,
                    weight: FontWeight.w600,
                    color: filled ? Colors.white : RatnexColors.ink,
                  ),
                ),
              ),
            ],
          );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: RatnexColors.ink,
            foregroundColor: Colors.white,
            disabledBackgroundColor: RatnexColors.ink.withValues(alpha: 0.5),
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: RatnexColors.ink,
          side: const BorderSide(color: RatnexColors.ink, width: 1.2),
          shape: const StadiumBorder(),
          backgroundColor: RatnexColors.panel,
        ),
        child: child,
      ),
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthGoogleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          customBorder: const StadiumBorder(),
          child: Ink(
            decoration: BoxDecoration(
              color: RatnexColors.panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: RatnexColors.hairline),
              boxShadow: [
                BoxShadow(
                  color: RatnexColors.ink.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GoogleGMark(size: 20),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: RatnexTheme.label(
                            size: 15,
                            weight: FontWeight.w600,
                            color: RatnexColors.ink,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleGMark extends StatelessWidget {
  final double size;

  const GoogleGMark({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2);
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    sweep.color = const Color(0xFF4285F4);
    canvas.drawArc(inset, -1.85, 1.5, false, sweep);
    sweep.color = const Color(0xFF34A853);
    canvas.drawArc(inset, -0.35, 1.1, false, sweep);
    sweep.color = const Color(0xFFFBBC05);
    canvas.drawArc(inset, 0.75, 0.9, false, sweep);
    sweep.color = const Color(0xFFEA4335);
    canvas.drawArc(inset, 1.65, 1.0, false, sweep);

    final bar = Paint()..color = const Color(0xFF4285F4);
    final cy = size.height / 2;
    canvas.drawRRect(
      RRect.fromLTRBR(
        size.width * 0.45,
        cy - stroke / 2,
        size.width * 0.92,
        cy + stroke / 2,
        Radius.circular(stroke / 2),
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

InputDecoration authFieldDecoration(String label, {Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    labelStyle: RatnexTheme.label(size: 13),
    filled: true,
    fillColor: RatnexColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: RatnexColors.hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: RatnexColors.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: RatnexColors.gold, width: 1.4),
    ),
    suffixIcon: suffix,
  );
}
