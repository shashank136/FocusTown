import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/parcel.dart';
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

    test('one at a time: the others are busy, the one building shows', () {
      final t = _city(project: const DistrictProject(DistrictSide.east, 0));
      expect(
        TownRules.districtState(t, DistrictSide.east),
        DistrictState.inProgress,
      );
      expect(TownRules.districtState(t, DistrictSide.west), DistrictState.busy);
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

    test('beginning one sets the project, and only when it is ready', () {
      final t = TownRules.beginDistrict(_city(), DistrictSide.north)!;
      expect(t.districtProject, const DistrictProject(DistrictSide.north, 0));
      expect(TownRules.beginDistrict(t, DistrictSide.west), isNull);
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
  });
}
