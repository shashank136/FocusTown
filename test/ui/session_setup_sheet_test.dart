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
import 'package:focus_town/data/save_failed_exception.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
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

class _NeverSaves extends TownRepository {
  // ignore: use_super_parameters, super params are private so names differ
  new(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<void> saveSessionStarted(TownState town, Session session) =>
      Future.error(const SaveFailedException());
}

Future<ProviderContainer> _open(
  WidgetTester tester, {
  TownState? seed,
  int? lastDuration,
  TownRepository Function(AppDatabase, Clock)? repo,
  Landmark? landmark,
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
        if (repo != null)
          townRepositoryProvider.overrideWithValue(repo(_db, _clock)),
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
                  builder: (_) => SessionSetupSheet(landmark: landmark),
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

  testWidgets('shows both looks of the tier and builds the chosen one', (
    tester,
  ) async {
    final c = await _open(tester);
    expect(find.text('House'), findsOneWidget);
    expect(find.text('Townhouse'), findsOneWidget);
    await tester.tap(find.text('Townhouse'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await _settle(tester);
    expect(c.read(focusControllerProvider).requireValue.active!.look, 1);
  });

  testWidgets('the classic look is the default', (tester) async {
    final c = await _open(tester);
    await tester.tap(find.text('Start'));
    await _settle(tester);
    expect(c.read(focusControllerProvider).requireValue.active!.look, 0);
  });

  testWidgets('the looks follow the tier: a castle or a pyramid', (
    tester,
  ) async {
    await _open(tester, seed: TownState.initial().copyWith(workers: 8));
    _jumpTo(tester, 95);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Castle'), findsOneWidget);
    expect(find.text('Pyramid'), findsOneWidget);
    expect(find.text('Townhouse'), findsNothing);
  });

  testWidgets('Choose plot… keeps the chosen look', (tester) async {
    final c = await _open(tester);
    await tester.tap(find.text('Townhouse'));
    await tester.pump();
    await tester.tap(find.text('Choose plot…'));
    await _settle(tester);
    expect(c.read(placementProvider)!.look, 1);
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

  testWidgets('a picture of each look of the selected tier is shown', (
    tester,
  ) async {
    await _open(tester);
    await _settle(tester);
    await _settle(tester);
    expect(find.byType(RawImage), findsNWidgets(2));
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

  testWidgets('Make garden… starts choosing a forest square', (tester) async {
    final c = await _open(tester);
    await tester.tap(find.text('Make garden…'));
    await _settle(tester);
    final placement = c.read(placementProvider)!;
    expect(placement.garden, isTrue);
    expect(placement.land, isFalse);
    expect(placement.minutes, 15);
  });

  testWidgets('Extend land… starts choosing land', (tester) async {
    final c = await _open(tester);
    await tester.tap(find.text('Extend land…'));
    await _settle(tester);
    final placement = c.read(placementProvider)!;
    expect(placement.land, isTrue);
    expect(placement.minutes, 25);
    expect(find.byType(SessionSetupSheet), findsNothing);
  });

  testWidgets('a full town with no ruins does not mention ruins', (
    tester,
  ) async {
    final full = TownState.initial().copyWith(
      buildings: [
        for (var i = 0; i < 64; i++)
          TownBuilding(
            id: 'b$i',
            tier: BuildingTier.hut,
            status: BuildingStatus.complete,
            plotIndex: i,
          ),
      ],
    );
    await _open(tester, seed: full);
    expect(find.textContaining('Every plot is used.'), findsOneWidget);
    expect(find.textContaining('ruin'), findsNothing);
    expect(find.textContaining('Extend land to add some'), findsOneWidget);
  });

  testWidgets('a castle says it needs a free 2 x 2 block', (tester) async {
    // A hut on every other plot: free plots, but no free block.
    final town = TownState.initial().copyWith(
      workers: 8,
      buildings: [
        for (var gx = 0; gx < 8; gx++)
          for (var gy = 0; gy < 8; gy++)
            if ((gx + gy).isEven)
              TownBuilding(
                id: 'b$gx$gy',
                tier: BuildingTier.hut,
                status: BuildingStatus.complete,
                plotIndex: plotAtCell(gx, gy, const [])!,
              ),
      ],
    );
    await _open(tester, seed: town, lastDuration: 120);
    expect(find.textContaining('no free 2 x 2 block'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Choose plot…'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a full town explains why Choose plot… is off', (tester) async {
    final full = TownState.initial().copyWith(
      buildings: [
        for (var i = 0; i < 64; i++)
          TownBuilding(
            id: 'b$i',
            tier: BuildingTier.hut,
            status: i == 0 ? BuildingStatus.complete : BuildingStatus.ruin,
            plotIndex: i,
          ),
      ],
    );
    await _open(tester, seed: full);
    expect(
      find.text(
        'Every plot is used. A finished build waits until there is room. Tap '
        'Extend land to add some, or tap a ruin to repair it.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Choose plot…'),
    );
    expect(button.onPressed, isNull);
    expect(_start(tester).onPressed, isNotNull);
  });

  testWidgets('a town with room shows no such message', (tester) async {
    await _open(tester);
    expect(find.textContaining('plots are used'), findsNothing);
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

  testWidgets('a save failure shows its message and keeps the sheet', (
    tester,
  ) async {
    await _open(tester, repo: _NeverSaves.new);
    await tester.tap(find.text('Start'));
    await _settle(tester);
    expect(find.text("Couldn't save your session. Try again."), findsOneWidget);
    expect(find.byType(SessionSetupSheet), findsOneWidget);
  });

  group('semantics', () {
    testWidgets('a dial row reads minutes, building and why not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      expect(find.bySemanticsLabel('25 minutes, house'), findsOneWidget);
      _jumpTo(tester, 95);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.bySemanticsLabel(
          '95 minutes, castle, Needs 8 workers, you have 3',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('every button on the sheet has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      for (final b in [
        find.widgetWithText(FilledButton, 'Start'),
        find.widgetWithText(TextButton, 'Choose plot…'),
      ]) {
        expect(tester.getSemantics(b).label, isNotEmpty);
      }
      handle.dispose();
    });
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

    testWidgets('only the previous and next rows show, faded', (tester) async {
      await _open(tester);
      final wheel = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView),
      );
      // Three rows tall: the centre row plus one faded row each side.
      expect(tester.getSize(find.byType(ListWheelScrollView)).height, 112);
      expect(wheel.overAndUnderCenterOpacity, lessThanOrEqualTo(0.4));
    });
  });

  group('landmarks', () {
    TownState village() => TownState.initial().copyWith(xp: 300);

    testWidgets('the wheel time can go into a landmark, in whole stages', (
      tester,
    ) async {
      final c = await _open(tester, seed: village(), lastDuration: 60);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eiffel Tower'));
      await tester.pump();
      expect(find.text('Adds 3 stages'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await _settle(tester);
      final s = c.read(focusControllerProvider).requireValue.active!;
      expect(s.landmark, Landmark.eiffel);
      expect(s.plannedMinutes, 60);
    });

    testWidgets('minutes that are not a whole stage carry over, and say so', (
      tester,
    ) async {
      await _open(tester, seed: village(), lastDuration: 25);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eiffel Tower'));
      await tester.pump();
      expect(find.text('Adds 1 stage and 5 min toward the next'), findsOne);
      _jumpTo(tester, 10);
      await tester.pump();
      expect(find.text('Adds 10 min toward the next stage'), findsOne);
    });

    testWidgets('opened for a landmark it starts on that landmark', (
      tester,
    ) async {
      final c = await _open(
        tester,
        seed: village(),
        lastDuration: 40,
        landmark: Landmark.lighthouse,
      );
      expect(find.text('Adds 2 stages and 10 min toward the next'), findsOne);
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await _settle(tester);
      expect(
        c.read(focusControllerProvider).requireValue.active!.landmark,
        Landmark.lighthouse,
      );
    });

    testWidgets('a landmark not started yet can have its place chosen', (
      tester,
    ) async {
      final c = await _open(tester, seed: village(), lastDuration: 60);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eiffel Tower'));
      await tester.pump();
      await tester.tap(find.text('Choose plot…'));
      await _settle(tester);
      final p = c.read(placementProvider)!;
      expect(p.landmark, Landmark.eiffel);
      expect(p.minutes, 60);
    });

    testWidgets('a landmark already started stays where it is', (tester) async {
      const eiffel = TownBuilding(
        id: 'landmark-eiffel',
        tier: BuildingTier.castle,
        status: BuildingStatus.building,
        plotIndex: 0,
        landmark: Landmark.eiffel,
        progress: 40,
      );
      final seed = village().copyWith(
        buildings: [...village().buildings, eiffel],
      );
      await _open(tester, seed: seed);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eiffel Tower'));
      await tester.pump();
      expect(find.text('Choose plot…'), findsNothing);
    });

    testWidgets('every unlocked landmark is a choice, new building first', (
      tester,
    ) async {
      await _open(tester, seed: village());
      final ready = Landmark.values.where((l) => l.unlockLevel.minXp <= 300);
      expect(find.byType(ChoiceChip), findsNWidgets(ready.length + 1));
      expect(find.widgetWithText(ChoiceChip, 'New building'), findsOneWidget);
      // The default is still a normal building.
      expect(find.text('house'), findsOneWidget);
    });

    testWidgets('with one landmark in progress, only it is offered', (
      tester,
    ) async {
      const eiffel = TownBuilding(
        id: 'landmark-eiffel',
        tier: BuildingTier.castle,
        status: BuildingStatus.building,
        plotIndex: 0,
        landmark: Landmark.eiffel,
        progress: 40,
      );
      final seed = village().copyWith(
        buildings: [...village().buildings, eiffel],
      );
      await _open(tester, seed: seed);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.widgetWithText(ChoiceChip, 'Eiffel Tower'), findsOneWidget);
    });

    testWidgets('with no landmark unlocked there is no choice to make', (
      tester,
    ) async {
      await _open(tester);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('expand island', () {
    TownState city({
      List<DistrictSide> done = const [],
      DistrictProject? project,
    }) => TownState.initial().copyWith(
      xp: 6000,
      districts: done,
      districtProject: project,
    );

    testWidgets('it is a choice from City on, not before', (tester) async {
      await _open(tester, seed: TownState.initial().copyWith(xp: 1500));
      expect(find.widgetWithText(ChoiceChip, 'Expand island'), findsNothing);
    });

    testWidgets('choosing it offers the four sides and the time', (
      tester,
    ) async {
      await _open(tester, seed: city());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expand island'));
      _jumpTo(tester, 120);
      await tester.pump();
      for (final side in ['North', 'East', 'South', 'West']) {
        expect(find.widgetWithText(ChoiceChip, side), findsOneWidget);
      }
      expect(find.text('Adds 2 rows'), findsOneWidget);
      expect(find.text('Choose plot…'), findsNothing);
    });

    testWidgets('the time makes whole rows, the leftover carries', (
      tester,
    ) async {
      await _open(tester, seed: city());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expand island'));
      _jumpTo(tester, 90);
      await tester.pump();
      expect(find.text('Adds 1 row and 30 min toward the next'), findsOne);
      _jumpTo(tester, 30);
      await tester.pump();
      expect(find.text('Adds 30 min toward the next row'), findsOne);
    });

    testWidgets('starting it builds on the chosen side', (tester) async {
      final c = await _open(tester, seed: city());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expand island'));
      _jumpTo(tester, 120);
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'West'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Start'));
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await _settle(tester);
      final s = c.read(focusControllerProvider).requireValue.active!;
      expect(s.district, DistrictSide.west);
      expect(s.plannedMinutes, 120);
    });

    testWidgets('a district being built is the only side offered', (
      tester,
    ) async {
      await _open(
        tester,
        seed: city(project: const DistrictProject(DistrictSide.south, 130)),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expand island'));
      await tester.pump();
      expect(find.widgetWithText(ChoiceChip, 'South'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'North'), findsNothing);
      expect(find.text('2 of 8 rows built'), findsOneWidget);
    });

    testWidgets('a side with no room left is not offered', (tester) async {
      await _open(tester, seed: city(done: [DistrictSide.east]));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expand island'));
      await tester.pump();
      expect(find.widgetWithText(ChoiceChip, 'East'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'West'), findsOneWidget);
    });

    testWidgets('three districts is the most: no choice any more', (
      tester,
    ) async {
      await _open(
        tester,
        seed: city(
          done: [DistrictSide.east, DistrictSide.west, DistrictSide.north],
        ),
      );
      expect(find.widgetWithText(ChoiceChip, 'Expand island'), findsNothing);
    });
  });
}
