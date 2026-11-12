import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/hud.dart';
import 'package:focus_town/ui/onboarding/onboarding_screen.dart';
import 'package:focus_town/ui/result_dialogs.dart';
import 'package:focus_town/ui/session_panel.dart';
import 'package:focus_town/ui/session_setup_sheet.dart';
import 'package:focus_town/ui/town_summary.dart';

TownBuilding _b(int i, [BuildingStatus s = BuildingStatus.complete]) =>
    TownBuilding(id: 'b$i', tier: BuildingTier.hut, status: s, plotIndex: i);

class _Seeded extends FocusController {
  new(this._state);
  final FocusState _state;

  @override
  Future<FocusState> build() async => _state;
}

void _bigPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _scaled(Widget child) => MaterialApp(
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: c!,
  ),
  home: Scaffold(body: child),
);

Future<void> _inScope(
  WidgetTester tester,
  Widget child, {
  TownState? town,
  Session? active,
}) async {
  _bigPhone(tester);
  final clock = FakeClock();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(FakeNotifier()),
        focusControllerProvider.overrideWith(
          () => _Seeded(
            FocusState(town: town ?? TownState.initial(), active: active),
          ),
        ),
      ],
      child: _scaled(child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('town summary', () {
    test('the starting town', () {
      expect(
        townSummary(TownState.initial()),
        'Your town has 1 building and 3 workers.',
      );
    });

    test('six buildings and seven workers', () {
      final town = TownState.initial().copyWith(
        workers: 7,
        buildings: [for (var i = 0; i < 6; i++) _b(i)],
      );
      expect(townSummary(town), 'Your town has 6 buildings and 7 workers.');
    });

    test('ruins are counted apart, singular and plural', () {
      final one = TownState.initial().copyWith(
        workers: 1,
        buildings: [_b(0), _b(1, BuildingStatus.ruin)],
      );
      expect(
        townSummary(one),
        'Your town has 1 building and 1 worker, and 1 ruin.',
      );
      final two = one.copyWith(
        buildings: [
          _b(0),
          _b(1, BuildingStatus.ruin),
          _b(2, BuildingStatus.ruin),
        ],
      );
      expect(
        townSummary(two),
        'Your town has 1 building and 1 worker, and 2 ruins.',
      );
    });
  });

  group('text twice as big on a 390 x 844 phone', () {
    testWidgets('the HUD', (tester) async {
      await _inScope(tester, const Hud());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the session panel', (tester) async {
      final s = Session(
        id: 's',
        plannedMinutes: 25,
        tier: BuildingTier.house,
        workersAssigned: 2,
        state: SessionState.running,
        startedAt: TimeStamp(FakeClock().nowWall(), Duration.zero),
      );
      await _inScope(tester, const SessionPanel(), active: s);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the setup sheet, even in recovery mode', (tester) async {
      await _inScope(
        tester,
        const SessionSetupSheet(),
        town: TownState.initial().copyWith(workers: 0, inRecoveryMode: true),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding, last page', (tester) async {
      _bigPhone(tester);
      await tester.pumpWidget(_scaled(OnboardingScreen(onStart: () {})));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    });

    for (final r in <(String, SessionResult)>[
      (
        'completed with everything',
        const SessionResult(
          outcome: SessionOutcome.completed,
          tier: BuildingTier.castle,
          workersLost: 0,
          workersGained: 4,
          newStreak: 12,
          xpGained: 120,
          reason: OutcomeReason.completed,
          leveledUpTo: TownLevel.village,
          recoveryEnded: true,
        ),
      ),
      (
        'failed into recovery',
        const SessionResult(
          outcome: SessionOutcome.failed,
          tier: BuildingTier.house,
          workersLost: 3,
          workersGained: 0,
          newStreak: 0,
          awaySeconds: 90,
          reason: OutcomeReason.leftTooLong,
          recoveryStarted: true,
        ),
      ),
    ]) {
      testWidgets('dialog: ${r.$1}', (tester) async {
        _bigPhone(tester);
        await tester.pumpWidget(
          _scaled(
            Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showResultDialog(context, r.$2, growthTip: true),
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('reduced motion: onboarding changes page at once', (
    tester,
  ) async {
    _bigPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: c!,
        ),
        home: OnboardingScreen(onStart: () {}),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Leave the app, and your builders stop.'), findsOneWidget);
  });
}
