import 'dart:ui';

import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

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
}) {
  Path diamond(Plot p, [int span = 1]) {
    final side = kPlotSize * span;
    Offset at(int dx, int dy) {
      final v = project(
        (p.originX + dx).toDouble(),
        (p.originY + dy).toDouble(),
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
