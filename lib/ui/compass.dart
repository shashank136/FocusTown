import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focus_town/game/world/view_rotation.dart';

/// A small compass: a needle that points to where north lies on the screen,
/// with an N at its tip, for the view [rotation].
class Compass extends StatelessWidget {
  /// Creates the compass.
  const new({required this.rotation, super.key});

  /// The view the island is seen from.
  final ViewRotation rotation;

  /// The angle of the needle, clockwise from straight up, for [rotation].
  static double angleFor(ViewRotation rotation) {
    final (dx, dy) = rotation.northOnScreen;
    return math.atan2(dx, -dy);
  }

  @override
  Widget build(BuildContext context) {
    final angle = angleFor(rotation);
    return Semantics(
      label: 'Compass, looking from the ${rotation.facing}',
      excludeSemantics: true,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: angle,
              child: const Icon(Icons.navigation, size: 20, color: Colors.red),
            ),
            Align(
              alignment: Alignment(
                math.sin(angle) * 0.8,
                -math.cos(angle) * 0.8,
              ),
              child: const Text(
                'N',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
