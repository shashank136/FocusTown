import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeNotifier _notifier;

Future<ProviderContainer> _loaded() async {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(FakeClock()),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(_notifier),
    ],
  );
  addTearDown(c.dispose);
  await c.read(focusControllerProvider.future);
  return c;
}

int _asked() => _notifier.calls.where((c) => c == 'requestPermission').length;

void main() {
  setUp(() {
    _db = AppDatabase(NativeDatabase.memory());
    _notifier = FakeNotifier();
    addTearDown(_db.close);
  });

  test('finish asks for notification permission once, even twice', () async {
    final c = await _loaded();
    final o = c.read(onboardingControllerProvider);
    await o.finish();
    await o.finish();
    expect(_asked(), 1);
  });

  test('a denied permission still starts the first hut', () async {
    _notifier = FakeNotifier(grants: false);
    final c = await _loaded();
    await c.read(onboardingControllerProvider).finish();
    final active = c.read(focusControllerProvider).requireValue.active;
    expect(active, isNotNull);
    expect(active!.tier, BuildingTier.hut);
    expect(active.plannedMinutes, 10);
    expect(active.workersAssigned, 1);
  });

  test('finish marks onboarding done', () async {
    final c = await _loaded();
    expect(await c.read(townRepositoryProvider).isOnboardingDone(), isFalse);
    await c.read(onboardingControllerProvider).finish();
    expect(await c.read(townRepositoryProvider).isOnboardingDone(), isTrue);
    expect(await c.read(onboardingDoneProvider.future), isTrue);
  });
}
