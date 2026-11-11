import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/ui/hud.dart';

class _Seeded extends FocusController {
  new(this._state);
  final FocusState _state;

  @override
  Future<FocusState> build() async => _state;
}

Future<FakeClock> _pump(WidgetTester tester, TownState town) async {
  final clock = FakeClock();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(clock),
        focusControllerProvider.overrideWith(
          () => _Seeded(FocusState(town: town)),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: Hud())),
    ),
  );
  await tester.pump();
  return clock;
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

double _bar(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byKey(const ValueKey('hud-bar')))
    .value!;

void main() {
  testWidgets('the starting town: streak 0, Camp, 3 workers, 1/6 plots', (
    tester,
  ) async {
    await _pump(tester, TownState.initial());
    expect(_text(tester, 'hud-streak'), '0');
    expect(_text(tester, 'hud-level'), 'Camp');
    expect(_text(tester, 'hud-workers'), '3');
    expect(_text(tester, 'hud-plots'), '1/6');
    expect(find.byKey(const ValueKey('hud-queue')), findsNothing);
  });

  testWidgets('a streak kept today shows its count', (tester) async {
    final clock = FakeClock();
    final today = LocalDate.fromDateTime(clock.nowWall());
    await _pump(
      tester,
      TownState.initial().copyWith(streakCount: 4, lastStreakDate: today),
    );
    expect(_text(tester, 'hud-streak'), '4');
  });

  testWidgets('a streak last kept 2 days ago shows 0', (tester) async {
    final clock = FakeClock();
    final old = LocalDate.fromDateTime(
      clock.nowWall().subtract(const Duration(days: 2)),
    );
    await _pump(
      tester,
      TownState.initial().copyWith(streakCount: 4, lastStreakDate: old),
    );
    expect(_text(tester, 'hud-streak'), '0');
  });

  testWidgets('450 xp is a Village a quarter of the way up', (tester) async {
    await _pump(tester, TownState.initial().copyWith(xp: 450));
    expect(_text(tester, 'hud-level'), 'Village');
    expect(_bar(tester), closeTo((450 - 300) / 1200, 1e-9));
  });

  testWidgets('a queued building shows a badge with the count', (tester) async {
    await _pump(
      tester,
      TownState.initial().copyWith(
        queue: [const QueuedBuilding(id: 'q', tier: BuildingTier.hut)],
      ),
    );
    expect(_text(tester, 'hud-queue'), '1');
  });

  testWidgets('plots count placed buildings over unlocked plots', (
    tester,
  ) async {
    final initial = TownState.initial();
    await _pump(
      tester,
      initial.copyWith(
        plotsUnlocked: 7,
        buildings: [
          ...initial.buildings,
          const TownBuilding(
            id: 'h',
            tier: BuildingTier.hut,
            status: BuildingStatus.complete,
            plotIndex: 1,
          ),
        ],
      ),
    );
    expect(_text(tester, 'hud-plots'), '2/7');
  });
}
