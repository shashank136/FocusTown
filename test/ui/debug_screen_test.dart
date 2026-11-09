import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/ui/debug_screen.dart';

void main() {
  _sliderTests();

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

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    overrides: [clockProvider.overrideWithValue(FakeClock())],
    child: const MaterialApp(home: DebugScreen()),
  ),
);

void _sliderTests() {
  testWidgets('defaults to 25 minutes, house, 2 workers at risk', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Minutes: 25'), findsOneWidget);
    expect(find.text('Tier: house'), findsOneWidget);
    expect(find.text('Workers at risk: 2'), findsOneWidget);
  });

  testWidgets('slider minimum is 10 minutes, hut', (tester) async {
    await _pump(tester);
    await tester.drag(find.byType(Slider), const Offset(-2000, 0));
    await tester.pump();
    expect(find.text('Minutes: 10'), findsOneWidget);
    expect(find.text('Tier: hut'), findsOneWidget);
    expect(find.text('Workers at risk: 1'), findsOneWidget);
  });

  testWidgets('slider maximum is 120 minutes, castle', (tester) async {
    await _pump(tester);
    await tester.drag(find.byType(Slider), const Offset(2000, 0));
    await tester.pump();
    expect(find.text('Minutes: 120'), findsOneWidget);
    expect(find.text('Tier: castle'), findsOneWidget);
    expect(find.text('Workers at risk: 8'), findsOneWidget);
  });
}
