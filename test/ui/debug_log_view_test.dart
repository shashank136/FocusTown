import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/local_log.dart';
import 'package:focus_town/ui/debug_log_view.dart';

void main() {
  late FakeClock clock;
  late LocalLog log;
  late AppDatabase db;

  testWidgets('shows what is in the log, newest on top', (tester) async {
    clock = FakeClock(start: DateTime(2026, 3, 1, 9));
    log = LocalLog(null, clock)
      ..write('first')
      ..write('second');
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          databaseProvider.overrideWithValue(db),
          localLogProvider.overrideWithValue(log),
        ],
        child: const MaterialApp(home: Scaffold(body: DebugLogView())),
      ),
    );
    final first = tester.getTopLeft(find.textContaining('first')).dy;
    final second = tester.getTopLeft(find.textContaining('second')).dy;
    expect(second, lessThan(first));
  });

  testWidgets('Copy log puts every line on the clipboard', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    clock = FakeClock();
    log = LocalLog(null, clock)
      ..write('one')
      ..write('two');
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          databaseProvider.overrideWithValue(db),
          localLogProvider.overrideWithValue(log),
        ],
        child: const MaterialApp(home: Scaffold(body: DebugLogView())),
      ),
    );
    await tester.tap(find.text('Copy log'));
    await tester.pump();
    expect(copied, log.lines.join('\n'));
  });

  testWidgets('the stats card shows the numbers', (tester) async {
    clock = FakeClock(start: DateTime(2026, 3, 1, 9));
    log = LocalLog(null, clock);
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> add(String id, SessionState s, DateTime at) => db
        .into(db.sessions)
        .insert(
          sessionToRow(
            Session(
              id: id,
              plannedMinutes: 25,
              tier: BuildingTier.house,
              workersAssigned: 1,
              state: s,
              startedAt: TimeStamp(at, Duration.zero),
            ),
          ),
        );
    await tester.runAsync(() async {
      await add('a', SessionState.completed, DateTime(2026, 3, 1, 9));
      await add('b', SessionState.completed, DateTime(2026, 3, 1, 12));
      await add('c', SessionState.completed, DateTime(2026, 3, 8, 8));
      await add('d', SessionState.failed, DateTime(2026, 3, 8, 9));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: Scaffold(body: BetaStatsCard())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Sessions started: 4'), findsOneWidget);
    expect(find.text('Completed: 3'), findsOneWidget);
    expect(find.text('Failed: 1'), findsOneWidget);
    expect(find.text('Completion rate: 75%'), findsOneWidget);
    expect(find.text('Days active: 2'), findsOneWidget);
    expect(find.text('First open: 2026-03-01'), findsOneWidget);
    expect(find.text('Returned after day 7: yes'), findsOneWidget);
  });
}
