import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

final _t0 = TimeStamp(DateTime(2026), Duration.zero);

TownBuilding _b(int plot, [BuildingStatus s = BuildingStatus.complete]) =>
    TownBuilding(
      id: 'b$plot',
      tier: BuildingTier.hut,
      status: s,
      plotIndex: plot,
    );

Session _session(
  SessionState state, {
  int? plot,
  BuildingTier tier = BuildingTier.hut,
}) => Session(
  id: 's1',
  plannedMinutes: tier.minMinutes,
  tier: tier,
  workersAssigned: tier.workersAtRisk,
  state: state,
  startedAt: _t0,
  plotIndex: plot,
);

TownState _town({int plots = 6, List<TownBuilding> buildings = const []}) =>
    TownState.initial().copyWith(
      plotsUnlocked: plots,
      buildings: [TownState.initial().buildings.first, ...buildings],
      workers: 10,
    );

void main() {
  group('isPlotFree', () {
    test('a free unlocked plot is free', () {
      expect(TownRules.isPlotFree(_town(), 3), isTrue);
    });

    test('a building or a ruin takes the plot', () {
      final t = _town(buildings: [_b(3), _b(4, BuildingStatus.ruin)]);
      expect(TownRules.isPlotFree(t, 3), isFalse);
      expect(TownRules.isPlotFree(t, 4), isFalse);
    });

    test('a locked or out-of-range plot is not free', () {
      expect(TownRules.isPlotFree(_town(), 6), isFalse);
      expect(TownRules.isPlotFree(_town(), -1), isFalse);
      expect(TownRules.isPlotFree(_town(), 64), isFalse);
    });
  });

  group('sitePlot', () {
    test('a chosen free plot is used', () {
      expect(
        TownRules.sitePlot(_town(), _session(SessionState.running, plot: 4)),
        4,
      );
    });

    test('no choice gives the automatic plot', () {
      expect(TownRules.sitePlot(_town(), _session(SessionState.running)), 1);
    });

    test('a taken or locked choice falls back to the automatic plot', () {
      final t = _town(buildings: [_b(4)]);
      expect(TownRules.sitePlot(t, _session(SessionState.running, plot: 4)), 1);
      expect(TownRules.sitePlot(t, _session(SessionState.running, plot: 9)), 1);
    });

    test('a full town gives null', () {
      final t = _town(buildings: [for (var i = 1; i < 6; i++) _b(i)]);
      expect(
        TownRules.sitePlot(t, _session(SessionState.running, plot: 2)),
        isNull,
      );
    });
  });

  group('results land on the chosen plot', () {
    test('a completed building', () {
      final t = TownRules.applyCompleted(
        _town(),
        _session(SessionState.completed, plot: 4),
      );
      expect(t.buildings.last.plotIndex, 4);
      expect(t.buildings.last.status, BuildingStatus.complete);
    });

    test('a failed session leaves its ruin there', () {
      final t = TownRules.applyFailed(
        _town(),
        _session(SessionState.failed, plot: 5),
      );
      expect(t.buildings.last.plotIndex, 5);
      expect(t.buildings.last.status, BuildingStatus.ruin);
    });

    test('a plot taken meanwhile falls back to the automatic one', () {
      final t = TownRules.applyCompleted(
        _town(buildings: [_b(4)]),
        _session(SessionState.completed, plot: 4),
      );
      expect(t.buildings.last.plotIndex, 1);
    });

    test('a chosen plot with a full town still queues', () {
      final t = TownRules.applyCompleted(
        _town(buildings: [for (var i = 1; i < 6; i++) _b(i)]),
        _session(SessionState.completed, plot: 2),
      );
      expect(t.queue, hasLength(1));
    });
  });

  test('SessionEngine.start remembers the chosen plot', () {
    final s = SessionEngine.start(
      id: 's',
      minutes: 10,
      workersAvailable: 5,
      now: _t0,
      plotIndex: 3,
    );
    expect(s.plotIndex, 3);
    expect(s, isNot(s.copyWith(state: SessionState.away)));
    expect(
      SessionEngine.start(
        id: 's',
        minutes: 10,
        workersAvailable: 5,
        now: _t0,
      ).plotIndex,
      isNull,
    );
  });
}
