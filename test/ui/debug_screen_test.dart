import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/debug_screen.dart';

/// Fake clock plus an in-memory database, so no test touches the disk.
late FakeNotifier _notifier;

List<Override> _overrides(FakeClock clock) {
  _notifier = FakeNotifier();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return [
    clockProvider.overrideWithValue(clock),
    databaseProvider.overrideWithValue(db),
    notifierProvider.overrideWithValue(_notifier),
  ];
}

void main() {
  _storedTownTest();
  _notificationTests();
  _worldStatsTest();
  _sliderTests();
  _elapsedTests();
  _simulatorWiringTest();

  testWidgets('shows title, wall and uptime, and refreshes each second', (
    tester,
  ) async {
    final clock = FakeClock();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(clock),
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
    overrides: _overrides(FakeClock()),
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

void _elapsedTests() {
  testWidgets('shows elapsed since start and no tampering', (tester) async {
    final clock = FakeClock();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(clock),
        child: const MaterialApp(home: DebugScreen()),
      ),
    );
    expect(find.text('Elapsed since start: 00:00'), findsOneWidget);

    clock.advance(const Duration(seconds: 90));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Elapsed since start: 01:30'), findsOneWidget);
    expect(find.text('Clock tampered: no'), findsOneWidget);
  });

  testWidgets('flags wall clock jump, elapsed unchanged', (tester) async {
    final clock = FakeClock();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(clock),
        child: const MaterialApp(home: DebugScreen()),
      ),
    );
    clock.advance(const Duration(seconds: 90));
    clock.setWall(clock.nowWall().add(const Duration(hours: 3)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Elapsed since start: 01:30'), findsOneWidget);
    expect(find.text('Clock tampered: yes'), findsOneWidget);
  });
}

void _simulatorWiringTest() {
  testWidgets('the controller panel starts a session with the slider minutes', (
    tester,
  ) async {
    await _pump(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.ensureVisible(find.text('Start'));
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Planned: 25 min'), findsOneWidget);
  });
}

void _storedTownTest() {
  testWidgets('stored town card shows the seeded town', (tester) async {
    await _pump(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.ensureVisible(find.text('Stored town'));
    expect(find.text('Stored town'), findsOneWidget);
    expect(find.text('Stored workers: 3'), findsOneWidget);
    expect(find.text('Stored plots unlocked: 6'), findsOneWidget);
    expect(find.text('Stored XP: 0'), findsOneWidget);
    expect(find.text('Stored streak: 0'), findsOneWidget);
    expect(find.text('Stored buildings: 1'), findsOneWidget);
  });
}

void _notificationTests() {
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('permission starts denied and a request grants it', (
    tester,
  ) async {
    await _pump(tester);
    await settle(tester);
    await tester.ensureVisible(find.text('Notifications: denied'));
    expect(find.text('Notifications: denied'), findsOneWidget);

    await tester.tap(find.text('Request notification permission'));
    await settle(tester);
    expect(_notifier.calls, ['requestPermission']);
    expect(find.text('Notifications: granted'), findsOneWidget);
  });
}

void _worldStatsTest() {
  testWidgets('the debug screen shows the world stats card', (tester) async {
    await _pump(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.ensureVisible(find.textContaining('World:'));
    expect(find.textContaining(' blocks, '), findsOneWidget);
    expect(find.textContaining('house complete plot 0:'), findsOneWidget);
  });
}
