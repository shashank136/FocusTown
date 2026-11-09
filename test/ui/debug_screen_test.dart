import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/ui/debug_screen.dart';

void main() {
  testWidgets('shows title, wall and uptime, and refreshes each second', (
    tester,
  ) async {
    final clock = FakeClock();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWithValue(clock)],
        child: const MaterialApp(home: DebugScreen()),
      ),
    );

    expect(find.text('Focus Town debug'), findsOneWidget);
    expect(find.textContaining('Wall:'), findsOneWidget);
    expect(find.text('Uptime: 0:00:00'), findsOneWidget);

    clock.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Uptime: 0:00:05'), findsOneWidget);
  });
}
