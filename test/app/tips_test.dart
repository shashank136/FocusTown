import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/tips.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/tip.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeNotifier _notifier;

Future<ProviderContainer> _container() async {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(FakeClock()),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(_notifier),
    ],
  );
  addTearDown(c.dispose);
  await c.read(townRepositoryProvider).loadOrCreate();
  return c;
}

void main() {
  setUp(() {
    _db = AppDatabase(NativeDatabase.memory());
    _notifier = FakeNotifier();
    addTearDown(_db.close);
  });

  test('every tip shows once, then never again', () async {
    final c = await _container();
    final tips = c.read(tipsProvider.notifier);
    for (final tip in Tip.values) {
      expect(await tips.shouldShow(tip), isTrue);
      await tips.markShown(tip);
      expect(await tips.shouldShow(tip), isFalse);
    }
  });

  test('flags survive a new container on the same database', () async {
    final c = await _container();
    await c.read(tipsProvider.notifier).markShown(Tip.pass);
    final again = await _container();
    final tips = again.read(tipsProvider.notifier);
    expect(await tips.shouldShow(Tip.pass), isFalse);
    expect(await tips.shouldShow(Tip.growth), isTrue);
  });

  group('the notification note', () {
    Future<bool> shows(ProviderContainer c) =>
        c.read(notificationNoteProvider.future);

    test('not before onboarding is done', () async {
      final c = await _container();
      expect(await shows(c), isFalse);
    });

    test('shows with no permission after onboarding', () async {
      final c = await _container();
      await c.read(townRepositoryProvider).setOnboardingDone();
      expect(await shows(c), isTrue);
    });

    test('not when permission is granted', () async {
      _notifier = FakeNotifier()..permissionGranted = true;
      final c = await _container();
      await c.read(townRepositoryProvider).setOnboardingDone();
      expect(await shows(c), isFalse);
    });

    test('not again after it was dismissed', () async {
      final c = await _container();
      await c.read(townRepositoryProvider).setOnboardingDone();
      await c.read(tipsProvider.notifier).markShown(Tip.notificationNote);
      c.invalidate(notificationNoteProvider);
      expect(await shows(c), isFalse);
    });
  });
}
