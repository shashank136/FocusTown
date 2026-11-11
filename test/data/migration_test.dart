import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';

import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 to v2 keeps a stored session and adds a null plot', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute('''
      INSERT INTO sessions (id, planned_minutes, tier, workers_assigned, state,
        started_at_wall, started_at_uptime_ms, away_total_ms, pass_used)
      VALUES ('s1', 10, 'hut', 1, 'running', 1000, 2000, 0, 0)
    ''');
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);
    final row = await db.select(db.sessions).getSingle();
    expect(row.id, 's1');
    expect(row.plannedMinutes, 10);
    expect(row.plotIndex, isNull);
  });
}
