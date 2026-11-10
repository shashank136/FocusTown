import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/app.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/testing/fake_lifecycle_source.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
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
          notifierProvider.overrideWithValue(FakeNotifier()),
          lifecycleSourceProvider.overrideWithValue(source),
        ],
        child: const FocusTownApp(),
      ),
    );
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FocusTownApp)),
    );
    SessionState? state() =>
        container.read(focusControllerProvider).value?.active?.state;

    await tester.runAsync(
      () => container.read(focusControllerProvider.notifier).start(25),
    );
    expect(state(), SessionState.running);

    source.emit(BackgroundedEvent(TimeStamp.now(clock)));
    await _settle(tester);
    expect(state(), SessionState.running); // still inside the lock window

    clock.advance(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100)); // the flush timer
    await _settle(tester);
    expect(state(), SessionState.away);
  });
}
