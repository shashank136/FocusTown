import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/local_log.dart';
import 'package:focus_town/platform/notifier.dart' as warnings;
import 'package:focus_town/platform/testing/fake_notifier.dart';

class _ThrowingNotifier extends FakeNotifier {
  @override
  Future<void> scheduleAwayWarnings({
    required bool passAvailable,
    bool emergency = false,
  }) => throw StateError('boom');
}

void main() {
  late FakeClock clock;
  late LocalLog log;

  Future<ProviderContainer> started(warnings.Notifier notifier) async {
    clock = FakeClock();
    log = LocalLog(null, clock);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(notifier),
        localLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(c.dispose);
    await c.read(focusControllerProvider.future);
    await c.read(focusControllerProvider.notifier).start(25);
    return c;
  }

  test('a notifier error writes one line and the session carries on', () async {
    final c = await started(_ThrowingNotifier());
    await c.read(focusControllerProvider.notifier).onBackgroundedUnlocked();
    expect(log.lines, hasLength(1));
    expect(log.lines.single, contains('Notification failed'));
    expect(c.read(focusControllerProvider).requireValue.active, isNotNull);
  });

  test('a wall clock moved 2 hours is logged when the session ends', () async {
    final c = await started(FakeNotifier());
    clock.setWall(clock.nowWall().add(const Duration(hours: 2)));
    await c.read(focusControllerProvider.notifier).abandon();
    expect(
      log.lines.where((l) => l.contains('clock tamper detected')),
      hasLength(1),
    );
  });

  test('an honest session writes nothing', () async {
    final c = await started(FakeNotifier());
    clock.advance(const Duration(minutes: 5));
    await c.read(focusControllerProvider.notifier).abandon();
    expect(log.lines, isEmpty);
  });
}
