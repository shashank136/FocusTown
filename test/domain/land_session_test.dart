import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

TimeStamp _at(int s) => TimeStamp(
  DateTime(2026, 11, 11, 9).add(Duration(seconds: s)),
  Duration(seconds: s),
);

const _west = Parcel(-1, 3);

Session _land({Parcel parcel = _west, int minutes = 25}) =>
    SessionEngine.startLand(
      id: 'l',
      parcel: parcel,
      minutes: minutes,
      now: _at(0),
    );

void main() {
  group('land minutes', () {
    test('25 for the first parcels, 5 more for every 4, at most 90', () {
      expect(TownRules.landMinutes(0), 25);
      expect(TownRules.landMinutes(3), 25);
      expect(TownRules.landMinutes(4), 30);
      expect(TownRules.landMinutes(8), 35);
      expect(TownRules.landMinutes(100), 90);
    });
  });

  group('the session', () {
    test('puts nothing at risk and carries the parcel', () {
      final s = _land(minutes: 30);
      expect(s.isLand, isTrue);
      expect(s.isRepair, isFalse);
      expect(s.land, _west);
      expect(s.plannedMinutes, 30);
      expect(s.workersAssigned, 0);
      expect(s.state, SessionState.running);
    });

    test('keeps the parcel through every change of state', () {
      final away = SessionEngine.onBackgroundedUnlocked(_land(), _at(5));
      expect(away.land, _west);
      expect(away.copyWith(passUsed: true).land, _west);
    });

    test('a land session completes like any other', () {
      final done = SessionEngine.resolve(_land(), _at(25 * 60));
      expect(done.state, SessionState.completed);
    });

    test('the emergency pause cannot be armed on it', () {
      expect(TownRules.armEmergency(TownState.initial(), _land()), isNull);
    });
  });

  group('claiming', () {
    test('only a parcel next to the island can be claimed', () {
      final town = TownState.initial();
      expect(TownRules.canClaim(town, _west), isTrue);
      expect(TownRules.canClaim(town, const Parcel(3, 3)), isFalse);
      expect(TownRules.canClaim(town, const Parcel(-5, 3)), isFalse);
      expect(
        TownRules.canClaim(town.copyWith(parcels: [_west]), _west),
        isFalse,
      );
    });

    test('a completed land session adds the parcel', () {
      final done = _land().copyWith(state: SessionState.completed);
      final town = TownRules.applyLandCompleted(TownState.initial(), done);
      expect(town.parcels, [_west]);
      expect(TownRules.plotCountOf(town), 65);
    });

    test('a garden adds land only', () {
      const garden = Parcel(-1, 3, garden: true);
      final done = _land(parcel: garden)
          .copyWith(state: SessionState.completed);
      final town = TownRules.applyLandCompleted(TownState.initial(), done);
      expect(town.parcels, [garden]);
      expect(TownRules.plotCountOf(town), 64);
    });

    test('a parcel that is no longer free changes nothing', () {
      final done = _land().copyWith(state: SessionState.completed);
      final town = TownState.initial().copyWith(parcels: [_west]);
      expect(TownRules.applyLandCompleted(town, done), town);
    });

    test('the next plot follows and a queued building takes it', () {
      final full = TownState(
        workers: 3,
        plotsUnlocked: 64,
        buildings: [
          for (var i = 0; i < 64; i++)
            TownBuilding(
              id: 'b$i',
              tier: BuildingTier.hut,
              status: BuildingStatus.complete,
              plotIndex: i,
            ),
        ],
        queue: const [QueuedBuilding(id: 'q', tier: BuildingTier.hut)],
        inRecoveryMode: false,
      );
      final done = _land().copyWith(state: SessionState.completed);
      final town = Progression.onSessionCompleted(
        TownRules.applyLandCompleted(full, done),
        done,
        DateTime(2026, 11, 11, 10),
      );
      expect(town.queue, isEmpty);
      expect(town.buildings.any((b) => b.plotIndex == 64), isTrue);
    });
  });
}
