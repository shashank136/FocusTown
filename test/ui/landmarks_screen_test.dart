import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/landmark_text.dart';
import 'package:focus_town/ui/landmarks_screen.dart';

late AppDatabase _db;
late FakeClock _clock;

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

TownBuilding _lighthouse(int progress, BuildingStatus status) => TownBuilding(
  id: 'landmark-lighthouse',
  tier: BuildingTier.castle,
  status: status,
  plotIndex: plotAtCell(0, 0, const [])!,
  landmark: Landmark.lighthouse,
  progress: progress,
);

Future<ProviderContainer> _open(WidgetTester tester, TownState seed) async {
  // Tall, so the lazy list builds every card (there are several landmarks).
  await tester.binding.setSurfaceSize(const Size(400, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  _clock = FakeClock();
  _db = AppDatabase(NativeDatabase.memory());
  addTearDown(_db.close);
  await _db.transaction(() async {
    await _db
        .into(_db.towns)
        .insert(
          townToRow(seed)
              .copyWith(id: const Value(1), createdAt: const Value(0)),
        );
    await _db.batch(
      (b) => b.insertAll(
        _db.buildings,
        buildingsToRows(seed, now: _clock.nowWall()),
      ),
    );
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(_db),
        notifierProvider.overrideWithValue(FakeNotifier()),
        liveStatusSinkProvider.overrideWithValue(FakeLiveStatusSink()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LandmarksScreen(),
                ),
              ),
              child: const Text('open'),
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

TownState _town({int xp = 300, List<TownBuilding> extra = const []}) =>
    TownState.initial().copyWith(
      xp: xp,
      buildings: [...TownState.initial().buildings, ...extra],
    );

// The card of the landmark titled [title].
Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card));

// How many landmarks are unlocked at 300 minutes of focus.
final int _unlockedAt300 = Landmark.values
    .where((l) => l.unlockLevel.minXp <= 300)
    .length;

void main() {
  testWidgets('a locked landmark says when it unlocks and has no button', (
    tester,
  ) async {
    await _open(tester, _town(xp: 100));
    expect(find.text('Lighthouse of Alexandria'), findsOneWidget);
    expect(
      find.descendant(
        of: _card('Lighthouse of Alexandria'),
        matching: find.text('About 4 hours over many sessions'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Unlocks at Village (300 minutes of focus)'),
      findsNWidgets(
        Landmark.values.where((l) => l.unlockLevel.minXp == 300).length,
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('an unlocked landmark can be started with a chosen length', (
    tester,
  ) async {
    final c = await _open(tester, _town());
    expect(find.text('Not started'), findsNWidgets(_unlockedAt300));
    await tester.tap(
      find.descendant(
        of: _card('Lighthouse of Alexandria'),
        matching: find.widgetWithText(FilledButton, 'Start'),
      ),
    );
    await _settle(tester);
    // The same sheet as the island's, already on this landmark.
    expect(find.text('Adds 1 stage and 5 min toward the next'), findsOne);
    await tester.tap(find.widgetWithText(FilledButton, 'Start').last);
    await _settle(tester);
    final s = c.read(focusControllerProvider).requireValue.active!;
    expect(s.isLandmark, isTrue);
    expect(s.landmark, Landmark.lighthouse);
    expect(s.plannedMinutes, 25);
    // Back on the island, not on the screen.
    await _settle(tester);
    expect(find.byType(LandmarksScreen), findsNothing);
  });

  testWidgets('a landmark in progress shows its stage and can continue', (
    tester,
  ) async {
    await _open(
      tester,
      _town(extra: [_lighthouse(85, BuildingStatus.building)]),
    );
    expect(find.text('Stage 4 of 12 (85 of 240 minutes)'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
  });

  testWidgets('one landmark at a time: the others wait for it', (tester) async {
    await _open(
      tester,
      _town(extra: [_lighthouse(85, BuildingStatus.building)]),
    );
    expect(
      find.text('Finish the Lighthouse of Alexandria first.'),
      findsNWidgets(_unlockedAt300 - 1),
    );
    // Only the landmark in progress has a button.
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('a finished landmark says it is built', (tester) async {
    await _open(
      tester,
      _town(extra: [_lighthouse(240, BuildingStatus.complete)]),
    );
    expect(find.text('Built'), findsOneWidget);
    expect(
      find.descendant(
        of: _card('Lighthouse of Alexandria'),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  testWidgets('with no free area it says what is needed and offers more land', (
    tester,
  ) async {
    final crowded = _town(
      extra: [
        for (var gx = 0; gx < 8; gx++)
          for (var gy = 0; gy < 8; gy++)
            if ((gx + gy).isEven)
              TownBuilding(
                id: 'h$gx$gy',
                tier: BuildingTier.hut,
                status: BuildingStatus.complete,
                plotIndex: plotAtCell(gx, gy, const [])!,
              ),
      ],
    );
    await _open(tester, crowded);
    // A landmark of one plot still finds a free plot between the huts.
    final open = Landmark.values.where(
      (l) => l.unlockLevel.minXp <= 300 && l.footprint.area > 1,
    );
    for (final l in open) {
      expect(
        find.text(noRoomText(l.title, l.footprint)),
        findsOneWidget,
        reason: l.title,
      );
    }
    // No Start or Continue on those, but a way to make room on each of them.
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Expand island'),
      findsNWidgets(open.length),
    );
  });

  testWidgets(
    'the Expand island button opens the sheet on growing the island',
    (tester) async {
      final crowded = _town(
        extra: [
          for (var gx = 0; gx < 8; gx++)
            for (var gy = 0; gy < 8; gy++)
              if ((gx + gy).isEven)
                TownBuilding(
                  id: 'h$gx$gy',
                  tier: BuildingTier.hut,
                  status: BuildingStatus.complete,
                  plotIndex: plotAtCell(gx, gy, const [])!,
                ),
        ],
      );
      await _open(tester, crowded);
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Expand island').first,
      );
      await _settle(tester);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Expand island'),
      );
      expect(chip.selected, isTrue);
    },
  );
}
