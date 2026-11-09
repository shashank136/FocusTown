import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/ui/session_simulator_panel.dart';

Future<void> _pump(WidgetTester tester, {int minutes = 10}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionSimulatorPanel(minutes: minutes),
          ),
        ),
      ),
    );

bool _startEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
        .onPressed !=
    null;

Future<void> _failSession(WidgetTester tester) async {
  await _tap(tester, 'Start');
  await _tap(tester, 'Leave');
  await _tap(tester, 'Return after 90s');
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('Start makes a running session', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Progress: 0%'), findsOneWidget);
    expect(find.text('Outcome: -'), findsOneWidget);
  });

  testWidgets('Leave then Return after 5s keeps running, no pass', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Leave');
    expect(find.text('State: away'), findsOneWidget);
    await _tap(tester, 'Return after 5s');
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Pass used: false'), findsOneWidget);
  });

  testWidgets('Leave then Return after 30s uses the pass', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Leave');
    await _tap(tester, 'Return after 30s');
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Pass used: true'), findsOneWidget);
  });

  testWidgets('Leave then Return after 90s fails leftTooLong', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Leave');
    await _tap(tester, 'Return after 90s');
    expect(find.text('State: failed'), findsOneWidget);
    expect(find.text('Outcome: leftTooLong'), findsOneWidget);
  });

  testWidgets('+1 min ten times completes a 10 minute session', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    for (var i = 0; i < 10; i++) {
      await _tap(tester, '+1 min');
    }
    expect(find.text('State: completed'), findsOneWidget);
    expect(find.text('Progress: 100%'), findsOneWidget);
    expect(find.text('Outcome: completed'), findsOneWidget);
  });

  testWidgets('Lock for 5 minutes does not change the state', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Lock');
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Progress: 50%'), findsOneWidget);
  });

  testWidgets('Abandon fails abandoned', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Abandon');
    expect(find.text('State: failed'), findsOneWidget);
    expect(find.text('Outcome: abandoned'), findsOneWidget);
  });

  group('town', () {
    testWidgets('initial town: 3 workers, 1/6 plots, empty queue', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Workers: 3'), findsOneWidget);
      expect(find.text('Plots: 1/6'), findsOneWidget);
      expect(find.text('Queue: 0'), findsOneWidget);
      expect(find.text('Recovery: false'), findsOneWidget);
      expect(find.text('house complete plot 0'), findsOneWidget);
    });

    testWidgets('completing a 10 minute hut: 4 workers, 2 buildings', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, 'Start');
      for (var i = 0; i < 10; i++) {
        await _tap(tester, '+1 min');
      }
      expect(find.text('Workers: 4'), findsOneWidget);
      expect(find.text('Plots: 2/6'), findsOneWidget);
      expect(find.text('hut complete plot 1'), findsOneWidget);
    });

    testWidgets('extra taps after completion do not apply it twice', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, 'Start');
      for (var i = 0; i < 12; i++) {
        await _tap(tester, '+1 min');
      }
      expect(find.text('Workers: 4'), findsOneWidget);
      expect(find.text('Plots: 2/6'), findsOneWidget);
    });

    testWidgets('failing a 25 minute house: 1 worker and a ruin', (
      tester,
    ) async {
      await _pump(tester, minutes: 25);
      await _failSession(tester);
      expect(find.text('Workers: 1'), findsOneWidget);
      expect(find.text('house ruin plot 1'), findsOneWidget);
    });

    testWidgets('castle at 3 workers: Start disabled with the reason', (
      tester,
    ) async {
      await _pump(tester, minutes: 95);
      expect(_startEnabled(tester), isFalse);
      expect(find.text('Needs 8 workers, you have 3'), findsOneWidget);
    });

    testWidgets('losing all workers enters recovery: huts only', (
      tester,
    ) async {
      await _pump(tester, minutes: 25);
      await _failSession(tester); // 3 -> 1 worker
      await _pump(tester);
      await _failSession(tester); // hut risks 1 -> 0 workers
      expect(find.text('Workers: 0'), findsOneWidget);
      expect(find.text('Recovery: true'), findsOneWidget);
      expect(_startEnabled(tester), isTrue);

      await _pump(tester, minutes: 20);
      expect(_startEnabled(tester), isTrue);
      await _pump(tester, minutes: 25);
      expect(_startEnabled(tester), isFalse);
      expect(find.text('Recovery mode: huts only'), findsOneWidget);
    });

    testWidgets('a recovery hut that fails costs no workers', (tester) async {
      await _pump(tester, minutes: 25);
      await _failSession(tester);
      await _pump(tester);
      await _failSession(tester);
      await _failSession(tester); // recovery hut, 0 assigned
      expect(find.text('Workers: 0'), findsOneWidget);
    });
  });
}
