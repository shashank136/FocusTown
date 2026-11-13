import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/world/view_rotation.dart';
import 'package:focus_town/ui/compass.dart';

void main() {
  test('north points up and to the right in the first view', () {
    final angle = Compass.angleFor(ViewRotation.none);
    // Clockwise from straight up: between up (0) and right (pi / 2).
    expect(angle, greaterThan(0));
    expect(angle, lessThan(math.pi / 2));
  });

  test('every turn points the needle somewhere else', () {
    final angles = {
      for (var k = 0; k < 4; k++) Compass.angleFor(ViewRotation(k)),
    };
    expect(angles, hasLength(4));
  });

  testWidgets('it draws the needle at that angle and an N', (tester) async {
    const r = ViewRotation(1);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Compass(rotation: r)),
      ),
    );
    expect(find.text('N'), findsOneWidget);
    final turned = tester.widget<Transform>(
      find.descendant(
        of: find.byType(Compass),
        matching: find.byType(Transform),
      ),
    );
    final expected = Matrix4.rotationZ(Compass.angleFor(r));
    expect(turned.transform.storage[0], closeTo(expected.storage[0], 1e-9));
    expect(turned.transform.storage[1], closeTo(expected.storage[1], 1e-9));
  });
}
