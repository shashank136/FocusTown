import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/ui/session_simulator_panel.dart';

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: SessionSimulatorPanel(minutes: 10)),
    ),
  ),
);

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
}
