import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/render/plot_outline_painter.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/view_rotation.dart';

const _size = 400;

// The alpha of the pixel at [at] after [draw] painted on a clear canvas.
Future<int> _alphaAt(void Function(ui.Canvas canvas) draw, Vec2 at) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(_size, _size);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  return bytes[((at.y.round() * _size) + at.x.round()) * 4 + 3];
}

void main() {
  final row = districtRow(DistrictSide.east, 0, 0);
  // Tile size 2, so the whole row of 8 parcels (7 x 56 tiles) fits on screen.
  const tile = 2.0;

  // The screen origin that puts the middle of the row at the screen centre in
  // view [r].
  Vec2 originFor(ViewRotation r) {
    final mid = row[row.length ~/ 2];
    final (x, y) = r.point(
      parcelOrigin(mid.gx) + kPlotSize / 2,
      parcelOrigin(mid.gy) + kPlotSize / 2,
    );
    final at = project(x, y, 1, tile, const Vec2(0, 0));
    return Vec2(_size / 2 - at.x, _size / 2 - at.y);
  }

  Vec2 centerOf(int gx, int gy, ViewRotation r) {
    final (x, y) = r.point(
      parcelOrigin(gx) + kPlotSize / 2,
      parcelOrigin(gy) + kPlotSize / 2,
    );
    return project(x, y, 1, tile, originFor(r));
  }

  testWidgets('the row about to be built is painted, nothing else is', (
    tester,
  ) async {
    await tester.runAsync(() async {
      void draw(ui.Canvas c, ViewRotation r) => paintRowHighlight(
        c,
        row,
        tile: tile,
        origin: originFor(r),
        rotation: r,
      );
      for (var k = 0; k < 4; k++) {
        final r = ViewRotation(k);
        for (final p in [row.first, row[3], row.last]) {
          final at = centerOf(p.gx, p.gy, r);
          expect(
            await _alphaAt((c) => draw(c, r), at),
            greaterThan(0),
            reason: 'turn $k parcel ${p.gx},${p.gy}',
          );
        }
        // A parcel of another row is not painted.
        final away = centerOf(10, 0, r);
        expect(await _alphaAt((c) => draw(c, r), away), 0, reason: 'turn $k');
      }
    });
  });

  test('the renderer keeps the row to highlight, and clears it', () {
    final r = TownRenderer()..setTown(TownState.initial());
    expect(r.rowHighlight, isEmpty);
    r.setRowHighlight(row);
    expect(r.rowHighlight, row);
    r.setRowHighlight(const []);
    expect(r.rowHighlight, isEmpty);
  });
}
