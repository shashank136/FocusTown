import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/domain/town_rules.dart';

TownState _city({
  List<DistrictSide> done = const [],
  DistrictProject? project,
  List<Parcel> parcels = const [],
  int? xp,
}) => TownState.initial().copyWith(
  xp: xp ?? TownLevel.city.minXp,
  districts: done,
  districtProject: project,
  parcels: parcels,
);

void main() {
  group('text form', () {
    test('sides and the project are written and read back', () {
      expect(encodeDistricts(const []), '');
      expect(decodeDistricts(''), isEmpty);
      const sides = [DistrictSide.east, DistrictSide.north];
      expect(encodeDistricts(sides), 'east,north');
      expect(decodeDistricts('east,north'), sides);
      const project = DistrictProject(DistrictSide.west, 130);
      expect(project.encode(), 'west:130');
      expect(DistrictProject.decode('west:130'), project);
    });
  });

  group('session', () {
    test('a district session risks nothing and says which side', () {
      final s = SessionEngine.startDistrict(
        id: 'd1',
        side: DistrictSide.west,
        minutes: 60,
        now: TimeStamp(DateTime(2026), Duration.zero),
      );
      expect(s.isDistrict, isTrue);
      expect(s.district, DistrictSide.west);
      expect(s.workersAssigned, 0);
      expect(s.plannedMinutes, 60);
      expect(s.isLand || s.isLandmark || s.isRepair, isFalse);
      // The session copies keep the side.
      expect(s.copyWith(plannedMinutes: 30).district, DistrictSide.west);
    });

    test(
      'it remembers the minutes it counts, even when the clock is faster',
      () {
        final s = SessionEngine.startDistrict(
          id: 'd1',
          side: DistrictSide.north,
          minutes: 120,
          now: TimeStamp(DateTime(2026), Duration.zero),
        );
        expect(s.creditMinutes, 120);
        // The testing aid makes the session last 1 minute; the credit stays.
        final quick = s.copyWith(plannedMinutes: 1);
        expect(quick.plannedMinutes, 1);
        expect(quick.creditMinutes, 120);
      },
    );

    test('how much of the planned time was focused when it failed', () {
      final start = TimeStamp(DateTime(2026), Duration.zero);
      TimeStamp at(int s) => TimeStamp(
        DateTime(2026).add(Duration(seconds: s)),
        Duration(seconds: s),
      );
      final s = SessionEngine.startDistrict(
        id: 'd1',
        side: DistrictSide.north,
        minutes: 120,
        now: start,
      ).copyWith(plannedMinutes: 1);
      final abandoned = s.copyWith(
        state: SessionState.failed,
        outcomeReason: OutcomeReason.abandoned,
      );
      expect(
        SessionEngine.focusedFraction(abandoned, at(30)),
        closeTo(0.5, 1e-9),
      );
      expect(SessionEngine.focusedFraction(abandoned, at(500)), 1);
      // Left too long: the focus stopped when the user left.
      final left = s.copyWith(
        state: SessionState.failed,
        outcomeReason: OutcomeReason.leftTooLong,
        leftAt: at(15),
      );
      expect(SessionEngine.focusedFraction(left, at(500)), closeTo(0.25, 1e-9));
    });
  });

  group('rows', () {
    test('a district is 8 rows of 8 parcels, outward from the island', () {
      expect(districtRow(DistrictSide.east, 0, 0), [
        for (var y = 0; y < 8; y++) Parcel(8, y),
      ]);
      expect(districtRow(DistrictSide.east, 0, 7).first, const Parcel(15, 0));
      expect(districtRow(DistrictSide.west, 0, 0).first, const Parcel(-1, 0));
      expect(districtRow(DistrictSide.west, 0, 7).first, const Parcel(-8, 0));
      expect(districtRow(DistrictSide.north, 0, 0), [
        for (var x = 0; x < 8; x++) Parcel(x, -1),
      ]);
      expect(districtRow(DistrictSide.south, 0, 0).first, const Parcel(0, 8));
    });

    test('the next district on a side starts where the last one ended', () {
      expect(districtRow(DistrictSide.west, 1, 0).first, const Parcel(-9, 0));
      expect(districtRow(DistrictSide.north, 1, 7).first, const Parcel(0, -16));
    });

    test('room: one more east or south, two north or west', () {
      expect(districtFits(DistrictSide.east, 0), isTrue);
      expect(districtFits(DistrictSide.east, 1), isFalse);
      expect(districtFits(DistrictSide.south, 0), isTrue);
      expect(districtFits(DistrictSide.south, 1), isFalse);
      expect(districtFits(DistrictSide.west, 1), isTrue);
      expect(districtFits(DistrictSide.west, 2), isFalse);
      expect(districtFits(DistrictSide.north, 1), isTrue);
      expect(districtFits(DistrictSide.north, 2), isFalse);
    });
  });

  group('state', () {
    test('never locked: a new town can start a district at once', () {
      for (final side in DistrictSide.values) {
        expect(
          TownRules.districtState(
            TownState.initial(), // no focus minutes at all
            side,
          ),
          DistrictState.ready,
        );
      }
    });

    test('any side can be chosen while one is being built', () {
      final t = _city(project: const DistrictProject(DistrictSide.east, 0));
      expect(
        TownRules.districtState(t, DistrictSide.east),
        DistrictState.inProgress,
      );
      for (final side in [
        DistrictSide.north,
        DistrictSide.south,
        DistrictSide.west,
      ]) {
        expect(TownRules.districtState(t, side), DistrictState.ready);
      }
    });

    test('a side with no room left says so', () {
      final t = _city(done: [DistrictSide.east]);
      expect(
        TownRules.districtState(t, DistrictSide.east),
        DistrictState.noRoom,
      );
      expect(
        TownRules.districtState(t, DistrictSide.west),
        DistrictState.ready,
      );
    });

    test('at most 3 districts in all', () {
      final t = _city(
        done: [DistrictSide.east, DistrictSide.west, DistrictSide.north],
      );
      expect(
        TownRules.districtState(t, DistrictSide.south),
        DistrictState.limit,
      );
    });

    test('beginning one sets the project', () {
      final t = TownRules.beginDistrict(_city(), DistrictSide.north)!;
      expect(t.districtProject, const DistrictProject(DistrictSide.north, 0));
    });
  });

  group('switching sides', () {
    test('rows built on a side are counted from the land', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      expect(TownRules.builtRows(t, DistrictSide.east), 0);
      t = TownRules.applyDistrictMinutes(t, 130);
      expect(TownRules.builtRows(t, DistrictSide.east), 2);
      expect(TownRules.builtRows(t, DistrictSide.west), 0);
    });

    test('a row with a square owned before does not count by itself', () {
      final t = _city(parcels: [districtRow(DistrictSide.west, 0, 0).first]);
      expect(TownRules.builtRows(t, DistrictSide.west), 0);
    });

    test('switching keeps the rows and drops the minutes of the old side', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 130); // two rows and 10 minutes
      final west = TownRules.beginDistrict(t, DistrictSide.west)!;
      expect(west.districtProject, const DistrictProject(DistrictSide.west, 0));
      expect(west.parcels, t.parcels); // the east rows are still land
    });

    test('coming back goes on from the rows already built', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 130);
      t = TownRules.beginDistrict(t, DistrictSide.west)!;
      final back = TownRules.beginDistrict(t, DistrictSide.east)!;
      expect(
        back.districtProject,
        const DistrictProject(DistrictSide.east, 120),
      );
      final more = TownRules.applyDistrictMinutes(back, 60); // the third row
      expect(TownRules.builtRows(more, DistrictSide.east), 3);
      expect(more.parcels.length, 24);
    });

    test('starting the side already being built keeps its minutes', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 130);
      expect(
        TownRules.beginDistrict(t, DistrictSide.east)!.districtProject,
        const DistrictProject(DistrictSide.east, 130),
      );
    });

    test('the limit counts finished and half-built districts', () {
      var t = _city(done: [DistrictSide.east, DistrictSide.west]);
      // A third, half built, on the north.
      t = TownRules.beginDistrict(t, DistrictSide.north)!;
      t = TownRules.applyDistrictMinutes(t, 120);
      expect(
        TownRules.districtState(t, DistrictSide.south),
        DistrictState.limit,
      );
      // The half-built one can still be gone on with.
      expect(
        TownRules.districtState(t, DistrictSide.north),
        DistrictState.inProgress,
      );
      final other = TownRules.beginDistrict(t, DistrictSide.south);
      expect(other, isNull);
    });
  });

  group('progress', () {
    test('a row is 60 minutes, the leftover carries', () {
      expect(const DistrictProject(DistrictSide.east, 59).rows, 0);
      expect(const DistrictProject(DistrictSide.east, 60).rows, 1);
      expect(const DistrictProject(DistrictSide.east, 479).rows, 7);
      expect(const DistrictProject(DistrictSide.east, 480).rows, 8);
    });

    test('a finished row becomes parcels at once', () {
      final t = TownRules.applyDistrictMinutes(
        TownRules.beginDistrict(_city(), DistrictSide.east)!,
        90,
      );
      expect(t.districtProject!.progress, 90);
      expect(t.parcels, districtRow(DistrictSide.east, 0, 0));
    });

    test('two rows after 120 minutes, in order', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 60);
      t = TownRules.applyDistrictMinutes(t, 60);
      expect(t.parcels, [
        ...districtRow(DistrictSide.east, 0, 0),
        ...districtRow(DistrictSide.east, 0, 1),
      ]);
    });

    test('the whole district finishes at 480 minutes', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.west)!;
      t = TownRules.applyDistrictMinutes(t, 480);
      expect(t.parcels, hasLength(64));
      expect(t.districts, [DistrictSide.west]);
      expect(t.districtProject, isNull);
      // More minutes than needed change nothing more.
      expect(TownRules.applyDistrictMinutes(t, 60), t);
    });

    test('parcels already claimed are skipped and keep their kind', () {
      const garden = Parcel(8, 3, garden: true);
      var t = _city(parcels: [garden]);
      t = TownRules.beginDistrict(t, DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 60);
      expect(t.parcels.where((p) => p.gx == 8 && p.gy == 3), [garden]);
      expect(t.parcels, hasLength(8));
    });

    test('a district parcel is never claimed twice across districts', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 480);
      final seen = {for (final p in t.parcels) (p.gx, p.gy)};
      expect(seen, hasLength(t.parcels.length));
    });
  });

  group('a session counts its credit minutes', () {
    test('a completed session counts the minutes it was started with', () {
      final s = SessionEngine.startDistrict(
        id: 'd1',
        side: DistrictSide.east,
        minutes: 120,
        now: TimeStamp(DateTime(2026), Duration.zero),
      ).copyWith(plannedMinutes: 1);
      final t = TownRules.applyDistrictCompleted(
        TownRules.beginDistrict(_city(), DistrictSide.east)!,
        s,
      );
      expect(t.parcels, hasLength(16)); // two rows, not one
      expect(t.districtProject!.progress, 120);
    });
  });

  group('failing', () {
    test('only the minutes toward the next row are lost', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 130);
      final failed = TownRules.applyDistrictFailed(t);
      expect(failed.districtProject!.progress, 120);
      expect(failed.parcels, t.parcels); // land is never taken back
    });

    test('nothing is lost when no row is half done, never below nothing', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      expect(TownRules.applyDistrictFailed(t).districtProject!.progress, 0);
      t = TownRules.applyDistrictMinutes(t, 120);
      expect(TownRules.applyDistrictFailed(t).districtProject!.progress, 120);
    });

    test('the rows earned before giving up stay', () {
      final t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      // 130 minutes were focused: two whole rows, 10 minutes lost.
      final failed = TownRules.applyDistrictFailed(t, 130);
      expect(failed.parcels, hasLength(16));
      expect(failed.districtProject!.progress, 120);
      // Under an hour earns nothing.
      expect(TownRules.applyDistrictFailed(t, 59).parcels, isEmpty);
      expect(TownRules.applyDistrictFailed(t, 59).districtProject!.progress, 0);
    });

    test('earning the last row before giving up finishes the district', () {
      var t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      t = TownRules.applyDistrictMinutes(t, 450);
      final failed = TownRules.applyDistrictFailed(t, 40);
      expect(failed.parcels, hasLength(64));
      expect(failed.districts, [DistrictSide.east]);
      expect(failed.districtProject, isNull);
    });
  });

  group('live land', () {
    test('the rows a running session has reached so far', () {
      final t = TownRules.beginDistrict(_city(), DistrictSide.east)!;
      final s = SessionEngine.startDistrict(
        id: 'd1',
        side: DistrictSide.east,
        minutes: 120,
        now: TimeStamp(DateTime(2026), Duration.zero),
      );
      expect(TownRules.liveDistrictParcels(t, s, 0.49), isEmpty);
      expect(
        TownRules.liveDistrictParcels(t, s, 0.5),
        districtRow(DistrictSide.east, 0, 0),
      );
      expect(TownRules.liveDistrictParcels(t, s, 1), hasLength(16));
    });
  });
}
