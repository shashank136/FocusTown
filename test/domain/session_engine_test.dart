import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
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

  group('away rules', () {
    late FakeClock clock;
    late Session running;

    TimeStamp stamp() => TimeStamp.now(clock);

    setUp(() {
      clock = FakeClock();
      running = SessionEngine.start(
        id: 's',
        minutes: 25,
        workersAvailable: 5,
        now: stamp(),
      );
    });

    // Leaves, waits [away], returns.
    Session awayFor(Session s, Duration away) {
      final left = SessionEngine.onBackgroundedUnlocked(s, stamp());
      clock.advance(away);
      return SessionEngine.onForegrounded(left, stamp());
    }

    Duration secs(int n) => Duration(seconds: n);

    test('lock for 5 minutes changes nothing', () {
      clock.advance(const Duration(minutes: 5));
      expect(SessionEngine.onLocked(running, stamp()), running);
    });

    test('call started changes nothing', () {
      expect(SessionEngine.onCallStarted(running, stamp()), running);
    });

    test('leaving sets away and leftAt', () {
      final s = SessionEngine.onBackgroundedUnlocked(running, stamp());
      expect(s.state, SessionState.away);
      expect(s.leftAt, stamp());
    });

    test('away 5 s returns to running without the pass', () {
      final s = awayFor(running, secs(5));
      expect(s.state, SessionState.running);
      expect(s.passUsed, isFalse);
      expect(s.awayTotal, secs(5));
      expect(s.leftAt, isNull);
    });

    test('away exactly 10 s is forgiven without the pass', () {
      final s = awayFor(running, secs(10));
      expect(s.state, SessionState.running);
      expect(s.passUsed, isFalse);
    });

    test('away 30 s uses the pass', () {
      final s = awayFor(running, secs(30));
      expect(s.state, SessionState.running);
      expect(s.passUsed, isTrue);
      expect(s.awayTotal, secs(30));
      expect(s.leftAt, isNull);
    });

    test('second away of 30 s fails leftTooLong', () {
      final s = awayFor(awayFor(running, secs(30)), secs(30));
      expect(s.state, SessionState.failed);
      expect(s.outcomeReason, OutcomeReason.leftTooLong);
      expect(s.awayTotal, secs(60));
      expect(s.leftAt, isNotNull);
    });

    test('away exactly 70 s with the pass available returns to running', () {
      final s = awayFor(running, secs(70));
      expect(s.state, SessionState.running);
      expect(s.passUsed, isTrue);
    });

    test('away 71 s fails', () {
      final s = awayFor(running, secs(71));
      expect(s.state, SessionState.failed);
      expect(s.outcomeReason, OutcomeReason.leftTooLong);
    });

    test('away 90 s fails', () {
      expect(awayFor(running, secs(90)).state, SessionState.failed);
    });

    test('away 11 s after the pass was used fails', () {
      final s = awayFor(awayFor(running, secs(30)), secs(11));
      expect(s.state, SessionState.failed);
    });

    test('a short away after the pass is still forgiven', () {
      final s = awayFor(awayFor(running, secs(30)), secs(5));
      expect(s.state, SessionState.running);
      expect(s.awayTotal, secs(35));
    });

    test('backgrounding an away session is a no-op', () {
      final away = SessionEngine.onBackgroundedUnlocked(running, stamp());
      clock.advance(secs(5));
      expect(SessionEngine.onBackgroundedUnlocked(away, stamp()), away);
    });

    test('backgrounding a finished session is a no-op', () {
      final done = running.copyWith(state: SessionState.completed);
      expect(SessionEngine.onBackgroundedUnlocked(done, stamp()), done);
    });

    test('foregrounding a running session is a no-op', () {
      expect(SessionEngine.onForegrounded(running, stamp()), running);
    });

    test('abandon from running fails abandoned', () {
      final s = SessionEngine.abandon(running, stamp());
      expect(s.state, SessionState.failed);
      expect(s.outcomeReason, OutcomeReason.abandoned);
    });

    test('abandon from away fails abandoned', () {
      final away = SessionEngine.onBackgroundedUnlocked(running, stamp());
      final s = SessionEngine.abandon(away, stamp());
      expect(s.state, SessionState.failed);
      expect(s.outcomeReason, OutcomeReason.abandoned);
    });

    test('abandon of a completed session is a no-op', () {
      final done = running.copyWith(
        state: SessionState.completed,
        outcomeReason: OutcomeReason.completed,
      );
      expect(SessionEngine.abandon(done, stamp()), done);
    });
  });
}
