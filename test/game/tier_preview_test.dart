import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/render/tier_preview.dart';

Future<Uint8List> _rgba(WidgetTester t, ui.Image image) async {
  final data = await t.runAsync(image.toByteData);
  return data!.buffer.asUint8List();
}

int _opaque(Uint8List px) {
  var n = 0;
  for (var i = 3; i < px.length; i += 4) {
    if (px[i] > 0) n++;
  }
  return n;
}

void main() {
  for (final tier in BuildingTier.values) {
    testWidgets('${tier.name} preview has the asked size and a building', (
      tester,
    ) async {
      final image = (await tester.runAsync(() => renderTierPreview(tier)))!;
      expect(image.width, 96);
      expect(image.height, 96);
      expect(_opaque(await _rgba(tester, image)), greaterThan(200));
    });
  }

  testWidgets('another size is honored', (tester) async {
    final image = (await tester.runAsync(
      () => renderTierPreview(BuildingTier.hut, size: 48),
    ))!;
    expect(image.width, 48);
    expect(image.height, 48);
  });

  testWidgets('the building fills most of the picture but stays inside', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () => renderTierPreview(BuildingTier.castle),
    ))!;
    final px = await _rgba(tester, image);
    var minX = 96;
    var maxX = -1;
    var maxY = -1;
    for (var y = 0; y < 96; y++) {
      for (var x = 0; x < 96; x++) {
        if (px[(y * 96 + x) * 4 + 3] > 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    expect(maxX - minX + 1, inInclusiveRange(60, 96));
    expect(maxY, lessThan(96));
  });

  testWidgets('tiers share one scale: hut < house, castle biggest', (
    tester,
  ) async {
    final n = <BuildingTier, int>{};
    for (final tier in BuildingTier.values) {
      final image = (await tester.runAsync(() => renderTierPreview(tier)))!;
      n[tier] = _opaque(await _rgba(tester, image));
    }
    expect(n[BuildingTier.hut], lessThan(n[BuildingTier.house]!));
    expect(
      n[BuildingTier.castle],
      greaterThan(n.values.where((v) => v != n[BuildingTier.castle]).reduce(
        (a, b) => a > b ? a : b,
      )),
    );
  });

  testWidgets('a castle does not look like a hut', (tester) async {
    final hut = (await tester.runAsync(
      () => renderTierPreview(BuildingTier.hut),
    ))!;
    final castle = (await tester.runAsync(
      () => renderTierPreview(BuildingTier.castle),
    ))!;
    expect(await _rgba(tester, castle), isNot(await _rgba(tester, hut)));
  });

  testWidgets('golden: all five tiers side by side', (tester) async {
    final images = <ui.Image>[];
    for (final tier in BuildingTier.values) {
      images.add((await tester.runAsync(() => renderTierPreview(tier)))!);
    }
    final strip = await tester.runAsync(() {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xFFCDEAF7), ui.BlendMode.src);
      for (var i = 0; i < images.length; i++) {
        canvas.drawImage(images[i], ui.Offset(i * 96.0, 0), ui.Paint());
      }
      return recorder.endRecording().toImage(96 * images.length, 96);
    });
    await expectLater(strip, matchesGoldenFile('goldens/tier_previews.png'));
  });
}
