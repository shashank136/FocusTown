import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

TownBuilding _b(int plot, BuildingStatus s) => TownBuilding(
  id: 'b$plot',
  tier: BuildingTier.house,
  status: s,
  plotIndex: plot,
);

TownState _town({int workers = 3, bool recovery = false}) => TownState(
  workers: workers,
  plotsUnlocked: 4,
  buildings: [
    _b(0, BuildingStatus.complete),
    _b(1, BuildingStatus.ruin),
    _b(2, BuildingStatus.ruin),
  ],
  queue: const [],
  inRecoveryMode: recovery,
);

final _now = TimeStamp(DateTime(2026, 1, 1, 9), const Duration(minutes: 3));

Session _repair({int plot = 1}) => SessionEngine.startRepair(
  id: 'r1',
  plot: plot,
  now: _now,
);

void main() {
  group('starting a repair', () {
    test('is a 10-minute session with nothing at risk', () {
      final s = _repair();
      expect(s.plannedMinutes, 10);
      expect(s.workersAssigned, 0);
      expect(s.repairPlot, 1);
      expect(s.isRepair, isTrue);
      expect(s.state, SessionState.running);
    });

    test('an ordinary session is not a repair', () {
      final s = SessionEngine.start(
        id: 's',
        minutes: 25,
        workersAvailable: 5,
        now: _now,
      );
      expect(s.isRepair, isFalse);
    });

    test('the repair plot survives away and return', () {
      final s = SessionEngine.onBackgroundedUnlocked(_repair(), _now);
      expect(s.repairPlot, 1);
    });
  });

  group('canRepair', () {
    test('only a ruin can be repaired', () {
      final t = _town();
      expect(TownRules.canRepair(t, 1), isTrue);
      expect(TownRules.canRepair(t, 0), isFalse); // a standing building
      expect(TownRules.canRepair(t, 3), isFalse); // nothing there
    });
  });

  group('a finished repair', () {
    test('completing clears exactly that ruin', () {
      final t = TownRules.applyRepairCompleted(
        _town(),
        _repair().copyWith(state: SessionState.completed),
      );
      expect(t.buildings.map((b) => b.plotIndex), [0, 2]);
    });

    test('completing changes no workers and no recovery mode', () {
      final before = _town(workers: 0, recovery: true);
      final after = TownRules.applyRepairCompleted(
        before,
        _repair().copyWith(state: SessionState.completed),
      );
      expect(after.workers, 0);
      expect(after.inRecoveryMode, isTrue);
    });

    test('a freed plot takes a waiting building', () {
      final full = _town().copyWith(
        plotsUnlocked: 3,
        queue: const [QueuedBuilding(id: 'q', tier: BuildingTier.hut)],
      );
      final t = TownRules.applyRepairCompleted(
        full,
        _repair().copyWith(state: SessionState.completed),
      );
      expect(t.queue, isEmpty);
      expect(t.buildings.any((b) => b.id == 'q'), isTrue);
    });

    test('counts for XP and the streak like any session', () {
      final done = _repair().copyWith(state: SessionState.completed);
      final t = Progression.onSessionCompleted(
        TownRules.applyRepairCompleted(_town(), done),
        done,
        DateTime(2026, 1, 1, 9, 10),
      );
      expect(t.xp, 10);
      expect(t.streakCount, 1);
    });

    test('repairing a plot that is no longer a ruin changes nothing', () {
      final t = TownRules.applyRepairCompleted(
        _town(),
        _repair(plot: 0).copyWith(state: SessionState.completed),
      );
      expect(t, _town());
    });
  });
}
