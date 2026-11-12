import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

const _mon = LocalDate(2026, 11, 9);

TimeStamp _at(int seconds) => TimeStamp(
  DateTime(2026, 11, 11, 9).add(Duration(seconds: seconds)),
  Duration(seconds: seconds),
);

Session _session() =>
    SessionEngine.start(id: 's', minutes: 60, workersAvailable: 5, now: _at(0));

void main() {
  group('the week', () {
    test('starts on Monday', () {
      expect(TownRules.weekStart(const LocalDate(2026, 11, 11)), _mon);
      expect(TownRules.weekStart(_mon), _mon);
      expect(TownRules.weekStart(const LocalDate(2026, 11, 15)), _mon);
      expect(
        TownRules.weekStart(const LocalDate(2026, 11, 16)),
        const LocalDate(2026, 11, 16),
      );
    });
  });

  group('refill', () {
    test('a new town starts with one pause', () {
      expect(TownState.initial().emergencyPauses, 1);
      expect(TownState.initial().emergencyWeek, isNull);
    });

    test('the first session of a new week brings the pause back', () {
      final spent = TownState.initial().copyWith(
        emergencyPauses: 0,
        emergencyWeek: _mon,
      );
      final next = TownRules.refillEmergency(
        spent,
        const LocalDate(2026, 11, 17),
      );
      expect(next.emergencyPauses, 1);
      expect(next.emergencyWeek, const LocalDate(2026, 11, 16));
    });

    test('the same week gives nothing back', () {
      final spent = TownState.initial().copyWith(
        emergencyPauses: 0,
        emergencyWeek: _mon,
      );
      expect(
        TownRules.refillEmergency(spent, const LocalDate(2026, 11, 15)),
        spent,
      );
    });

    test('never more than one is stored', () {
      final full = TownState.initial().copyWith(emergencyWeek: _mon);
      final next = TownRules.refillEmergency(
        full,
        const LocalDate(2026, 12, 25),
      );
      expect(next.emergencyPauses, 1);
    });

    test('moving the clock back never grants an extra one', () {
      final spent = TownState.initial().copyWith(
        emergencyPauses: 0,
        emergencyWeek: const LocalDate(2026, 11, 16),
      );
      expect(
        TownRules.refillEmergency(spent, const LocalDate(2026, 11, 2)),
        spent,
      );
    });
  });

  group('refund', () {
    (TownState, Session) armed() =>
        TownRules.armEmergency(TownState.initial(), _session())!;

    test('an armed pause that was never used comes back', () {
      final (town, session) = armed();
      final done = session.copyWith(state: SessionState.completed);
      expect(TownRules.refundEmergency(town, done).emergencyPauses, 1);
      final gone = session.copyWith(
        state: SessionState.failed,
        outcomeReason: OutcomeReason.abandoned,
      );
      expect(TownRules.refundEmergency(town, gone).emergencyPauses, 1);
    });

    test('a used pause, or one that covered an absence, stays spent', () {
      final (town, session) = armed();
      final used = session.copyWith(
        state: SessionState.completed,
        emergencyArmed: false,
        emergencyUsed: true,
      );
      expect(TownRules.refundEmergency(town, used).emergencyPauses, 0);
      final lost = session.copyWith(
        state: SessionState.failed,
        awayTotal: const Duration(minutes: 11),
        outcomeReason: OutcomeReason.leftTooLong,
      );
      expect(TownRules.refundEmergency(town, lost).emergencyPauses, 0);
    });

    test('a session that never armed changes nothing', () {
      final town = TownState.initial();
      expect(TownRules.refundEmergency(town, _session()), town);
    });
  });

  group('arming', () {
    test('uses up the pause and marks the session', () {
      final (town, session) = TownRules.armEmergency(
        TownState.initial(),
        _session(),
      )!;
      expect(town.emergencyPauses, 0);
      expect(session.emergencyArmed, isTrue);
    });

    test('is refused with none left, twice, away, in a repair', () {
      final none = TownState.initial().copyWith(emergencyPauses: 0);
      expect(TownRules.armEmergency(none, _session()), isNull);
      final armed = TownRules.armEmergency(TownState.initial(), _session())!;
      expect(
        TownRules.armEmergency(armed.$1.copyWith(emergencyPauses: 1), armed.$2),
        isNull,
      );
      final away = SessionEngine.onBackgroundedUnlocked(_session(), _at(5));
      expect(TownRules.armEmergency(TownState.initial(), away), isNull);
      final repair = SessionEngine.startRepair(id: 'r', plot: 1, now: _at(0));
      expect(TownRules.armEmergency(TownState.initial(), repair), isNull);
    });
  });

  group('the longer away window', () {
    Session armed() => _session().copyWith(emergencyArmed: true);

    Session leave(Session s) =>
        SessionEngine.onBackgroundedUnlocked(s, _at(60));

    test('5 minutes away is forgiven, and the pause is spent', () {
      final back = SessionEngine.onForegrounded(leave(armed()), _at(360));
      expect(back.state, SessionState.running);
      expect(back.emergencyArmed, isFalse);
      expect(back.emergencyUsed, isTrue);
      expect(back.passUsed, isFalse);
    });

    test('exactly 10 minutes is forgiven, 10 minutes and a second is not', () {
      final ok = SessionEngine.onForegrounded(leave(armed()), _at(660));
      expect(ok.state, SessionState.running);
      final late = SessionEngine.onForegrounded(leave(armed()), _at(661));
      expect(late.state, SessionState.failed);
      expect(late.outcomeReason, OutcomeReason.leftTooLong);
    });

    test('never coming back: away at 9 minutes, failed at 11', () {
      final at9 = SessionEngine.resolve(leave(armed()), _at(60 + 540));
      expect(at9.state, SessionState.away);
      final at11 = SessionEngine.resolve(leave(armed()), _at(60 + 660));
      expect(at11.state, SessionState.failed);
    });

    test('it works once: the next absence follows the old rules', () {
      var s = SessionEngine.onForegrounded(leave(armed()), _at(360));
      s = SessionEngine.onBackgroundedUnlocked(s, _at(400));
      final back = SessionEngine.onForegrounded(s, _at(400 + 120));
      expect(back.state, SessionState.failed);
    });

    test('without it, 5 minutes away still fails', () {
      final back = SessionEngine.onForegrounded(leave(_session()), _at(360));
      expect(back.state, SessionState.failed);
    });
  });

  test('an armed session keeps its flags through copyWith', () {
    final s = _session().copyWith(emergencyArmed: true);
    expect(s.copyWith(state: SessionState.away).emergencyArmed, isTrue);
  });
}
