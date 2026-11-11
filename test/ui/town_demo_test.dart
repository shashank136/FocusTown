import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/demo/demo_script.dart';
import 'package:focus_town/ui/onboarding/onboarding_screen.dart';
import 'package:focus_town/ui/onboarding/town_demo.dart';

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: SizedBox(width: 300, height: 300, child: child)),
    ),
  ),
);

DemoGame _game(WidgetTester tester) => tester
    .widget<GameWidget<DemoGame>>(find.byType(GameWidget<DemoGame>))
    .game!;

void main() {
  testWidgets('the demo animates while active', (tester) async {
    await _show(tester, const TownDemo(kind: DemoKind.build));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_game(tester).seconds, greaterThan(1));
    expect(_game(tester).renderer.site, isNotNull);
  });

  testWidgets('an inactive demo stands still', (tester) async {
    await _show(tester, const TownDemo(kind: DemoKind.build, active: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_game(tester).seconds, 0);
  });

  testWidgets('reduced motion shows one static final frame', (tester) async {
    await _show(
      tester,
      const TownDemo(kind: DemoKind.build),
      reduceMotion: true,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final g = _game(tester);
    expect(g.seconds, lessThan(kDemoLoop));
    final first = g.seconds;
    await tester.pump(const Duration(seconds: 2));
    expect(g.seconds, first);
  });

  testWidgets('the ruin demo shows a ruin in its second half', (tester) async {
    await _show(tester, const TownDemo(kind: DemoKind.ruin));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(_game(tester).renderer.site, isNull);
  });

  testWidgets('each onboarding page builds its own demo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onStart: () {})),
    );
    await tester.pump();
    for (final kind in DemoKind.values) {
      expect(
        tester.widget<TownDemo>(find.byType(TownDemo)).kind,
        kind,
      );
      await tester.tap(find.text(kind == DemoKind.start ? 'Start' : 'Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  });
}
