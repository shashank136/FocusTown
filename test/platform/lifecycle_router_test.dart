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
import 'package:focus_town/platform/testing/fake_notifier.dart';

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
        notifierProvider.overrideWithValue(FakeNotifier()),
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
      clock.advance(const Duration(milliseconds: 600));
      await router.flushExpired();
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
      clock.advance(const Duration(milliseconds: 600));
      await router.flushExpired();
      expect(active()!.state, SessionState.away);
    },
  );

  test(
    'a call that never reports its end stops counting after 3 hours',
    () async {
      await controller.start(25);
      await send(CallStartedEvent(now()));
      clock.advance(const Duration(hours: 3, minutes: 1));
      await send(BackgroundedEvent(now()));
      clock.advance(const Duration(milliseconds: 600));
      await router.flushExpired();
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

  group('lock window', () {
    TimeStamp after(TimeStamp t, int ms) => TimeStamp(
      t.wall.add(Duration(milliseconds: ms)),
      t.uptime + Duration(milliseconds: ms),
    );

    Future<void> flushAfter(int ms) async {
      clock.advance(Duration(milliseconds: ms));
      await router.flushExpired();
      await router.idle;
    }

    test('locked 200 ms after backgrounded never goes away', () async {
      await controller.start(25);
      final t = now();
      await send(BackgroundedEvent(t));
      await send(LockedEvent(after(t, 200)));
      final s = active()!;
      expect(s.state, SessionState.running);
      expect(s.leftAt, isNull);
      expect(s.passUsed, isFalse);
    });

    test(
      'locked 600 ms after backgrounded goes away at the pending time',
      () async {
        await controller.start(25);
        final t = now();
        await send(BackgroundedEvent(t));
        await send(LockedEvent(after(t, 600)));
        expect(active()!.state, SessionState.away);
        expect(active()!.leftAt, t);
      },
    );

    test('flushExpired after 600 ms forwards the pending event', () async {
      await controller.start(25);
      final t = now();
      await send(BackgroundedEvent(t));
      expect(active()!.state, SessionState.running);
      await flushAfter(600);
      expect(active()!.state, SessionState.away);
      expect(active()!.leftAt, t);
    });

    test('flushExpired after 400 ms keeps it pending', () async {
      await controller.start(25);
      await send(BackgroundedEvent(now()));
      await flushAfter(400);
      expect(active()!.state, SessionState.running);
    });

    test('foregrounded within 300 ms cancels it with no pass', () async {
      await controller.start(25);
      final t = now();
      await send(BackgroundedEvent(t));
      await send(ForegroundedEvent(after(t, 300)));
      expect(active()!.state, SessionState.running);
      expect(active()!.passUsed, isFalse);
      await flushAfter(1000);
      expect(active()!.state, SessionState.running);
    });

    test(
      'foregrounded after the window forwards the pending event first',
      () async {
        await controller.start(25);
        final t = now();
        await send(BackgroundedEvent(t));
        clock.advance(const Duration(seconds: 30));
        await send(ForegroundedEvent(now()));
        expect(active()!.state, SessionState.running);
        expect(active()!.passUsed, isTrue);
      },
    );

    test(
      'locked just BEFORE backgrounded (the real iPhone order) is a lock',
      () async {
        await controller.start(25);
        final t = now();
        await send(LockedEvent(t));
        await send(LockedEvent(after(t, 63)));
        await send(BackgroundedEvent(after(t, 76)));
        // Three minutes later the user unlocks into the app.
        clock.advance(const Duration(minutes: 3));
        await send(ForegroundedEvent(after(t, 188000)));
        await send(UnlockedEvent(after(t, 188003)));
        final s = active()!;
        expect(s.state, SessionState.running);
        expect(s.passUsed, isFalse);
        expect(s.awayTotal, Duration.zero);
      },
    );

    test(
      'a background long after a lock and unlock is a real switch',
      () async {
        await controller.start(25);
        final t = now();
        await send(LockedEvent(t));
        await send(UnlockedEvent(after(t, 5000)));
        await send(BackgroundedEvent(after(t, 10000)));
        clock.advance(const Duration(seconds: 11));
        await router.flushExpired();
        await router.idle;
        expect(active()!.state, SessionState.away);
      },
    );

    test('callStarted drops the pending event', () async {
      await controller.start(25);
      final t = now();
      await send(BackgroundedEvent(t));
      await send(CallStartedEvent(after(t, 100)));
      await flushAfter(1000);
      expect(active()!.state, SessionState.running);
    });

    test('backgrounded during a call is never pending', () async {
      await controller.start(25);
      await send(CallStartedEvent(now()));
      await send(BackgroundedEvent(now()));
      await flushAfter(1000);
      expect(active()!.state, SessionState.running);
    });

    test('two backgrounded events in a row keep the earlier time', () async {
      await controller.start(25);
      final t = now();
      await send(BackgroundedEvent(t));
      await send(BackgroundedEvent(after(t, 100)));
      await flushAfter(600);
      expect(active()!.leftAt, t);
    });

    test('flush and events with no active session are no-ops', () async {
      await send(BackgroundedEvent(now()));
      await flushAfter(1000);
      await send(LockedEvent(now()));
      expect(active(), isNull);
    });
  });
}
