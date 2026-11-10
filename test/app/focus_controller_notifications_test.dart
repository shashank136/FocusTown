import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/notifier.dart' as warnings;
import 'package:focus_town/platform/testing/fake_notifier.dart';

/// A notifier that fails on every call.
class _ThrowingNotifier implements warnings.Notifier {
  @override
  Future<bool> requestPermission() => throw StateError('boom');

  @override
  Future<bool> hasPermission() => throw StateError('boom');

  @override
  Future<void> scheduleAwayWarnings({required bool passAvailable}) =>
      throw StateError('boom');

  @override
  Future<void> cancelAwayWarnings() => throw StateError('boom');
}

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FakeNotifier fake;

  setUp(() {
    clock = FakeClock();
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    fake = FakeNotifier();
  });

  ProviderContainer container(warnings.Notifier notifier) {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(notifier),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<FocusController> started(
    ProviderContainer c, {
    int minutes = 25,
  }) async {
    await c.read(focusControllerProvider.future);
    final controller = c.read(focusControllerProvider.notifier);
    await controller.start(minutes);
    return controller;
  }

  test('leaving with the pass available schedules with the pass', () async {
    final controller = await started(container(fake));
    await controller.onBackgroundedUnlocked();
    expect(fake.calls, ['schedule(passAvailable: true)']);
  });

  test('leaving after the pass was used schedules without the pass', () async {
    final controller = await started(container(fake));
    await controller.onBackgroundedUnlocked();
    clock.advance(const Duration(seconds: 30));
    await controller.onForegrounded();
    fake.calls.clear();
    await controller.onBackgroundedUnlocked();
    expect(fake.calls, ['schedule(passAvailable: false)']);
  });

  test('returning cancels the warnings', () async {
    final controller = await started(container(fake));
    await controller.onBackgroundedUnlocked();
    fake.calls.clear();
    clock.advance(const Duration(seconds: 5));
    await controller.onForegrounded();
    expect(fake.calls, ['cancel']);
  });

  test('locking while away cancels the warnings', () async {
    final controller = await started(container(fake));
    await controller.onBackgroundedUnlocked();
    fake.calls.clear();
    await controller.onLocked();
    expect(fake.calls, ['cancel']);
  });

  test('a session that completes cancels the warnings', () async {
    final controller = await started(container(fake), minutes: 10);
    fake.calls.clear();
    clock.advance(const Duration(minutes: 10));
    await controller.tick();
    expect(fake.calls, ['cancel']);
  });

  test('a session that fails cancels the warnings once', () async {
    final controller = await started(container(fake));
    await controller.onBackgroundedUnlocked();
    fake.calls.clear();
    clock.advance(const Duration(seconds: 90));
    await controller.onForegrounded();
    expect(fake.calls, ['cancel']);
  });

  test('an abandoned session cancels the warnings', () async {
    final controller = await started(container(fake));
    fake.calls.clear();
    await controller.abandon();
    expect(fake.calls, ['cancel']);
  });

  test('resuming a still-running session cancels stale warnings', () async {
    await started(container(fake));
    clock.advance(const Duration(minutes: 1));
    final second = FakeNotifier();
    await container(second).read(focusControllerProvider.future);
    expect(second.calls, ['cancel']);
  });

  test('a throwing notifier does not change any outcome', () async {
    Future<FocusState> run(warnings.Notifier notifier) async {
      clock = FakeClock();
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = container(notifier);
      final controller = await started(c);
      await controller.onBackgroundedUnlocked();
      clock.advance(const Duration(seconds: 30));
      await controller.onForegrounded(); // uses the pass
      await controller.onLocked();
      await controller.onBackgroundedUnlocked();
      clock.advance(const Duration(seconds: 120));
      await controller.onForegrounded(); // fails
      return c.read(focusControllerProvider).requireValue;
    }

    final normal = await run(FakeNotifier());
    final broken = await run(_ThrowingNotifier());
    expect(normal.lastResult, isNotNull);
    expect(broken, normal);
  });
}
