import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/session_setup_sheet.dart';

late AppDatabase _db;
late FakeClock _clock;

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<ProviderContainer> _open(
  WidgetTester tester, {
  TownState? seed,
  int? lastDuration,
}) async {
  _clock = FakeClock();
  _db = AppDatabase(NativeDatabase.memory());
  addTearDown(_db.close);
  if (seed != null) {
    await _db.transaction(() async {
      await _db
          .into(_db.towns)
          .insert(
            townToRow(seed).copyWith(
              id: const Value(1),
              createdAt: const Value(0),
              lastDurationMinutes: Value(lastDuration ?? 25),
            ),
          );
      await _db.batch(
        (b) => b.insertAll(
          _db.buildings,
          buildingsToRows(seed, now: _clock.nowWall()),
        ),
      );
    });
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(_db),
        notifierProvider.overrideWithValue(FakeNotifier()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const SessionSetupSheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final c = ProviderScope.containerOf(tester.element(find.text('open')));
  await tester.runAsync(() => c.read(focusControllerProvider.future));
  await tester.tap(find.text('open'));
  await _settle(tester);
  return c;
}

void _jumpTo(WidgetTester tester, int minutes) {
  final wheel = tester.widget<ListWheelScrollView>(
    find.byType(ListWheelScrollView),
  );
  (wheel.controller! as FixedExtentScrollController).jumpToItem(
    (minutes - 10) ~/ 5,
  );
}

FilledButton _start(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'));

TownState _recovery() =>
    TownState.initial().copyWith(workers: 0, inRecoveryMode: true);

void main() {
  testWidgets('opens on 25 minutes: a house, risking 2, gaining 2', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('house'), findsOneWidget);
    expect(find.text('Risks 2 workers'), findsOneWidget);
    expect(find.text('+2 workers if you finish'), findsOneWidget);
  });

  testWidgets('opens on the last used duration', (tester) async {
    await _open(tester, seed: TownState.initial(), lastDuration: 45);
    expect(find.text('workshop'), findsOneWidget);
  });

  testWidgets('a hut risks 1 worker and gains 1', (tester) async {
    await _open(tester);
    _jumpTo(tester, 10);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('hut'), findsOneWidget);
    expect(find.text('Risks 1 worker'), findsOneWidget);
    expect(find.text('+1 worker if you finish'), findsOneWidget);
  });

  testWidgets('a workshop gains nothing, so no gain line', (tester) async {
    await _open(tester);
    _jumpTo(tester, 45);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('workshop'), findsOneWidget);
    expect(find.textContaining('if you finish'), findsNothing);
  });

  testWidgets('a castle with 3 workers says why and disables Start', (
    tester,
  ) async {
    await _open(tester);
    _jumpTo(tester, 95);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Needs 8 workers, you have 3'), findsOneWidget);
    expect(_start(tester).onPressed, isNull);
  });

  testWidgets('recovery mode shows the banner, hides risk, huts only', (
    tester,
  ) async {
    await _open(tester, seed: _recovery());
    expect(find.textContaining('The Last Builder.'), findsOneWidget);
    expect(find.textContaining('Risks'), findsNothing);
    expect(_start(tester).onPressed, isNotNull); // opens on a hut
    _jumpTo(tester, 45);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Recovery mode: huts only'), findsOneWidget);
    expect(_start(tester).onPressed, isNull);
  });

  testWidgets('the picture of the selected tier is shown', (tester) async {
    await _open(tester);
    await _settle(tester);
    await _settle(tester);
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('Start begins the session, saves the duration, closes', (
    tester,
  ) async {
    final c = await _open(tester);
    _jumpTo(tester, 30);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start'));
    await _settle(tester);
    final focus = c.read(focusControllerProvider).requireValue;
    expect(focus.active!.plannedMinutes, 30);
    expect(await c.read(townRepositoryProvider).lastDurationMinutes(), 30);
    expect(find.byType(SessionSetupSheet), findsNothing);
  });

  testWidgets('Choose plot… saves the duration and starts choosing', (
    tester,
  ) async {
    final c = await _open(tester);
    _jumpTo(tester, 20);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Choose plot…'));
    await _settle(tester);
    expect(c.read(placementProvider)!.minutes, 20);
    expect(c.read(focusControllerProvider).requireValue.active, isNull);
    expect(await c.read(townRepositoryProvider).lastDurationMinutes(), 20);
    expect(find.byType(SessionSetupSheet), findsNothing);
  });

  testWidgets('a failing start shows the error and keeps the sheet', (
    tester,
  ) async {
    final c = await _open(tester);
    await tester.runAsync(
      () => c.read(focusControllerProvider.notifier).start(10),
    );
    await tester.tap(find.text('Start'));
    await _settle(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(SessionSetupSheet), findsOneWidget);
  });

  group('the dial feel', () {
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    int ticks() => calls
        .where(
          (c) =>
              c.method == 'HapticFeedback.vibrate' &&
              c.arguments == 'HapticFeedbackType.selectionClick',
        )
        .length;

    int clicks() => calls
        .where(
          (c) =>
              c.method == 'SystemSound.play' &&
              c.arguments == 'SystemSoundType.click',
        )
        .length;

    testWidgets('opening the sheet makes no tick', (tester) async {
      await _open(tester);
      // (Tapping the "open" button itself clicks on Android; start counting
      // from here.)
      calls.clear();
      await tester.pump(const Duration(seconds: 1));
      expect(ticks(), 0);
      expect(clicks(), 0);
    });

    testWidgets('turning the dial ticks and clicks once per step', (
      tester,
    ) async {
      await _open(tester);
      calls.clear();
      // A slow drag that passes several rows (they are 40 px apart).
      await tester.timedDrag(
        find.byType(ListWheelScrollView),
        const Offset(0, -130),
        const Duration(milliseconds: 600),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(ticks(), greaterThanOrEqualTo(3));
      expect(clicks(), ticks());
    });

    testWidgets('the dial looks like a dial: curved and magnified', (
      tester,
    ) async {
      await _open(tester);
      final wheel = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView),
      );
      expect(wheel.useMagnifier, isTrue);
      expect(wheel.diameterRatio, lessThan(2.5));
      expect(wheel.perspective, greaterThan(0.002));
    });
  });
}
