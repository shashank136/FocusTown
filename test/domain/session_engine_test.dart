import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';

void main() {
  final now = TimeStamp(DateTime(2026, 1, 1, 9), const Duration(minutes: 3));

  Session start(int minutes, int workers) => SessionEngine.start(
    id: 's1',
    minutes: minutes,
    workersAvailable: workers,
    now: now,
  );

  group('start', () {
    test('25 min with 5 workers makes a running house', () {
      final s = start(25, 5);
      expect(s.id, 's1');
      expect(s.plannedMinutes, 25);
      expect(s.tier, BuildingTier.house);
      expect(s.workersAssigned, 2);
      expect(s.state, SessionState.running);
      expect(s.startedAt, now);
      expect(s.leftAt, isNull);
      expect(s.awayTotal, Duration.zero);
      expect(s.passUsed, isFalse);
      expect(s.outcomeReason, isNull);
    });

    test('10 min with 1 worker works', () {
      expect(start(10, 1).workersAssigned, 1);
    });

    test('120 min with 8 workers works', () {
      expect(start(120, 8).tier, BuildingTier.castle);
    });

    test('120 min with 7 workers throws StateError', () {
      expect(() => start(120, 7), throwsStateError);
    });

    test('25 min with 1 worker throws StateError', () {
      expect(() => start(25, 1), throwsStateError);
    });

    test('7 min throws ArgumentError', () {
      expect(() => start(7, 8), throwsArgumentError);
    });

    test('130 min throws ArgumentError', () {
      expect(() => start(130, 8), throwsArgumentError);
    });
  });
}
