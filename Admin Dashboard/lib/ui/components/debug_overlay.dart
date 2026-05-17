import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// Displays an optional overlay on top of the current page that helps
/// engineers verify spacing and alignment. The overlay draws an 8px
/// baseline grid and highlights the bounding boxes of widgets when
/// hovered over on web. This overlay is controlled via the [enabled]
/// property and should only be active during development.
class DebugOverlay extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const DebugOverlay({Key? key, required this.enabled, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Draw vertical lines every 8px
    for (double x = 0; x <= size.width; x += AppSpacing.sm) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Draw horizontal lines every 8px
    for (double y = 0; y <= size.height; y += AppSpacing.sm) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}