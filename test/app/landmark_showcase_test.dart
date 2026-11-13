import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/landmark_showcase.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/debug_screen.dart';

void main() {
  testWidgets('the debug screen has the switch', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FakeClock()),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(FakeNotifier()),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: DebugScreen()),
      ),
    );
    await tester.pump();
    final finder = find.text('Show every landmark on the map');
    await tester.scrollUntilVisible(finder, 200);
    await tester.tap(finder);
    await tester.pump();
    expect(c.read(landmarkShowcaseProvider), isTrue);
  });
}
