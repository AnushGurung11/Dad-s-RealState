import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The LUCKY brand lockup: symbol + wordmark, tinted with the app accent.
/// Used wherever a logo lockup makes sense (splash/loading moment,
/// Settings → About) — never on the launcher icon itself, which stays a
/// symbol only.
class LuckyWordmark extends StatelessWidget {
  const LuckyWordmark({super.key, this.size = 32});

  /// Height of the symbol; the wordmark scales proportionally.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('lucky_wordmark'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _LuckyMarkPainter()),
        ),
        SizedBox(width: size * 0.25),
        Flexible(
          child: Text(
            'Lucky',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size * 0.72,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: appText1,
              fontFamily: null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Vector twin of the launcher icon's mark so the in-app lockup stays crisp
/// at any density.
class _LuckyMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = appAccent;
    final w = size.width;
    final baseline = size.height * 0.92;

    // Ascending bars.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.04, baseline - size.height * 0.30, w * 0.24,
          size.height * 0.30),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, baseline - size.height * 0.46, w * 0.24,
          size.height * 0.46),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.72, baseline - size.height * 0.62, w * 0.24,
          size.height * 0.62),
      paint,
    );

    // Coin above the tallest bar.
    final coinCenter = Offset(w * 0.84, size.height * 0.16);
    canvas.drawCircle(coinCenter, size.height * 0.13, paint);
    final hole = Paint()
      ..color = const Color(0x590F766E)
      ..blendMode = BlendMode.srcOver;
    canvas.drawCircle(coinCenter, size.height * 0.06, hole);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
