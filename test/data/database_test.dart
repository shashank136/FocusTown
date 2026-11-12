import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schemaVersion is 9', () {
    expect(db.schemaVersion, 9);
  });

  test('towns row round trips and onboardingDone defaults to false', () async {
    await db
        .into(db.towns)
        .insert(
          TownsCompanion.insert(
            id: const Value(1),
            workerCount: 3,
            plotsUnlocked: 6,
            xp: 0,
            streakCount: 0,
            inRecoveryMode: false,
            createdAt: 1000,
          ),
        );
    final row = await db.select(db.towns).getSingle();
    expect(row.workerCount, 3);
    expect(row.plotsUnlocked, 6);
    expect(row.lastStreakDate, isNull);
    expect(row.lastPlotGrantDate, isNull);
    expect(row.onboardingDone, isFalse);
    expect(row.createdAt, 1000);
  });

  test('buildings row round trips with nullable plot and session', () async {
    await db
        .into(db.buildings)
        .insert(
          BuildingsCompanion.insert(
            id: 'b1',
            tier: 'hut',
            status: 'queued',
            completedAt: 5,
          ),
        );
    final row = await db.select(db.buildings).getSingle();
    expect(row.id, 'b1');
    expect(row.status, 'queued');
    expect(row.plotIndex, isNull);
    expect(row.sessionId, isNull);
  });

  test('sessions row round trips with nullable away and outcome', () async {
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: 's1',
            plannedMinutes: 25,
            tier: 'house',
            workersAssigned: 2,
            state: 'running',
            startedAtWall: 100,
            startedAtUptimeMs: 50,
            awayTotalMs: 0,
            passUsed: false,
          ),
        );
    final row = await db.select(db.sessions).getSingle();
    expect(row.plannedMinutes, 25);
    expect(row.startedAtUptimeMs, 50);
    expect(row.leftAtWall, isNull);
    expect(row.leftAtUptimeMs, isNull);
    expect(row.outcomeReason, isNull);
    expect(row.resolvedAt, isNull);
  });
}
