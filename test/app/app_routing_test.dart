import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/app.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/home_screen.dart';
import 'package:focus_town/ui/onboarding/onboarding_screen.dart';

late AppDatabase _db;
late FakeClock _clock;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<ProviderContainer> _launch(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(_db),
        notifierProvider.overrideWithValue(FakeNotifier()),
      ],
      child: const FocusTownApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(FocusTownApp)));
}

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  testWidgets('a fresh install starts with onboarding', (tester) async {
    await _launch(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('after onboarding the app opens on the town', (tester) async {
    final repo = TownRepository(_db, _clock);
    await tester.runAsync(() async {
      await repo.loadOrCreate();
      await repo.setOnboardingDone();
    });
    await _launch(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('Start on the last page lands on the town with a hut', (
    tester,
  ) async {
    final c = await _launch(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.text('Start'));
    await _settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    final active = c.read(focusControllerProvider).requireValue.active;
    expect(active!.plannedMinutes, 10);
    expect(find.text('Abandon'), findsOneWidget);
  });

  testWidgets('a running session on launch shows the town, no onboarding', (
    tester,
  ) async {
    final repo = TownRepository(_db, _clock);
    await tester.runAsync(() async {
      await repo.loadOrCreate();
      await repo.setOnboardingDone();
    });
    final first = await _launch(tester);
    await tester.runAsync(
      () => first.read(focusControllerProvider.notifier).start(25),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _launch(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Abandon'), findsOneWidget);
  });
}
