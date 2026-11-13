import 'dart:ui';

import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/view_rotation.dart';

/// Outlines each plot in [free] on the ground; the [selected] plot is also
/// filled green.
void paintPlotOutlines(
  Canvas canvas,
  Set<int> free,
  int? selected, {
  required double tile,
  required Vec2 origin,
  int selectedSpan = 1,
  List<Parcel> parcels = const [],
  ViewRotation rotation = ViewRotation.none,
}) {
  Path diamond(Plot p, [int span = 1]) {
    final side = kPlotSize * span;
    // The plot's square as it lies in the current view.
    final (vx, vy, _, _) = rotation.rect(p.originX, p.originY, side, side);
    Offset at(int dx, int dy) {
      final v = project(
        (vx + dx).toDouble(),
        (vy + dy).toDouble(),
        1,
        tile,
        origin,
      );
      return Offset(v.x, v.y);
    }

    return Path()
      ..moveTo(at(0, 0).dx, at(0, 0).dy)
      ..lineTo(at(side, 0).dx, at(side, 0).dy)
      ..lineTo(at(side, side).dx, at(side, side).dy)
      ..lineTo(at(0, side).dx, at(0, side).dy)
      ..close();
  }

  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xCCFFFFFF);
  for (final i in free) {
    canvas.drawPath(diamond(plotFor(i, parcels)), stroke);
  }
  if (selected != null) {
    final path = diamond(plotFor(selected, parcels), selectedSpan);
    canvas
      ..drawPath(path, Paint()..color = const Color(0x6643A047))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF2E7D32),
      );
  }
}
