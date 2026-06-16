import 'package:flutter/material.dart';

/// 안심시그널 마스코트 — 방패 모양 (안전·보호를 상징)
///
/// [color] — 배경에 따라 caller가 지정:
///   - 네이비/어두운 배경(스플래시, 홈 버튼) → Colors.white
///   - 밝은 배경(온보딩, 기타)               → AppTheme.primaryLight
class AnsimMascot extends StatelessWidget {
  final double size;
  final Color color;

  const AnsimMascot({
    super.key,
    this.size = 80,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ShieldPainter(color: color)),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  const _ShieldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    _draw(canvas);
  }

  void _draw(Canvas canvas) {
    // 그림자
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 94), width: 40, height: 8),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );

    // 방패 외곽
    final shieldPath = Path()
      ..moveTo(50, 10)
      ..lineTo(85, 22)
      ..cubicTo(85, 22, 85, 62, 50, 88)
      ..cubicTo(15, 62, 15, 22, 15, 22)
      ..close();

    canvas.drawPath(shieldPath, Paint()..color = color);

    // 방패 안 체크마크
    final checkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(33, 50)
      ..lineTo(45, 63)
      ..lineTo(68, 37);

    canvas.drawPath(checkPath, checkPaint);

    // 광택
    canvas.drawCircle(
      const Offset(36, 28),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter old) => old.color != color;
}
