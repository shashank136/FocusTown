import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';

import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  Future<AppDatabase> migrate(int from) async {
    final schema = await verifier.schemaAt(from);
    schema.rawDatabase
      ..execute('''
        INSERT INTO towns (id, worker_count, plots_unlocked, xp, streak_count,
          in_recovery_mode, onboarding_done, created_at)
        VALUES (1, 4, 7, 30, 2, 0, 1, 5000)
      ''')
      ..execute('''
        INSERT INTO buildings (id, tier, status, plot_index, completed_at)
        VALUES ('b1', 'hut', 'complete', 0, 6000)
      ''')
      ..execute('''
        INSERT INTO sessions (id, planned_minutes, tier, workers_assigned,
          state, started_at_wall, started_at_uptime_ms, away_total_ms,
          pass_used)
        VALUES ('s1', 10, 'hut', 1, 'running', 1000, 2000, 0, 0)
      ''');
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);
    return db;
  }

  for (final from in [1, 2, 3, 4, 5, 6, 7]) {
    test('v$from to v8 keeps the town, building and session', () async {
      final db = await migrate(from);
      final town = await db.select(db.towns).getSingle();
      expect(town.workerCount, 4);
      expect(town.plotsUnlocked, 7);
      expect(town.xp, 30);
      expect(town.onboardingDone, isTrue);
      expect(town.lastDurationMinutes, 25);
      expect(town.tipPassShown, isFalse);
      expect(town.tipGrowthShown, isFalse);
      expect(town.tipRecoveryShown, isFalse);
      expect(town.notificationNoteShown, isFalse);
      expect(town.emergencyPauses, 1);
      expect(town.emergencyWeek, isNull);
      expect(town.parcels, '');
      final building = await db.select(db.buildings).getSingle();
      expect(building.id, 'b1');
      expect(building.completedAt, 6000);
      expect(building.look, isNull);
      final session = await db.select(db.sessions).getSingle();
      expect(session.id, 's1');
      expect(session.plannedMinutes, 10);
      expect(session.plotIndex, isNull);
      expect(session.repairPlotIndex, isNull);
      expect(session.land, isNull);
      expect(session.look, isNull);
      expect(session.emergencyArmed, isFalse);
      expect(session.emergencyUsed, isFalse);
    });
  }
}
