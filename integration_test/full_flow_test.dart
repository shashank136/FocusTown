import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/app.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/testing/fake_lifecycle_source.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding, a hut, a lost house, a new day, a second hut', (
    tester,
  ) async {
    final clock = FakeClock();
    final source = FakeLifecycleSource(isNative: true);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          databaseProvider.overrideWithValue(db),
          notifierProvider.overrideWithValue(FakeNotifier()),
          lifecycleSourceProvider.overrideWithValue(source),
        ],
        child: const FocusTownApp(),
      ),
    );

    // The town animates all the time, so pump for set times, not "settle".
    Future<void> wait([Duration d = const Duration(milliseconds: 600)]) async {
      await tester.pump(d);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump(d);
    }

    String hud(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    Future<void> tapText(String text) async {
      await tester.tap(find.text(text));
      await wait();
    }

    // Leave the app for [away] and come back.
    Future<void> leaveFor(Duration away) async {
      source.emit(BackgroundedEvent(TimeStamp.now(clock)));
      clock.advance(away);
      await wait();
      source.emit(ForegroundedEvent(TimeStamp.now(clock)));
      await wait();
    }

    // 1. Onboarding.
    await wait();
    await tapText('Next');
    await tapText('Next');
    await tapText('Start');

    // 2. A 10-minute hut is running.
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('hut'), findsOneWidget);

    // 3. Five seconds away costs nothing.
    await leaveFor(const Duration(seconds: 5));
    expect(find.text('Abandon'), findsOneWidget);
    expect(find.textContaining('built'), findsNothing);

    // 4. The hut completes: streak 1, workers 4, plots 7.
    clock.advance(const Duration(minutes: 10));
    await wait(const Duration(milliseconds: 1500));
    expect(find.text('Hut built'), findsOneWidget);
    await tapText('Continue');
    expect(hud('hud-streak'), '1');
    expect(hud('hud-workers'), '4');
    expect(hud('hud-plots'), '2/7');

    // 5. A 25-minute house, then 90 seconds away: the builders are lost.
    await tapText('Start focus');
    await tapText('Start');
    expect(find.text('25:00'), findsOneWidget);
    await leaveFor(const Duration(seconds: 90));
    await wait(const Duration(milliseconds: 1500));
    expect(find.text('Your builders stopped'), findsOneWidget);
    await tapText('Continue');
    expect(hud('hud-workers'), '2');

    // 6. A day later: a 10-minute hut again.
    clock.advance(const Duration(hours: 24));
    await tapText('Start focus');
    // The wheel opens on 25; its first row is 10 minutes.
    final wheel = tester.widget<ListWheelScrollView>(
      find.byType(ListWheelScrollView),
    );
    (wheel.controller! as FixedExtentScrollController).jumpToItem(0);
    await wait();
    await tapText('Start');
    expect(find.text('10:00'), findsOneWidget);
    clock.advance(const Duration(minutes: 10));
    await wait(const Duration(milliseconds: 1500));
    expect(find.text('Hut built'), findsOneWidget);
    await tapText('Continue');
    expect(hud('hud-streak'), '2');
    // The starter, the first hut, the ruin and the new hut.
    expect(hud('hud-plots'), '4/8');
  });
}
