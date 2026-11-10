import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/focus_debug_panel.dart';

late FakeClock _clock;
late ValueNotifier<int> _minutes;
int _ticks = 0;

/// Counts how often the panel asks the controller to tick.
class _CountingController extends FocusController {
  @override
  Future<void> tick() {
    _ticks++;
    return super.tick();
  }
}

/// Lets real async work (the in-memory database) finish, then redraws.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}

Future<void> _pump(WidgetTester tester, {int minutes = 10}) async {
  _clock = FakeClock();
  _minutes = ValueNotifier(minutes);
  _ticks = 0;
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(FakeNotifier()),
        focusControllerProvider.overrideWith(_CountingController.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ValueListenableBuilder<int>(
              valueListenable: _minutes,
              builder: (_, m, _) => FocusDebugPanel(minutes: m),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await _settle(tester);
}

/// Moves the fake clock and lets the panel's 1 s timer tick once.
Future<void> _advance(WidgetTester tester, Duration d) async {
  _clock.advance(d);
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);
}

Future<void> _dismissDialog(WidgetTester tester) async {
  if (find.text('OK').evaluate().isEmpty) return;
  await _tap(tester, 'OK');
}

Future<void> _setMinutes(WidgetTester tester, int m) async {
  _minutes.value = m;
  await tester.pump();
}

bool _startEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
        .onPressed !=
    null;

/// Leave, then come back after 90 s without the timer noticing first.
Future<void> _failSession(WidgetTester tester) async {
  await _tap(tester, 'Start');
  await _tap(tester, 'Leave');
  _clock.advance(const Duration(seconds: 90));
  await _tap(tester, 'Return');
  await _dismissDialog(tester);
}

Future<void> _completeHut(WidgetTester tester) async {
  await _tap(tester, 'Start');
  await _advance(tester, const Duration(minutes: 10));
  await _dismissDialog(tester);
}

void main() {
  testWidgets('Start makes a running session of the slider minutes', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Planned: 10 min'), findsOneWidget);
    expect(find.text('Progress: 0%'), findsOneWidget);
  });

  testWidgets('Leave then Return after 5s keeps running, no pass', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Leave');
    expect(find.text('State: away'), findsOneWidget);
    _clock.advance(const Duration(seconds: 5));
    await _tap(tester, 'Return');
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Pass used: false'), findsOneWidget);
  });

  testWidgets('Leave then Return after 30s uses the pass', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Leave');
    _clock.advance(const Duration(seconds: 30));
    await _tap(tester, 'Return');
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Pass used: true'), findsOneWidget);
  });

  testWidgets('Leave then Return after 90s fails and shows the dialog', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Leave');
    _clock.advance(const Duration(seconds: 90));
    await _tap(tester, 'Return');
    expect(find.text('State: -'), findsOneWidget);
    expect(find.text('Session failed'), findsOneWidget);
    expect(find.text('Workers lost: 1'), findsOneWidget);
  });

  testWidgets('a session completes by itself through the tick timer', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _advance(tester, const Duration(minutes: 10));
    expect(find.text('Session completed'), findsOneWidget);
    expect(find.text('Workers gained: 1'), findsOneWidget);
    expect(find.text('State: -'), findsOneWidget);
  });

  testWidgets('Lock for 5 minutes does not change the state', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    _clock.advance(const Duration(minutes: 5));
    await _tap(tester, 'Lock');
    await tester.pump(const Duration(seconds: 1)); // display refresh
    expect(find.text('State: running'), findsOneWidget);
    expect(find.text('Progress: 50%'), findsOneWidget);
  });

  testWidgets('Abandon fails the session', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _tap(tester, 'Abandon');
    expect(find.text('State: -'), findsOneWidget);
    expect(find.text('Session failed'), findsOneWidget);
    expect(find.text('Workers: 2'), findsOneWidget);
  });

  testWidgets('result dialog appears once and dismissing clears the result', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'Start');
    await _advance(tester, const Duration(minutes: 10));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FocusDebugPanel)),
    );
    expect(find.text('Session completed'), findsOneWidget);
    expect(
      container.read(focusControllerProvider).requireValue.lastResult,
      isNotNull,
    );
    await _tap(tester, 'OK');
    expect(find.text('Session completed'), findsNothing);
    expect(
      container.read(focusControllerProvider).requireValue.lastResult,
      isNull,
    );
  });

  testWidgets('the tick timer only asks for ticks while a session is active', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_ticks, 0);
    await _tap(tester, 'Start');
    await tester.pump(const Duration(seconds: 3));
    expect(_ticks, greaterThanOrEqualTo(3));
    await _tap(tester, 'Abandon');
    await _dismissDialog(tester);
    final after = _ticks;
    await tester.pump(const Duration(seconds: 3));
    expect(_ticks, after);
  });

  group('town', () {
    testWidgets('initial town: 3 workers, 1/6 plots, empty queue', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Workers: 3'), findsOneWidget);
      expect(find.text('Plots: 1/6'), findsOneWidget);
      expect(find.text('Queue: 0'), findsOneWidget);
      expect(find.text('Recovery: false'), findsOneWidget);
      expect(find.text('house complete plot 0'), findsOneWidget);
    });

    testWidgets('completing a 10 minute hut: 4 workers, 2 buildings', (
      tester,
    ) async {
      await _pump(tester);
      await _completeHut(tester);
      expect(find.text('Workers: 4'), findsOneWidget);
      expect(find.text('Plots: 2/7'), findsOneWidget);
      expect(find.text('hut complete plot 1'), findsOneWidget);
    });

    testWidgets('extra ticks after completion do not apply it twice', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, 'Start');
      await _advance(tester, const Duration(minutes: 12));
      await _dismissDialog(tester);
      await _advance(tester, const Duration(seconds: 5));
      expect(find.text('Workers: 4'), findsOneWidget);
      expect(find.text('Plots: 2/7'), findsOneWidget);
    });

    testWidgets('failing a 25 minute house: 1 worker and a ruin', (
      tester,
    ) async {
      await _pump(tester, minutes: 25);
      await _failSession(tester);
      expect(find.text('Workers: 1'), findsOneWidget);
      expect(find.text('house ruin plot 1'), findsOneWidget);
    });

    testWidgets('castle at 3 workers: Start disabled with the reason', (
      tester,
    ) async {
      await _pump(tester, minutes: 95);
      expect(_startEnabled(tester), isFalse);
      expect(find.text('Needs 8 workers, you have 3'), findsOneWidget);
    });

    testWidgets('losing all workers enters recovery: huts only', (
      tester,
    ) async {
      await _pump(tester, minutes: 25);
      await _failSession(tester); // 3 -> 1 worker
      await _setMinutes(tester, 10);
      await _failSession(tester); // hut risks 1 -> 0 workers
      expect(find.text('Workers: 0'), findsOneWidget);
      expect(find.text('Recovery: true'), findsOneWidget);
      expect(_startEnabled(tester), isTrue);

      await _setMinutes(tester, 20);
      expect(_startEnabled(tester), isTrue);
      await _setMinutes(tester, 25);
      expect(_startEnabled(tester), isFalse);
      expect(find.text('Recovery mode: huts only'), findsOneWidget);
    });

    testWidgets('a recovery hut that fails costs no workers', (tester) async {
      await _pump(tester, minutes: 25);
      await _failSession(tester);
      await _setMinutes(tester, 10);
      await _failSession(tester);
      await _failSession(tester); // recovery hut, 0 assigned
      expect(find.text('Workers: 0'), findsOneWidget);
    });
  });

  group('progression', () {
    testWidgets('initial: streak 0, camp, 0 xp, 0%', (tester) async {
      await _pump(tester);
      expect(find.text('Streak: 0'), findsOneWidget);
      expect(find.text('Level: camp'), findsOneWidget);
      expect(find.text('XP: 0'), findsOneWidget);
      expect(find.text('Level progress: 0%'), findsOneWidget);
    });

    testWidgets('a 10 minute completion: streak 1, xp 10, 7 plots', (
      tester,
    ) async {
      await _pump(tester);
      await _completeHut(tester);
      expect(find.text('Streak: 1'), findsOneWidget);
      expect(find.text('XP: 10'), findsOneWidget);
      expect(find.text('Plots: 2/7'), findsOneWidget);
      expect(find.text('Level: camp'), findsOneWidget);
      expect(find.text('Level progress: 3%'), findsOneWidget);
    });

    testWidgets('next day then another completion: streak 2, 8 plots', (
      tester,
    ) async {
      await _pump(tester);
      await _completeHut(tester);
      await _advance(tester, const Duration(days: 1));
      await _completeHut(tester);
      expect(find.text('Streak: 2'), findsOneWidget);
      expect(find.text('XP: 20'), findsOneWidget);
      expect(find.text('Plots: 3/8'), findsOneWidget);
    });

    testWidgets('a second completion the same day grants no extra plot', (
      tester,
    ) async {
      await _pump(tester);
      await _completeHut(tester);
      await _completeHut(tester);
      expect(find.text('Streak: 1'), findsOneWidget);
      expect(find.text('Plots: 3/7'), findsOneWidget);
    });

    testWidgets('two missed days show streak 0', (tester) async {
      await _pump(tester);
      await _completeHut(tester);
      await _advance(tester, const Duration(days: 1));
      expect(find.text('Streak: 1'), findsOneWidget);
      await _advance(tester, const Duration(days: 1));
      expect(find.text('Streak: 0'), findsOneWidget);
    });

    testWidgets('a failed session changes no progression', (tester) async {
      await _pump(tester);
      await _failSession(tester);
      expect(find.text('Streak: 0'), findsOneWidget);
      expect(find.text('XP: 0'), findsOneWidget);
      expect(find.text('Plots: 2/6'), findsOneWidget);
    });
  });
}
