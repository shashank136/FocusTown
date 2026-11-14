import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/session_panel.dart';

late AppDatabase _db;
late FakeClock _clock;

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

/// Pumps the panel with [priorSessions] finished sessions already stored and a
/// running session of [minutes].
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  int minutes = 25,
  int priorSessions = 0,
  TownState? town,
}) async {
  _clock = FakeClock();
  _db = AppDatabase(NativeDatabase.memory());
  addTearDown(_db.close);
  if (town != null) {
    await _db.transaction(() async {
      await _db
          .into(_db.towns)
          .insert(
            townToRow(town)
                .copyWith(id: const Value(1), createdAt: const Value(0)),
          );
      await _db.batch(
        (b) => b.insertAll(
          _db.buildings,
          buildingsToRows(town, now: _clock.nowWall()),
        ),
      );
    });
  }
  for (var i = 0; i < priorSessions; i++) {
    await _db
        .into(_db.sessions)
        .insert(
          sessionToRow(
            Session(
              id: 'old$i',
              plannedMinutes: 10,
              tier: BuildingTier.hut,
              workersAssigned: 1,
              state: SessionState.completed,
              startedAt: TimeStamp(DateTime(2020), Duration.zero),
            ),
          ),
        );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(_db),
        notifierProvider.overrideWithValue(FakeNotifier()),
      ],
      child: const MaterialApp(home: Scaffold(body: SessionPanel())),
    ),
  );
  final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  await tester.runAsync(() => c.read(focusControllerProvider.future));
  await tester.runAsync(
    () => c.read(focusControllerProvider.notifier).start(minutes),
  );
  await _settle(tester); // builds the panel, which starts the count
  await _settle(tester);
  return c;
}

Future<void> _elapse(WidgetTester tester, Duration d) async {
  _clock.advance(d);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('nothing is shown without a session', (tester) async {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(_clock),
          databaseProvider.overrideWithValue(_db),
          notifierProvider.overrideWithValue(FakeNotifier()),
        ],
        child: const MaterialApp(home: Scaffold(body: SessionPanel())),
      ),
    );
    await _settle(tester);
    expect(find.text('Abandon'), findsNothing);
  });

  testWidgets('shows the full time at the start, and the tier', (tester) async {
    await _pump(tester);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('house'), findsOneWidget);
  });

  testWidgets('counts down: 5 minutes in shows 20:00', (tester) async {
    await _pump(tester);
    await _elapse(tester, const Duration(minutes: 5));
    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('ends at 00:00 and never goes below', (tester) async {
    await _pump(tester);
    await _elapse(tester, const Duration(minutes: 40));
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('a session over an hour shows hours', (tester) async {
    await _pump(
      tester,
      minutes: 65,
      town: TownState.initial().copyWith(workers: 10),
    );
    expect(find.text('1:05:00'), findsOneWidget);
  });

  testWidgets('the progress bar follows the clock', (tester) async {
    await _pump(tester);
    await _elapse(tester, const Duration(minutes: 5));
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.2, 0.001));
  });

  for (final (prior, shown) in [(0, true), (2, true), (3, false)]) {
    testWidgets('with $prior earlier sessions the hint is '
        '${shown ? 'shown' : 'hidden'}', (tester) async {
      await _pump(tester, priorSessions: prior);
      expect(
        find.text('Lock your phone and put it face down.'),
        shown ? findsOneWidget : findsNothing,
      );
    });
  }

  group('Abandon', () {
    testWidgets('asks first, naming the 2 builders at risk', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Abandon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Abandon this build?'), findsOneWidget);
      expect(
        find.text('Your 2 builders will stop and the site becomes a ruin.'),
        findsOneWidget,
      );
    });

    testWidgets('one builder is singular', (tester) async {
      await _pump(tester, minutes: 10);
      await tester.tap(find.text('Abandon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Your builder will stop and the site becomes a ruin.'),
        findsOneWidget,
      );
    });

    testWidgets('no builders at risk says only the site is lost', (
      tester,
    ) async {
      await _pump(
        tester,
        minutes: 10,
        town: TownState.initial().copyWith(workers: 0, inRecoveryMode: true),
      );
      await tester.tap(find.text('Abandon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('The site becomes a ruin.'), findsOneWidget);
    });

    testWidgets('Keep focusing leaves the session running', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.text('Abandon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Keep focusing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.read(focusControllerProvider).requireValue.active, isNotNull);
      expect(find.text('Abandon this build?'), findsNothing);
    });

    testWidgets('confirming abandons: a failed result', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.text('Abandon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, 'Abandon').last);
      await _settle(tester);
      final focus = c.read(focusControllerProvider).requireValue;
      expect(focus.active, isNull);
      expect(focus.lastResult!.outcome.name, 'failed');
    });
  });

  group('emergency pause', () {
    testWidgets('a button arms it and says what it does', (tester) async {
      final c = await _pump(tester);
      expect(find.text('Emergency pause'), findsOneWidget);
      await tester.tap(find.text('Emergency pause'));
      await _settle(tester);
      expect(find.text('Emergency pause'), findsNothing);
      expect(
        find.text('Emergency pause on: you may be away up to 10 minutes.'),
        findsOneWidget,
      );
      expect(
        c.read(focusControllerProvider).requireValue.active!.emergencyArmed,
        isTrue,
      );
    });

    testWidgets('with none left it is off and says when the next comes', (
      tester,
    ) async {
      await _pump(
        tester,
        town: TownState.initial().copyWith(
          emergencyPauses: 0,
          emergencyWeek: const LocalDate(2025, 12, 29),
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Emergency pause'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Next pause on Mon 5 Jan'), findsOneWidget);
    });

    testWidgets('the label says what is being done, not "hut"', (tester) async {
      final c = await _pump(
        tester,
        town: TownState.initial().copyWith(xp: 300),
      );
      await tester.runAsync(() async {
        final n = c.read(focusControllerProvider.notifier);
        await n.abandon();
        _clock.advance(const Duration(minutes: 1));
        await n.startLand(const Parcel(5, 5, garden: true));
      });
      await _settle(tester);
      expect(find.text('Making a garden'), findsOneWidget);
      expect(find.text('hut'), findsNothing);
      await tester.runAsync(() async {
        final n = c.read(focusControllerProvider.notifier);
        await n.abandon();
        _clock.advance(const Duration(minutes: 1));
        await n.startRepair(1);
      });
      await _settle(tester);
      expect(find.text('Repairing a ruin'), findsOneWidget);
      expect(find.text('hut'), findsNothing);
      await tester.runAsync(() async {
        final n = c.read(focusControllerProvider.notifier);
        await n.abandon();
        _clock.advance(const Duration(minutes: 1));
        await n.startLandmark(Landmark.eiffel, 30);
      });
      await _settle(tester);
      expect(find.text('Building the Eiffel Tower'), findsOneWidget);
      expect(find.text('Emergency pause'), findsNothing);
    });

    testWidgets('a district session says it grows the island, no pause', (
      tester,
    ) async {
      final c = await _pump(
        tester,
        town: TownState.initial().copyWith(xp: 6000),
      );
      await tester.runAsync(() async {
        final n = c.read(focusControllerProvider.notifier);
        await n.abandon();
        _clock.advance(const Duration(minutes: 1));
        await n.startDistrict(DistrictSide.east, 60);
      });
      await _settle(tester);
      expect(find.text('Growing the island'), findsOneWidget);
      expect(find.text('hut'), findsNothing);
      expect(find.text('Emergency pause'), findsNothing);
    });

    testWidgets('a garden session has no pause button', (tester) async {
      final c = await _pump(tester);
      await tester.runAsync(() async {
        final n = c.read(focusControllerProvider.notifier);
        await n.abandon();
        _clock.advance(const Duration(minutes: 1));
        await n.startLand(const Parcel(5, 5, garden: true));
      });
      await _settle(tester);
      expect(find.text('Emergency pause'), findsNothing);
    });

    testWidgets('a repair has no pause button', (tester) async {
      final c = await _pump(tester);
      await tester.runAsync(() async {
        final n = c.read(focusControllerProvider.notifier);
        await n.abandon();
        _clock.advance(const Duration(minutes: 1));
        await n.startRepair(1);
      });
      await _settle(tester);
      expect(find.text('Emergency pause'), findsNothing);
    });
  });
}
