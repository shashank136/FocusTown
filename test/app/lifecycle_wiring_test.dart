import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/app.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/testing/fake_lifecycle_source.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}

void main() {
  testWidgets('a backgrounded event becomes away after the lock window', (
    tester,
  ) async {
    final clock = FakeClock();
    final source = FakeLifecycleSource();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          databaseProvider.overrideWithValue(db),
          lifecycleSourceProvider.overrideWithValue(source),
        ],
        child: const FocusTownApp(),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();
    await _settle(tester);
    expect(find.text('State: running'), findsOneWidget);

    source.emit(BackgroundedEvent(TimeStamp.now(clock)));
    await _settle(tester);
    expect(find.text('State: running'), findsOneWidget);

    clock.advance(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 1)); // panel display refresh
    expect(find.text('State: away'), findsOneWidget);
  });
}
