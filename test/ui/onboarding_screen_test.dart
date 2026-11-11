import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/ui/onboarding/onboarding_screen.dart';

const _titles = [
  'Your town grows while you focus.',
  'Leave the app, and your builders stop.',
  'Start your first build.',
];

Future<void> _open(WidgetTester tester, {VoidCallback? onStart}) =>
    tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onStart: onStart ?? () {})),
    );

int _dot(WidgetTester tester) {
  final active = Theme.of(
    tester.element(find.byType(OnboardingScreen)),
  ).colorScheme.primary;
  for (var i = 0; i < 3; i++) {
    final dot = tester.widget<Container>(find.byKey(ValueKey('page-dot-$i')));
    if ((dot.decoration! as BoxDecoration).color == active) return i;
  }
  return -1;
}

void main() {
  testWidgets('the first page shows its title and Next', (tester) async {
    await _open(tester);
    expect(find.text(_titles[0]), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('Next walks through the titles in order', (tester) async {
    await _open(tester);
    for (var i = 1; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_titles[i]), findsOneWidget);
    }
  });

  testWidgets('the indicator follows the page', (tester) async {
    await _open(tester);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('page-dot-$i')), findsOneWidget);
    }
    expect(_dot(tester), 0);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_dot(tester), 1);
  });

  testWidgets('swiping goes forward and back', (tester) async {
    await _open(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_titles[1]), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_titles[0]), findsOneWidget);
  });

  testWidgets('every page reserves a demo area', (tester) async {
    await _open(tester);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('demo-area-$i')), findsOneWidget);
      await tester.tap(find.text(i < 2 ? 'Next' : 'Start'));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    }
  });

  testWidgets('the last page offers Start and the 10-minute hut', (
    tester,
  ) async {
    var started = 0;
    await _open(tester, onStart: () => started++);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('10-minute hut'), findsOneWidget);
    expect(
      find.text('So we can warn you before your builders stop.'),
      findsOneWidget,
    );
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Start'));
    expect(started, 1);
  });
}
