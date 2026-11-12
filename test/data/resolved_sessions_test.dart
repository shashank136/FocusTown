import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  setUp(() {
    clock = FakeClock(start: DateTime(2026, 11, 11, 9));
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Session at(String id, SessionState state, DateTime wall) => Session(
    id: id,
    plannedMinutes: 25,
    tier: BuildingTier.house,
    workersAssigned: 2,
    state: state,
    startedAt: TimeStamp(wall, Duration.zero),
  );

  Future<void> insert(Session s) =>
      db.into(db.sessions).insert(sessionToRow(s));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(FakeNotifier()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('only finished sessions come back, oldest first', () async {
    await insert(at('b', SessionState.completed, DateTime(2026, 11, 10)));
    await insert(at('a', SessionState.failed, DateTime(2026, 11, 9)));
    await insert(at('run', SessionState.running, DateTime(2026, 11, 11)));
    final repo = container().read(townRepositoryProvider);
    expect((await repo.resolvedSessions()).map((s) => s.id), ['a', 'b']);
  });

  test('the stats provider counts what was stored', () async {
    await insert(at('a', SessionState.completed, DateTime(2026, 11, 11, 8)));
    final stats = await container().read(focusStatsProvider.future);
    expect(stats.minutesPerDay.last, 25);
  });

  test(
    'a session finished while the stats are open shows up on reread',
    () async {
      final c = container();
      await c.read(focusControllerProvider.future);
      final n = c.read(focusControllerProvider.notifier);
      expect((await c.read(focusStatsProvider.future)).isEmpty, isTrue);
      await n.start(25);
      clock.advance(const Duration(minutes: 26));
      await n.tick();
      expect((await c.read(focusStatsProvider.future)).minutesPerDay.last, 25);
    },
  );
}
