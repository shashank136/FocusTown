import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

TownState _town({int plots = 6, List<Parcel> parcels = const []}) => TownState(
  workers: 3,
  plotsUnlocked: plots,
  buildings: const [],
  queue: const [],
  inRecoveryMode: false,
  parcels: parcels,
);

void main() {
  test('a new town has no extra parcels and 64 plots of room', () {
    expect(TownState.initial().parcels, isEmpty);
    expect(TownRules.plotCountOf(TownState.initial()), 64);
  });

  test('each claimed parcel adds one plot', () {
    final town = _town(parcels: const [Parcel(-1, 3), Parcel(8, 0)]);
    expect(TownRules.plotCountOf(town), 66);
  });

  test('plot 64 is usable only after a parcel is claimed', () {
    expect(TownRules.isPlotFree(_town(plots: 70), 64), isFalse);
    final town = _town(plots: 70, parcels: const [Parcel(-1, 3)]);
    expect(TownRules.isPlotFree(town, 64), isTrue);
    expect(TownRules.isPlotFree(town, 65), isFalse);
  });

  test('copyWith keeps and changes the parcels', () {
    final town = _town();
    expect(town.copyWith(plotsUnlocked: 7).parcels, isEmpty);
    expect(town.copyWith(parcels: const [Parcel(1, 1)]).parcels, const [
      Parcel(1, 1),
    ]);
    expect(_town(parcels: const [Parcel(1, 1)]), isNot(_town()));
  });

  test('the daily plot stops at the plots the island has', () {
    final session = Session(
      id: 's',
      plannedMinutes: 25,
      tier: BuildingTier.house,
      workersAssigned: 2,
      state: SessionState.completed,
      startedAt: TimeStamp(DateTime(2026, 11, 11, 9), Duration.zero),
    );
    final day = DateTime(2026, 11, 11, 10);
    final full = Progression.onSessionCompleted(_town(plots: 64), session, day);
    expect(full.plotsUnlocked, 64);
    final room = Progression.onSessionCompleted(
      _town(plots: 64, parcels: const [Parcel(-1, 3)]),
      session,
      day,
    );
    expect(room.plotsUnlocked, 65);
  });

  test('a garden adds land but no plot', () {
    final town = _town(parcels: const [Parcel(-1, 3, garden: true)]);
    expect(TownRules.plotCountOf(town), 64);
  });
}
