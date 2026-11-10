import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/lifecycle_router.dart';
import 'package:focus_town/platform/testing/fake_lifecycle_source.dart';

void main() {
  late FakeClock clock;
  late ProviderContainer container;
  late FocusController controller;
  late FakeLifecycleSource source;
  late LifecycleRouter router;
  late List<LifecycleEvent> logged;

  setUp(() async {
    clock = FakeClock();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    await container.read(focusControllerProvider.future);
    controller = container.read(focusControllerProvider.notifier);
    source = FakeLifecycleSource();
    logged = [];
    router = LifecycleRouter(source, controller, clock, onEvent: logged.add)
      ..start();
    addTearDown(() async {
      await router.dispose();
      await source.dispose();
    });
  });

  TimeStamp now() => TimeStamp.now(clock);
  Session? active() => container.read(focusControllerProvider).value?.active;

  Future<void> send(LifecycleEvent e) async {
    source.emit(e);
    await Future<void>.delayed(Duration.zero);
    await router.idle;
  }

  test('locked leaves a running session unchanged', () async {
    await controller.start(25);
    final before = active();
    await send(LockedEvent(now()));
    expect(active(), before);
  });

  test('callStarted leaves a running session unchanged', () async {
    await controller.start(25);
    final before = active();
    await send(CallStartedEvent(now()));
    expect(active(), before);
  });

  test(
    'backgrounded makes it away with leftAt = the event timestamp',
    () async {
      await controller.start(25);
      clock.advance(const Duration(seconds: 3));
      final at = now();
      clock.advance(const Duration(seconds: 2));
      await send(BackgroundedEvent(at));
      expect(active()!.state, SessionState.away);
      expect(active()!.leftAt, at);
    },
  );

  test('foregrounded 5 s later returns to running', () async {
    await controller.start(25);
    await send(BackgroundedEvent(now()));
    clock.advance(const Duration(seconds: 5));
    await send(ForegroundedEvent(now()));
    expect(active()!.state, SessionState.running);
    expect(active()!.passUsed, isFalse);
  });

  test('unlocked does nothing', () async {
    await controller.start(25);
    final before = active();
    await send(UnlockedEvent(now()));
    expect(active(), before);
  });

  test(
    'backgrounded during a call is ignored; after the call it counts',
    () async {
      await controller.start(25);
      await send(CallStartedEvent(now()));
      await send(BackgroundedEvent(now()));
      expect(active()!.state, SessionState.running);
      await send(CallEndedEvent(now()));
      await send(BackgroundedEvent(now()));
      expect(active()!.state, SessionState.away);
    },
  );

  test('events with no active session are no-ops and do not throw', () async {
    await send(LockedEvent(now()));
    await send(BackgroundedEvent(now()));
    await send(ForegroundedEvent(now()));
    await send(CallStartedEvent(now()));
    expect(active(), isNull);
  });

  test('onEvent sees every event, including ignored ones', () async {
    final events = [
      LockedEvent(now()),
      UnlockedEvent(now()),
      CallEndedEvent(now()),
    ];
    for (final e in events) {
      await send(e);
    }
    expect(logged, events);
  });

  test('no events are handled after dispose', () async {
    await controller.start(25);
    await router.dispose();
    await send(BackgroundedEvent(now()));
    expect(active()!.state, SessionState.running);
  });
}
