import 'package:drift/drift.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';

const _queued = 'queued';

Landmark? _landmark(String? name) =>
    name == null ? null : Landmark.values.byName(name);

/// Builds a [TownState] from the town row and all building rows.
///
/// Queued rows become the queue, ordered by completedAt then id.
TownState townFromRows(TownRow town, List<BuildingRow> buildings) {
  final placed = buildings.where((b) => b.status != _queued);
  final queued = buildings.where((b) => b.status == _queued).toList()
    ..sort((a, b) {
      final byTime = a.completedAt.compareTo(b.completedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  final lastStreak = town.lastStreakDate;
  final lastGrant = town.lastPlotGrantDate;
  final week = town.emergencyWeek;
  return TownState(
    workers: town.workerCount,
    plotsUnlocked: town.plotsUnlocked,
    buildings: [
      for (final b in placed)
        TownBuilding(
          id: b.id,
          tier: BuildingTier.values.byName(b.tier),
          status: BuildingStatus.values.byName(b.status),
          plotIndex: b.plotIndex!,
          look: b.look,
          landmark: _landmark(b.landmark),
          progress: b.progress,
        ),
    ],
    queue: [
      for (final b in queued)
        QueuedBuilding(
          id: b.id,
          tier: BuildingTier.values.byName(b.tier),
          look: b.look,
        ),
    ],
    inRecoveryMode: town.inRecoveryMode,
    xp: town.xp,
    streakCount: town.streakCount,
    lastStreakDate: lastStreak == null ? null : LocalDate.parse(lastStreak),
    lastPlotGrantDate: lastGrant == null ? null : LocalDate.parse(lastGrant),
    emergencyPauses: town.emergencyPauses,
    emergencyWeek: week == null ? null : LocalDate.parse(week),
    parcels: Parcel.decodeList(town.parcels),
    districts: decodeDistricts(town.districts),
    districtProject: town.districtProject == null
        ? null
        : DistrictProject.decode(town.districtProject!),
  );
}

/// Town columns owned by the domain (not id, onboardingDone, createdAt).
TownsCompanion townToRow(TownState state) => TownsCompanion(
  workerCount: Value(state.workers),
  plotsUnlocked: Value(state.plotsUnlocked),
  xp: Value(state.xp),
  streakCount: Value(state.streakCount),
  lastStreakDate: Value(state.lastStreakDate?.toIso()),
  lastPlotGrantDate: Value(state.lastPlotGrantDate?.toIso()),
  inRecoveryMode: Value(state.inRecoveryMode),
  emergencyPauses: Value(state.emergencyPauses),
  emergencyWeek: Value(state.emergencyWeek?.toIso()),
  parcels: Value(Parcel.encodeList(state.parcels)),
  districts: Value(encodeDistricts(state.districts)),
  districtProject: Value(state.districtProject?.encode()),
);

/// One row per placed or queued building, all stamped [now].
List<BuildingsCompanion> buildingsToRows(
  TownState state, {
  required DateTime now,
}) {
  final at = now.millisecondsSinceEpoch;
  return [
    for (final b in state.buildings)
      BuildingsCompanion.insert(
        id: b.id,
        tier: b.tier.name,
        status: b.status.name,
        plotIndex: Value(b.plotIndex),
        sessionId: Value(b.id == 'starter' ? null : b.id),
        completedAt: at,
        look: Value(b.look),
        landmark: Value(b.landmark?.name),
        progress: Value(b.progress),
      ),
    for (final q in state.queue)
      BuildingsCompanion.insert(
        id: q.id,
        tier: q.tier.name,
        status: _queued,
        sessionId: Value(q.id),
        completedAt: at,
        look: Value(q.look),
        progress: const Value(0),
      ),
  ];
}

/// Restores a [Session] from its row.
Session sessionFromRow(SessionRow row) {
  final leftWall = row.leftAtWall;
  final leftUptime = row.leftAtUptimeMs;
  final reason = row.outcomeReason;
  return Session(
    id: row.id,
    plannedMinutes: row.plannedMinutes,
    tier: BuildingTier.values.byName(row.tier),
    workersAssigned: row.workersAssigned,
    state: SessionState.values.byName(row.state),
    startedAt: TimeStamp(
      DateTime.fromMillisecondsSinceEpoch(row.startedAtWall),
      Duration(milliseconds: row.startedAtUptimeMs),
    ),
    leftAt: leftWall == null || leftUptime == null
        ? null
        : TimeStamp(
            DateTime.fromMillisecondsSinceEpoch(leftWall),
            Duration(milliseconds: leftUptime),
          ),
    awayTotal: Duration(milliseconds: row.awayTotalMs),
    passUsed: row.passUsed,
    outcomeReason: reason == null ? null : OutcomeReason.values.byName(reason),
    plotIndex: row.plotIndex,
    repairPlot: row.repairPlotIndex,
    land: row.land == null ? null : Parcel.decode(row.land!),
    look: row.look,
    landmark: _landmark(row.landmark),
    district: row.district == null
        ? null
        : DistrictSide.values.byName(row.district!),
    emergencyArmed: row.emergencyArmed,
    emergencyUsed: row.emergencyUsed,
  );
}

/// Session as a row; [resolvedAt] is set when the session finished.
SessionsCompanion sessionToRow(Session session, {DateTime? resolvedAt}) {
  final left = session.leftAt;
  return SessionsCompanion.insert(
    id: session.id,
    plannedMinutes: session.plannedMinutes,
    tier: session.tier.name,
    workersAssigned: session.workersAssigned,
    state: session.state.name,
    startedAtWall: session.startedAt.wall.millisecondsSinceEpoch,
    startedAtUptimeMs: session.startedAt.uptime.inMilliseconds,
    leftAtWall: Value(left?.wall.millisecondsSinceEpoch),
    leftAtUptimeMs: Value(left?.uptime.inMilliseconds),
    awayTotalMs: session.awayTotal.inMilliseconds,
    passUsed: session.passUsed,
    outcomeReason: Value(session.outcomeReason?.name),
    plotIndex: Value(session.plotIndex),
    repairPlotIndex: Value(session.repairPlot),
    land: Value(session.land?.encode()),
    look: Value(session.look),
    landmark: Value(session.landmark?.name),
    district: Value(session.district?.name),
    emergencyArmed: Value(session.emergencyArmed),
    emergencyUsed: Value(session.emergencyUsed),
    resolvedAt: Value(resolvedAt?.millisecondsSinceEpoch),
  );
}
