// Table columns are self-describing; docs would only repeat the names.
// ignore_for_file: public_member_api_docs

import 'package:drift/drift.dart';

part 'database.g.dart';

/// Single row (id always 1).
@DataClassName('TownRow')
class Towns extends Table {
  IntColumn get id => integer()();
  IntColumn get workerCount => integer()();
  IntColumn get plotsUnlocked => integer()();
  IntColumn get xp => integer()();
  IntColumn get streakCount => integer()();
  // yyyy-mm-dd
  TextColumn get lastStreakDate => text().nullable()();
  TextColumn get lastPlotGrantDate => text().nullable()();
  BoolColumn get inRecoveryMode => boolean()();
  BoolColumn get onboardingDone =>
      boolean().withDefault(const Constant(false))();
  // epoch ms, UTC
  IntColumn get createdAt => integer()();
  // the duration picker starts here
  IntColumn get lastDurationMinutes =>
      integer().withDefault(const Constant(25))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BuildingRow')
class Buildings extends Table {
  TextColumn get id => text()();
  // BuildingTier.name
  TextColumn get tier => text()();
  // complete / ruin / queued
  TextColumn get status => text()();
  // null when queued
  IntColumn get plotIndex => integer().nullable()();
  TextColumn get sessionId => text().nullable()();
  // epoch ms
  IntColumn get completedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SessionRow')
class Sessions extends Table {
  TextColumn get id => text()();
  IntColumn get plannedMinutes => integer()();
  TextColumn get tier => text()();
  IntColumn get workersAssigned => integer()();
  TextColumn get state => text()();
  IntColumn get startedAtWall => integer()();
  IntColumn get startedAtUptimeMs => integer()();
  IntColumn get leftAtWall => integer().nullable()();
  IntColumn get leftAtUptimeMs => integer().nullable()();
  IntColumn get awayTotalMs => integer()();
  BoolColumn get passUsed => boolean()();
  TextColumn get outcomeReason => text().nullable()();
  IntColumn get resolvedAt => integer().nullable()();
  IntColumn get plotIndex => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Towns, Buildings, Sessions])
class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2: the plot the user chose for a session.
      if (from < 2) await m.addColumn(sessions, sessions.plotIndex);
      // v3: the duration the picker opens on.
      if (from < 3) await m.addColumn(towns, towns.lastDurationMinutes);
    },
  );
}
