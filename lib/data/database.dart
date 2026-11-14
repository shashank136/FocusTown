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
  IntColumn get emergencyPauses => integer().withDefault(const Constant(1))();
  TextColumn get emergencyWeek => text().nullable()();

  BoolColumn get notificationNoteShown =>
      boolean().withDefault(const Constant(false))();
  // claimed land beyond the starting island, as gx:gy,gx:gy
  TextColumn get parcels => text().withDefault(const Constant(''))();
  // finished districts, as east,north (the side of each, in order)
  TextColumn get districts => text().withDefault(const Constant(''))();
  // the district being built, as east:130 (side and minutes), or null
  TextColumn get districtProject => text().nullable()();

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
  // the look the user chose (null: the id decides)
  IntColumn get look => integer().nullable()();
  // Landmark.name for a landmark, and the minutes built into it so far
  TextColumn get landmark => text().nullable()();
  IntColumn get progress => integer().withDefault(const Constant(0))();

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
  // the parcel a land session claims, as gx:gy or gx:gy:g (garden)
  TextColumn get land => text().nullable()();
  // the look of the building the session builds (null: the id decides)
  IntColumn get look => integer().nullable()();
  // Landmark.name for a landmark session
  TextColumn get landmark => text().nullable()();
  // a district session: DistrictSide.name and the minutes it counts, north:120
  TextColumn get district => text().nullable()();
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
  static const currentSchemaVersion = 11;

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
      // v11: the side a district session builds on.
      if (from < 11) await m.addColumn(sessions, sessions.district);
      // v10: districts, the island grown in blocks of 64.
      if (from < 10) {
        await m.addColumn(towns, towns.districts);
        await m.addColumn(towns, towns.districtProject);
      }
      // v9: landmarks, built over several sessions.
      if (from < 9) {
        await m.addColumn(buildings, buildings.landmark);
        await m.addColumn(buildings, buildings.progress);
        await m.addColumn(sessions, sessions.landmark);
      }
      // v8: the look the user chose for a building.
      if (from < 8) {
        await m.addColumn(buildings, buildings.look);
        await m.addColumn(sessions, sessions.look);
      }
      // v7: land claimed beyond the starting island.
      if (from < 7) {
        await m.addColumn(towns, towns.parcels);
        await m.addColumn(sessions, sessions.land);
      }
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
