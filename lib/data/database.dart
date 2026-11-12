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
  // one-time tips already shown
  BoolColumn get tipPassShown => boolean().withDefault(const Constant(false))();
  BoolColumn get tipGrowthShown =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get tipRecoveryShown =>
      boolean().withDefault(const Constant(false))();
  // weekly emergency pause: how many are left and the Monday they were set
  IntColumn get emergencyPauses =>
      integer().withDefault(const Constant(1))();
  TextColumn get emergencyWeek => text().nullable()();
  BoolColumn get notificationNoteShown =>
      boolean().withDefault(const Constant(false))();

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
  IntColumn get repairPlotIndex => integer().nullable()();
  BoolColumn get emergencyArmed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get emergencyUsed =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Towns, Buildings, Sessions])
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// The schema version this build of the app writes.
  static const currentSchemaVersion = 6;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2: the plot the user chose for a session.
      if (from < 2) await m.addColumn(sessions, sessions.plotIndex);
      // v3: the duration the picker opens on.
      if (from < 3) await m.addColumn(towns, towns.lastDurationMinutes);
      if (from < 4) {
        await m.addColumn(towns, towns.tipPassShown);
        await m.addColumn(towns, towns.tipGrowthShown);
        await m.addColumn(towns, towns.tipRecoveryShown);
        await m.addColumn(towns, towns.notificationNoteShown);
      }
      // v5: the ruin a repair session clears.
      if (from < 5) await m.addColumn(sessions, sessions.repairPlotIndex);
      // v6: the weekly emergency pause.
      if (from < 6) {
        await m.addColumn(towns, towns.emergencyPauses);
        await m.addColumn(towns, towns.emergencyWeek);
        await m.addColumn(sessions, sessions.emergencyArmed);
        await m.addColumn(sessions, sessions.emergencyUsed);
      }
    },
  );
}
