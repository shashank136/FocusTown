import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/testing/fake_lifecycle_source.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/event_log_panel.dart';

TimeStamp _at(DateTime wall) => TimeStamp(wall, Duration.zero);

void main() {
  test(
    '25 events through the router keep the newest 20, newest first',
    () async {
      final source = FakeLifecycleSource();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FakeClock()),
          databaseProvider.overrideWithValue(db),
          notifierProvider.overrideWithValue(FakeNotifier()),
          lifecycleSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      container.read(lifecycleRouterProvider);
      final events = [
        for (var i = 0; i < 25; i++)
          UnlockedEvent(_at(DateTime(2026, 1, 1, 9, 0, i))),
      ]..forEach(source.emit);
      await Future<void>.delayed(Duration.zero);
      await container.read(lifecycleRouterProvider).idle;
      final log = container.read(eventLogProvider);
      expect(log, hasLength(20));
      expect(log.first, events.last);
      expect(log.last, events[5]);
    },
  );

  Future<void> pump(WidgetTester tester, FakeLifecycleSource source) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(FakeClock()),
            lifecycleSourceProvider.overrideWithValue(source),
          ],
          child: const MaterialApp(home: Scaffold(body: EventLogPanel())),
        ),
      );

  testWidgets('labels a non-native source as fallback', (tester) async {
    await pump(tester, FakeLifecycleSource());
    expect(find.text('Event log (fallback)'), findsOneWidget);
  });

  testWidgets('labels a native source as native', (tester) async {
    await pump(tester, FakeLifecycleSource(isNative: true));
    expect(find.text('Event log (native)'), findsOneWidget);
  });

  testWidgets('rows show time with milliseconds and the event name', (
    tester,
  ) async {
    await pump(tester, FakeLifecycleSource());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EventLogPanel)),
    );
    container.read(eventLogProvider.notifier)
      ..add(LockedEvent(_at(DateTime(2026, 1, 1, 9, 5, 7, 42))))
      ..add(ForegroundedEvent(_at(DateTime(2026, 1, 1, 23, 59, 1, 5))));
    await tester.pump();
    expect(find.text('09:05:07.042 locked'), findsOneWidget);
    expect(find.text('23:59:01.005 foregrounded'), findsOneWidget);
  });
}
