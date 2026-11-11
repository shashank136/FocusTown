// Writes the app icon and launch images. Run it, then review the pictures:
//   flutter test tool/generate_icon_test.dart
// It draws the house with the town's own painter; no extra package.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/render/tier_preview.dart';

const _sky = Color(0xFF8CC9EA);

/// The house picture, transparent around it, filling 80% of [size].
Future<Image> _house(int size) =>
    renderTierPreview(BuildingTier.house, size: size);

/// [source] scaled to [size], optionally on the sky and shrunk by [fill].
Future<Uint8List> _png(
  Image source,
  int size, {
  bool sky = false,
  double fill = 1,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  if (sky) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = _sky,
    );
  }
  final w = size * fill;
  final off = (size - w) / 2;
  canvas.drawImageRect(
    source,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(off, off, w, w),
    Paint()..filterQuality = FilterQuality.high,
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void _write(String path, Uint8List bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

void main() {
  testWidgets('writes the icons', (tester) async {
    await tester.runAsync(() async {
      final big = await _house(1024);

      // iOS: opaque, square, the house a little smaller than the preview.
      const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final names = Directory(ios)
          .listSync()
          .map((f) => f.path.split('/').last)
          .where((n) => n.startsWith('Icon-App-'));
      for (final n in names) {
        final m = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x').firstMatch(n);
        final px = m == null
            ? 1024
            : (double.parse(m[1]!) * int.parse(m[2]!)).round();
        _write('$ios/$n', await _png(big, px, sky: true, fill: 1.15));
      }

      // Android: legacy icons and the adaptive foreground (central 66%).
      const densities = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final e in densities.entries) {
        _write(
          'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
          await _png(big, e.value, sky: true, fill: 1.15),
        );
      }
      _write(
        'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
        await _png(big, 432, fill: 0.66 / 0.8),
      );

      // Launch images: just the house, the sky comes from the background.
      const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
      _write('$launch/LaunchImage.png', await _png(big, 120));
      _write('$launch/LaunchImage@2x.png', await _png(big, 240));
      _write('$launch/LaunchImage@3x.png', await _png(big, 360));
      _write(
        'android/app/src/main/res/drawable-nodpi/launch_image.png',
        await _png(big, 288),
      );
    });
  });
}
