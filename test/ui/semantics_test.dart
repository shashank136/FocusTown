import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/ui/hud.dart';
import 'package:focus_town/ui/onboarding/onboarding_screen.dart';
import 'package:focus_town/ui/session_panel.dart';

class _Seeded extends FocusController {
  new(this._state);
  final FocusState _state;

  @override
  Future<FocusState> build() async => _state;
}

late FakeClock _clock;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required FocusState focus,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(db),
        focusControllerProvider.overrideWith(() => _Seeded(focus)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Session _session() => Session(
  id: 's',
  plannedMinutes: 25,
  tier: BuildingTier.house,
  workersAssigned: 2,
  state: SessionState.running,
  startedAt: TimeStamp(_clock.nowWall(), _clock.uptime()),
);

void main() {
  setUp(() => _clock = FakeClock());

  group('HUD', () {
    testWidgets('streak, level, workers and plots read aloud', (tester) async {
      final handle = tester.ensureSemantics();
      final today = LocalDate.fromDateTime(_clock.nowWall());
      await _pump(
        tester,
        const Hud(),
        focus: FocusState(
          town: TownState.initial().copyWith(
            streakCount: 4,
            lastStreakDate: today,
            xp: 0,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Streak, 4 days'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Town level, Camp, 0 percent to next level'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Workers, 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Plots, 1 of 6 used'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('one day is singular', (tester) async {
      final handle = tester.ensureSemantics();
      final today = LocalDate.fromDateTime(_clock.nowWall());
      await _pump(
        tester,
        const Hud(),
        focus: FocusState(
          town: TownState.initial().copyWith(
            streakCount: 1,
            lastStreakDate: today,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Streak, 1 day'), findsOneWidget);
      handle.dispose();
    });
  });

  group('session panel', () {
    testWidgets('time left, progress and abandon are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      final session = _session();
      _clock.advance(const Duration(seconds: 90));
      await _pump(
        tester,
        const SessionPanel(),
        focus: FocusState(town: TownState.initial(), active: session),
      );
      expect(
        find.bySemanticsLabel('Time left, 23 minutes 30 seconds'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Build progress, 6 percent'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Abandon build'), findsOneWidget);
      handle.dispose();
    });
  });

  group('onboarding', () {
    testWidgets('the page indicator and the button are labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onStart: () {})),
      );
      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Next'), findsOneWidget);
      handle.dispose();
    });
  });
}
