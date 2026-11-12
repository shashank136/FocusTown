import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';

TownRow _townRowFrom(TownState s) {
  final c = townToRow(s);
  return TownRow(
    id: 1,
    workerCount: c.workerCount.value,
    plotsUnlocked: c.plotsUnlocked.value,
    xp: c.xp.value,
    streakCount: c.streakCount.value,
    lastStreakDate: c.lastStreakDate.value,
    lastPlotGrantDate: c.lastPlotGrantDate.value,
    inRecoveryMode: c.inRecoveryMode.value,
    onboardingDone: false,
    createdAt: 0,
    lastDurationMinutes: 25,
    tipPassShown: false,
    tipGrowthShown: false,
    tipRecoveryShown: false,
    notificationNoteShown: false,
    emergencyPauses: c.emergencyPauses.value,
    emergencyWeek: c.emergencyWeek.value,
    parcels: c.parcels.value,
  );
}

List<BuildingRow> _buildingRowsFrom(TownState s, DateTime now) => [
  for (final c in buildingsToRows(s, now: now))
    BuildingRow(
      id: c.id.value,
      tier: c.tier.value,
      status: c.status.value,
      plotIndex: c.plotIndex.value,
      sessionId: c.sessionId.value,
      completedAt: c.completedAt.value,
      look: c.look.value,
    ),
];

SessionRow _sessionRowFrom(SessionsCompanion c) => SessionRow(
  id: c.id.value,
  plannedMinutes: c.plannedMinutes.value,
  tier: c.tier.value,
  workersAssigned: c.workersAssigned.value,
  state: c.state.value,
  startedAtWall: c.startedAtWall.value,
  startedAtUptimeMs: c.startedAtUptimeMs.value,
  leftAtWall: c.leftAtWall.value,
  leftAtUptimeMs: c.leftAtUptimeMs.value,
  awayTotalMs: c.awayTotalMs.value,
  passUsed: c.passUsed.value,
  outcomeReason: c.outcomeReason.value,
  resolvedAt: c.resolvedAt.value,
  plotIndex: c.plotIndex.value,
  repairPlotIndex: c.repairPlotIndex.value,
  land: c.land.value,
  look: c.look.value,
  emergencyArmed: c.emergencyArmed.value,
  emergencyUsed: c.emergencyUsed.value,
);

void main() {
  final now = DateTime(2026, 3, 4, 10);

  final full = TownState(
    workers: 5,
    plotsUnlocked: 8,
    buildings: const [
      TownBuilding(
        id: 'starter',
        tier: BuildingTier.house,
        status: BuildingStatus.complete,
        plotIndex: 0,
      ),
      TownBuilding(
        id: 's1',
        tier: BuildingTier.tower,
        status: BuildingStatus.ruin,
        plotIndex: 3,
      ),
    ],
    queue: const [
      QueuedBuilding(id: 'q1', tier: BuildingTier.hut),
      QueuedBuilding(id: 'q2', tier: BuildingTier.castle),
    ],
    inRecoveryMode: true,
    xp: 130,
    streakCount: 4,
    lastStreakDate: LocalDate.parse('2026-03-04'),
    lastPlotGrantDate: LocalDate.parse('2026-03-03'),
    emergencyPauses: 0,
    emergencyWeek: LocalDate.parse('2026-03-02'),
    parcels: const [Parcel(-1, 3), Parcel(8, 0)],
  );

  group('town', () {
    test('full state round trips', () {
      final back = townFromRows(
        _townRowFrom(full),
        _buildingRowsFrom(full, now),
      );
      expect(back, full);
    });

    test('null dates map to null and back', () {
      final s = TownState.initial();
      final c = townToRow(s);
      expect(c.lastStreakDate.value, isNull);
      expect(c.lastPlotGrantDate.value, isNull);
      final back = townFromRows(_townRowFrom(s), _buildingRowsFrom(s, now));
      expect(back.lastStreakDate, isNull);
      expect(back.lastPlotGrantDate, isNull);
    });

    test('dates stored as yyyy-mm-dd', () {
      final c = townToRow(full);
      expect(c.lastStreakDate.value, '2026-03-04');
      expect(c.lastPlotGrantDate.value, '2026-03-03');
    });

    test('queue ordered by completedAt then id, whatever the row order', () {
      BuildingRow q(String id, int at) => BuildingRow(
        id: id,
        tier: 'hut',
        status: 'queued',
        sessionId: id,
        completedAt: at,
      );
      final s = townFromRows(_townRowFrom(TownState.initial()), [
        q('b', 20),
        q('z', 10),
        q('a', 20),
      ]);
      expect(s.queue.map((e) => e.id), ['z', 'a', 'b']);
      expect(s.buildings, isEmpty);
    });
  });

  group('buildingsToRows', () {
    test('placed keep plot; queued have no plot; session id rules', () {
      final rows = {
        for (final c in buildingsToRows(full, now: now)) c.id.value: c,
      };
      expect(rows['starter']!.sessionId.value, isNull);
      expect(rows['starter']!.status.value, 'complete');
      expect(rows['starter']!.plotIndex.value, 0);
      expect(rows['s1']!.status.value, 'ruin');
      expect(rows['s1']!.sessionId.value, 's1');
      expect(rows['s1']!.tier.value, 'tower');
      expect(rows['q1']!.status.value, 'queued');
      expect(rows['q1']!.plotIndex.value, isNull);
      expect(rows['q1']!.sessionId.value, 'q1');
      expect(rows['q2']!.completedAt.value, now.millisecondsSinceEpoch);
      expect(rows, hasLength(4));
    });
  });

  group('session', () {
    final started = TimeStamp(
      DateTime(2026, 3, 4, 9),
      const Duration(hours: 2),
    );
    final left = TimeStamp(
      DateTime(2026, 3, 4, 9, 20),
      const Duration(hours: 2, minutes: 20),
    );

    for (final state in SessionState.values) {
      test('${state.name} round trips with leftAt null', () {
        final s = Session(
          id: 's1',
          plannedMinutes: 25,
          tier: BuildingTier.house,
          workersAssigned: 2,
          state: state,
          startedAt: started,
        );
        expect(sessionFromRow(_sessionRowFrom(sessionToRow(s))), s);
      });

      test('${state.name} round trips with leftAt, pass, reason', () {
        final s = Session(
          id: 's2',
          plannedMinutes: 90,
          tier: BuildingTier.tower,
          workersAssigned: 5,
          state: state,
          startedAt: started,
          leftAt: left,
          awayTotal: const Duration(seconds: 42),
          passUsed: true,
          outcomeReason: OutcomeReason.leftTooLong,
          plotIndex: 4,
        );
        expect(sessionFromRow(_sessionRowFrom(sessionToRow(s))), s);
      });
    }

    test('the emergency pause flags round trip', () {
      final s = Session(
        id: 'e',
        plannedMinutes: 60,
        tier: BuildingTier.tower,
        workersAssigned: 5,
        state: SessionState.running,
        startedAt: started,
        emergencyArmed: true,
        emergencyUsed: true,
      );
      final back = sessionFromRow(_sessionRowFrom(sessionToRow(s)));
      expect(back.emergencyArmed, isTrue);
      expect(back.emergencyUsed, isTrue);
    });

    test('a land session keeps its parcel, garden or not', () {
      for (final parcel in const [Parcel(-1, 3), Parcel(8, 0, garden: true)]) {
        final s = Session(
          id: 'l',
          plannedMinutes: 25,
          tier: BuildingTier.hut,
          workersAssigned: 0,
          state: SessionState.running,
          startedAt: started,
          land: parcel,
        );
        expect(sessionFromRow(_sessionRowFrom(sessionToRow(s))).land, parcel);
      }
    });

    test('a repair keeps its ruin plot', () {
      final s = Session(
        id: 'r',
        plannedMinutes: 10,
        tier: BuildingTier.hut,
        workersAssigned: 0,
        state: SessionState.running,
        startedAt: started,
        repairPlot: 2,
      );
      final back = sessionFromRow(_sessionRowFrom(sessionToRow(s)));
      expect(back.repairPlot, 2);
      expect(back, s);
    });

    test('stores epoch ms and resolvedAt', () {
      final s = Session(
        id: 's3',
        plannedMinutes: 10,
        tier: BuildingTier.hut,
        workersAssigned: 1,
        state: SessionState.completed,
        startedAt: started,
        outcomeReason: OutcomeReason.completed,
      );
      final c = sessionToRow(s, resolvedAt: now);
      expect(c.startedAtWall.value, started.wall.millisecondsSinceEpoch);
      expect(
        c.startedAtUptimeMs.value,
        const Duration(hours: 2).inMilliseconds,
      );
      expect(c.resolvedAt.value, now.millisecondsSinceEpoch);
      expect(c.leftAtWall.value, isNull);
      expect(c.state.value, 'completed');
      expect(c.outcomeReason.value, 'completed');
      expect(sessionToRow(s).resolvedAt.value, isNull);
    });
  });

  group('looks', () {
    test(
      'a chosen look round trips on a building, the queue and a session',
      () {
        final town = TownState(
          workers: 3,
          plotsUnlocked: 6,
          buildings: const [
            TownBuilding(
              id: 'a',
              tier: BuildingTier.hut,
              status: BuildingStatus.complete,
              plotIndex: 1,
              look: 1,
            ),
            TownBuilding(
              id: 'b',
              tier: BuildingTier.hut,
              status: BuildingStatus.complete,
              plotIndex: 2,
            ),
          ],
          queue: const [
            QueuedBuilding(id: 'q', tier: BuildingTier.castle, look: 1),
          ],
          inRecoveryMode: false,
        );
        final back = townFromRows(
          _townRowFrom(town),
          _buildingRowsFrom(town, now),
        );
        expect(back.buildings.map((b) => b.look), [1, null]);
        expect(back.queue.single.look, 1);

        final s = Session(
          id: 'l',
          plannedMinutes: 25,
          tier: BuildingTier.house,
          workersAssigned: 2,
          state: SessionState.running,
          startedAt: TimeStamp(DateTime(2026, 3, 4, 9), Duration.zero),
          look: 1,
        );
        expect(sessionFromRow(_sessionRowFrom(sessionToRow(s))).look, 1);
      },
    );
  });
}
