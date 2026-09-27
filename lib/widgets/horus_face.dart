import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/horus_controller.dart';
import '../theme.dart';

/// Horus's animated face: a glowing orb with eyes that blink, a mouth that
/// moves while he speaks, and rings that react to the visitor's voice.
class HorusFace extends StatefulWidget {
  const HorusFace({super.key, required this.state, required this.micLevel});

  final HorusState state;
  final ValueListenable<double> micLevel;

  @override
  State<HorusFace> createState() => _HorusFaceState();
}

class _HorusFaceState extends State<HorusFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_clock, widget.micLevel]),
        builder: (context, _) => CustomPaint(
          painter: _FacePainter(
            seconds: _clock.value * 60,
            state: widget.state,
            micLevel: widget.micLevel.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.seconds,
    required this.state,
    required this.micLevel,
  });

  final double seconds;
  final HorusState state;
  final double micLevel;

  Color get _accent => switch (state) {
    HorusState.idle => HorusColors.sky,
    HorusState.connecting => HorusColors.sky,
    HorusState.listening => HorusColors.listening,
    HorusState.thinking => HorusColors.thinking,
    HorusState.speaking => HorusColors.gold,
    HorusState.error => HorusColors.error,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.36;
    final accent = _accent;

    // Breathing / voice-reactive scale.
    final breathe = 1 + 0.02 * math.sin(seconds * 2);
    final voice = state == HorusState.listening ? micLevel * 0.08 : 0.0;
    final talk = state == HorusState.speaking
        ? 0.03 * (math.sin(seconds * 14).abs())
        : 0.0;
    final r = radius * (breathe + voice + talk);

    // Outer glow.
    canvas.drawCircle(
      center,
      r * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.25)),
    );

    // Rings.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (state == HorusState.thinking || state == HorusState.connecting) {
      // Spinning arcs while he thinks.
      for (var i = 0; i < 3; i++) {
        final start = seconds * (2.5 - i * 0.6) + i * 2.1;
        ringPaint
          ..color = accent.withValues(alpha: 0.8 - i * 0.2)
          ..strokeWidth = r * 0.035;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r * (1.08 + i * 0.09)),
          start,
          math.pi * 0.7,
          false,
          ringPaint,
        );
      }
    } else {
      for (var i = 0; i < 3; i++) {
        final phase = (seconds * 0.6 + i / 3) % 1;
        final extra = state == HorusState.listening ? micLevel * 0.25 : 0.0;
        ringPaint
          ..color = accent.withValues(alpha: (1 - phase) * 0.45)
          ..strokeWidth = r * 0.02;
        canvas.drawCircle(center, r * (1.05 + phase * 0.3 + extra), ringPaint);
      }
    }

    // Head.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [HorusColors.navyLight, HorusColors.navy],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = accent,
    );

    _paintEyes(canvas, center, r, accent);
    _paintMouth(canvas, center, r, accent);
  }

  void _paintEyes(Canvas canvas, Offset center, double r, Color accent) {
    // Blink for ~150ms every 4 seconds.
    final blinkPhase = seconds % 4;
    final blink = blinkPhase < 0.15 ? math.sin(blinkPhase / 0.15 * math.pi) : 0;
    final eyeH = r * 0.26 * (1 - blink * 0.9);
    final eyeW = r * 0.2;
    final lookX = state == HorusState.thinking
        ? r * 0.05 * math.sin(seconds * 1.5)
        : 0.0;
    final eyeY = center.dy - r * 0.15;
    final paint = Paint()..color = Colors.white;
    final glow = Paint()
      ..color = accent.withValues(alpha: 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06);

    for (final side in [-1, 1]) {
      final rect = Rect.fromCenter(
        center: Offset(center.dx + side * r * 0.33 + lookX, eyeY),
        width: eyeW,
        height: eyeH,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(eyeW / 2));
      canvas.drawRRect(rrect, glow);
      canvas.drawRRect(rrect, paint);
    }
  }

  void _paintMouth(Canvas canvas, Offset center, double r, Color accent) {
    final mouthY = center.dy + r * 0.38;
    final paint = Paint()
      ..color = accent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.06;

    if (state == HorusState.speaking) {
      // Equalizer-style mouth that moves with speech.
      const bars = 5;
      final spacing = r * 0.11;
      for (var i = 0; i < bars; i++) {
        final x = center.dx + (i - (bars - 1) / 2) * spacing;
        final h =
            r *
            (0.05 +
                0.12 *
                    (0.5 + 0.5 * math.sin(seconds * (11 + i * 2.3) + i * 1.7)) *
                    (1 - (i - 2).abs() * 0.18));
        canvas.drawLine(Offset(x, mouthY - h), Offset(x, mouthY + h), paint);
      }
    } else {
      // Gentle smile.
      final path = Path()
        ..moveTo(center.dx - r * 0.2, mouthY - r * 0.02)
        ..quadraticBezierTo(
          center.dx,
          mouthY + r * (state == HorusState.error ? -0.08 : 0.1),
          center.dx + r * 0.2,
          mouthY - r * 0.02,
        );
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => true;
}
