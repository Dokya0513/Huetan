import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The box-and-flashcards mark: cards (blue/pink/green) piling into an open
/// box, representing the growing word collection.
class AppIcon extends StatelessWidget {
  final double size;
  const AppIcon({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo/icon.svg',
      width: size,
      height: size,
    );
  }
}

/// "ふえ" in plain text next to "たん" styled as a dog-eared flashcard —
/// solid pink fill, white text, folded top-right corner.
class AppWordmark extends StatelessWidget {
  final double fontSize;
  const AppWordmark({super.key, this.fontSize = 30});

  @override
  Widget build(BuildContext context) {
    final cardFontSize = fontSize;
    final foldSize = fontSize * 0.33;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ふえ',
          style: TextStyle(
            fontFamily: 'Zen Maru Gothic',
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            color: const Color(0xFF1C1917),
          ),
        ),
        const SizedBox(width: 4),
        Stack(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.33,
                vertical: fontSize * 0.1,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFDB2777),
                borderRadius: BorderRadius.circular(fontSize * 0.2),
              ),
              child: Text(
                'たん',
                style: TextStyle(
                  fontFamily: 'Zen Maru Gothic',
                  fontWeight: FontWeight.w700,
                  fontSize: cardFontSize,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: CustomPaint(
                size: Size(foldSize, foldSize),
                painter: _CornerFoldPainter(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CornerFoldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Icon-left, wordmark-right lockup used on the splash screen.
class AppLogoHorizontal extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  const AppLogoHorizontal({super.key, this.iconSize = 56, this.fontSize = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(size: iconSize),
        const SizedBox(width: 12),
        AppWordmark(fontSize: fontSize),
      ],
    );
  }
}

/// Small icon + plain title text, for use as an AppBar title.
class AppTitleRow extends StatelessWidget {
  final String title;
  const AppTitleRow({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(size: 24),
        const SizedBox(width: 8),
        Text(title),
      ],
    );
  }
}

/// Icon-above, wordmark-below lockup for larger presentation contexts.
class AppLogoVertical extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  const AppLogoVertical({super.key, this.iconSize = 72, this.fontSize = 26});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(size: iconSize),
        const SizedBox(height: 14),
        AppWordmark(fontSize: fontSize),
      ],
    );
  }
}
