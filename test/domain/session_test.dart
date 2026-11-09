import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';

Session _make() => Session(
  id: 's1',
  plannedMinutes: 25,
  tier: BuildingTier.house,
  workersAssigned: 2,
  state: SessionState.running,
  startedAt: TimeStamp(DateTime(2026), Duration.zero),
);

void main() {
  final stamp = TimeStamp(
    DateTime(2026, 1, 1, 0, 5),
    const Duration(minutes: 5),
  );

  test('defaults: no leftAt, no away, no pass, no outcome', () {
    final s = _make();
    expect(s.leftAt, isNull);
    expect(s.awayTotal, Duration.zero);
    expect(s.passUsed, isFalse);
    expect(s.outcomeReason, isNull);
  });

  test('planned for 25 minutes is 25 min', () {
    expect(_make().planned, const Duration(minutes: 25));
  });

  group('copyWith changes only the named field', () {
    final base = _make();
    test('state', () {
      final c = base.copyWith(state: SessionState.away);
      expect(c.state, SessionState.away);
      expect(c, isNot(base));
      expect(c.copyWith(state: SessionState.running), base);
    });
    test('leftAt', () {
      final c = base.copyWith(leftAt: stamp);
      expect(c.leftAt, stamp);
      expect(c.copyWith(clearLeftAt: true), base);
    });
    test('awayTotal', () {
      final c = base.copyWith(awayTotal: const Duration(seconds: 5));
      expect(c.awayTotal, const Duration(seconds: 5));
      expect(c.copyWith(awayTotal: Duration.zero), base);
    });
    test('passUsed', () {
      final c = base.copyWith(passUsed: true);
      expect(c.passUsed, isTrue);
      expect(c.copyWith(passUsed: false), base);
    });
    test('outcomeReason', () {
      final c = base.copyWith(outcomeReason: OutcomeReason.abandoned);
      expect(c.outcomeReason, OutcomeReason.abandoned);
      expect(c.id, base.id);
      expect(c.state, base.state);
    });
  });

  test('clearLeftAt wins over leftAt-less copy and keeps others', () {
    final s = _make().copyWith(leftAt: stamp, passUsed: true);
    final c = s.copyWith(clearLeftAt: true);
    expect(c.leftAt, isNull);
    expect(c.passUsed, isTrue);
  });

  group('equality', () {
    test('equal sessions are equal with same hashCode', () {
      expect(_make(), _make());
      expect(_make().hashCode, _make().hashCode);
    });
    test('differs when any field differs', () {
      final b = _make();
      final others = [
        Session(
          id: 'x',
          plannedMinutes: 25,
          tier: BuildingTier.house,
          workersAssigned: 2,
          state: SessionState.running,
          startedAt: b.startedAt,
        ),
        Session(
          id: 's1',
          plannedMinutes: 30,
          tier: BuildingTier.house,
          workersAssigned: 2,
          state: SessionState.running,
          startedAt: b.startedAt,
        ),
        Session(
          id: 's1',
          plannedMinutes: 25,
          tier: BuildingTier.hut,
          workersAssigned: 2,
          state: SessionState.running,
          startedAt: b.startedAt,
        ),
        Session(
          id: 's1',
          plannedMinutes: 25,
          tier: BuildingTier.house,
          workersAssigned: 1,
          state: SessionState.running,
          startedAt: b.startedAt,
        ),
        Session(
          id: 's1',
          plannedMinutes: 25,
          tier: BuildingTier.house,
          workersAssigned: 2,
          state: SessionState.running,
          startedAt: stamp,
        ),
        b.copyWith(state: SessionState.away),
        b.copyWith(leftAt: stamp),
        b.copyWith(awayTotal: const Duration(seconds: 1)),
        b.copyWith(passUsed: true),
        b.copyWith(outcomeReason: OutcomeReason.leftTooLong),
      ];
      for (final o in others) {
        expect(o, isNot(b));
      }
    });
  });

  test('isActive / isFinished for all four states', () {
    final expected = {
      SessionState.running: (true, false),
      SessionState.away: (true, false),
      SessionState.completed: (false, true),
      SessionState.failed: (false, true),
    };
    for (final e in expected.entries) {
      final s = _make().copyWith(state: e.key);
      expect(s.isActive, e.value.$1, reason: '${e.key} isActive');
      expect(s.isFinished, e.value.$2, reason: '${e.key} isFinished');
    }
  });
}
