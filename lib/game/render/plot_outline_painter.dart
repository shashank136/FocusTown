import 'dart:ui';

import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
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
  Footprint selectedFootprint = Footprint.one,
  List<Parcel> parcels = const [],
  ViewRotation rotation = ViewRotation.none,
  double spin = 0,
  Vec2 pivot = const Vec2(0, 0),
}) {
  Path diamond(Plot p, [Footprint f = Footprint.one]) {
    // The plot's rectangle as it lies in the current view.
    final (vx, vy, w, d) = rotation.rect(
      p.originX,
      p.originY,
      kPlotSize * f.cols,
      kPlotSize * f.rows,
    );
    Offset at(int dx, int dy) {
      final turned = turnAbout(
        (vx + dx).toDouble(),
        (vy + dy).toDouble(),
        pivot,
        spin,
      );
      final v = project(turned.x, turned.y, 1, tile, origin);
      return Offset(v.x, v.y);
    }

    return Path()
      ..moveTo(at(0, 0).dx, at(0, 0).dy)
      ..lineTo(at(w, 0).dx, at(w, 0).dy)
      ..lineTo(at(w, d).dx, at(w, d).dy)
      ..lineTo(at(0, d).dx, at(0, d).dy)
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
    final path = diamond(plotFor(selected, parcels), selectedFootprint);
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

/// Lights up the [parcels] (the row a district is about to build) on the
/// ground: a gold fill and outline over each square, seen from [rotation].
void paintRowHighlight(
  Canvas canvas,
  List<Parcel> parcels, {
  required double tile,
  required Vec2 origin,
  ViewRotation rotation = ViewRotation.none,
  double spin = 0,
  Vec2 pivot = const Vec2(0, 0),
}) {
  final fill = Paint()..color = const Color(0x77FFD54F);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFFFFB300);
  for (final p in parcels) {
    final (vx, vy, _, _) = rotation.rect(
      parcelOrigin(p.gx),
      parcelOrigin(p.gy),
      kPlotSize,
      kPlotSize,
    );
    Offset at(int dx, int dy) {
      final turned = turnAbout(
        (vx + dx).toDouble(),
        (vy + dy).toDouble(),
        pivot,
        spin,
      );
      final v = project(turned.x, turned.y, 1, tile, origin);
      return Offset(v.x, v.y);
    }

    final path = Path()
      ..moveTo(at(0, 0).dx, at(0, 0).dy)
      ..lineTo(at(kPlotSize, 0).dx, at(kPlotSize, 0).dy)
      ..lineTo(at(kPlotSize, kPlotSize).dx, at(kPlotSize, kPlotSize).dy)
      ..lineTo(at(0, kPlotSize).dx, at(0, kPlotSize).dy)
      ..close();
    canvas
      ..drawPath(path, fill)
      ..drawPath(path, stroke);
  }
}
