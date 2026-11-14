import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

TimeStamp _at(int s) => TimeStamp(
  DateTime(2026, 11, 11, 9).add(Duration(seconds: s)),
  Duration(seconds: s),
);

// A forest square of the island, to become a garden.
const _west = Parcel(5, 5, garden: true);

Session _land({Parcel parcel = _west, int minutes = 15}) =>
    SessionEngine.startLand(
      id: 'l',
      parcel: parcel,
      minutes: minutes,
      now: _at(0),
    );

void main() {
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
      final done = SessionEngine.resolve(_land(), _at(15 * 60));
      expect(done.state, SessionState.completed);
    });

    test('the emergency pause cannot be armed on it', () {
      expect(TownRules.armEmergency(TownState.initial(), _land()), isNull);
    });
  });
}
