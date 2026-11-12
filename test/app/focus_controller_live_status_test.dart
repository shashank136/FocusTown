import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/live_status.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;
late FakeLiveStatusSink _sink;

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
      liveStatusSinkProvider.overrideWithValue(_sink),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() {
    _clock = FakeClock(start: DateTime(2026, 11, 12, 9));
    _db = AppDatabase(NativeDatabase.memory());
    _sink = FakeLiveStatusSink();
    addTearDown(_db.close);
  });

  test('a started session is shown with its planned end', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    await c.read(focusControllerProvider.notifier).start(25);
    expect(_sink.shown, [
      LiveStatus(
        endsAt: DateTime(2026, 11, 12, 9, 25),
        title: 'house',
        away: false,
      ),
    ]);
  });

  test('leaving shows away, coming back shows running again', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    await n.start(25);
    await n.onBackgroundedUnlocked();
    _clock.advance(const Duration(seconds: 5));
    await n.onForegrounded();
    expect(_sink.shown.map((s) => s.away), [false, true, false]);
  });

  test('finishing or abandoning removes it', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    await n.start(25);
    await n.abandon();
    expect(_sink.ended, 1);
  });

  test('a repair is titled repair', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    await n.start(25);
    await n.abandon();
    _clock.advance(const Duration(minutes: 1));
    await n.startRepair(1);
    expect(_sink.shown.last.title, 'repair');
  });

  test('a session found on launch is shown again', () async {
    final first = _container();
    await first.read(focusControllerProvider.future);
    await first.read(focusControllerProvider.notifier).start(25);
    _sink.shown.clear();
    final second = _container();
    await second.read(focusControllerProvider.future);
    expect(_sink.shown, hasLength(1));
  });

  test('a failing sink never changes the session', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    _sink.failing = true;
    final n = c.read(focusControllerProvider.notifier);
    await n.start(25);
    expect(c.read(focusControllerProvider).requireValue.active, isNotNull);
    await n.abandon();
    expect(c.read(focusControllerProvider).requireValue.active, isNull);
  });
}
