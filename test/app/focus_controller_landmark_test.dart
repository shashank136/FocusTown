import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/short_sessions.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
      liveStatusSinkProvider.overrideWithValue(FakeLiveStatusSink()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

FocusState _state(ProviderContainer c) =>
    c.read(focusControllerProvider).requireValue;

TownBuilding? _project(ProviderContainer c) {
  for (final b in _state(c).town.buildings) {
    if (b.landmark == Landmark.eiffel) return b;
  }
  return null;
}

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  // A town at Village level, so landmarks are unlocked.
  Future<(ProviderContainer, FocusController)> ready({int xp = 300}) async {
    final seed = TownState.initial().copyWith(xp: xp);
    await _db.transaction(() async {
      await _db
          .into(_db.towns)
          .insert(
            townToRow(seed)
                .copyWith(id: const Value(1), createdAt: const Value(0)),
          );
      await _db.batch(
        (b) => b.insertAll(
          _db.buildings,
          buildingsToRows(seed, now: _clock.nowWall()),
        ),
      );
    });
    final c = _container();
    await c.read(focusControllerProvider.future);
    return (c, c.read(focusControllerProvider.notifier));
  }

  Future<void> finish(
    ProviderContainer c,
    FocusController n,
    int minutes,
  ) async {
    _clock.advance(Duration(minutes: minutes + 1));
    await n.tick();
    n.clearResult();
    _clock.advance(const Duration(minutes: 1));
  }

  test('the first session takes a block and starts the project', () async {
    final (c, n) = await ready();
    await n.startLandmark(Landmark.eiffel, 45);
    final s = _state(c).active!;
    expect(s.isLandmark, isTrue);
    expect(s.plannedMinutes, 45);
    expect(s.workersAssigned, 0);
    final p = _project(c)!;
    expect(p.status, BuildingStatus.building);
    expect(p.progress, 0);
    expect(s.plotIndex, p.plotIndex);
  });

  test('a finished session adds its minutes and counts for xp', () async {
    final (c, n) = await ready();
    await n.startLandmark(Landmark.eiffel, 45);
    _clock.advance(const Duration(minutes: 46));
    await n.tick();
    expect(_project(c)!.progress, 45);
    final r = _state(c).lastResult!;
    expect(r.outcome, SessionOutcome.completed);
    expect(r.landmark, Landmark.eiffel);
    expect(r.landmarkStage, 2);
    expect(r.landmarkFinished, isFalse);
    expect(r.xpGained, 45);
    expect(_state(c).town.xp, 345);
  });

  test('the next session continues the same project', () async {
    final (c, n) = await ready();
    await n.startLandmark(Landmark.eiffel, 30);
    await finish(c, n, 30);
    final first = _project(c)!;
    await n.startLandmark(Landmark.eiffel, 30);
    await finish(c, n, 30);
    final second = _project(c)!;
    expect(second.plotIndex, first.plotIndex);
    expect(second.progress, 60);
    expect(
      _state(c).town.buildings.where((b) => b.landmark != null),
      hasLength(1),
    );
  });

  test('giving up costs one stage and no workers', () async {
    final (c, n) = await ready();
    await n.startLandmark(Landmark.eiffel, 60);
    await finish(c, n, 60);
    await n.startLandmark(Landmark.eiffel, 30);
    final workers = _state(c).town.workers;
    await n.abandon();
    expect(_project(c)!.progress, 40); // 60 - one stage of 20
    final r = _state(c).lastResult!;
    expect(r.outcome, SessionOutcome.failed);
    expect(r.landmark, Landmark.eiffel);
    expect(r.landmarkStage, 2);
    expect(r.workersLost, 0);
    expect(_state(c).town.workers, workers);
  });

  test('240 minutes finish the landmark', () async {
    final (c, n) = await ready();
    for (var i = 0; i < 4; i++) {
      await n.startLandmark(Landmark.eiffel, 60);
      if (i < 3) await finish(c, n, 60);
    }
    _clock.advance(const Duration(minutes: 61));
    await n.tick();
    final p = _project(c)!;
    expect(p.status, BuildingStatus.complete);
    expect(_state(c).lastResult!.landmarkFinished, isTrue);
    await expectLater(n.startLandmark(Landmark.eiffel, 30), throwsStateError);
  });

  test('a bad length is refused', () async {
    final (_, n) = await ready();
    await expectLater(n.startLandmark(Landmark.eiffel, 7), throwsStateError);
    await expectLater(n.startLandmark(Landmark.eiffel, 130), throwsStateError);
  });

  test('the project survives a restart', () async {
    final (c, n) = await ready();
    await n.startLandmark(Landmark.eiffel, 30);
    await finish(c, n, 30);
    final again = _container();
    final town = (await again.read(focusControllerProvider.future)).town;
    expect(town.buildings.singleWhere((b) => b.landmark != null).progress, 30);
  });

  test(
    'test mode: a very short landmark session still counts a stage',
    () async {
      final (c, n) = await ready();
      c.read(shortSessionsProvider.notifier).toggle();
      await n.startLandmark(Landmark.eiffel, 60);
      expect(_state(c).active!.plannedMinutes, 1);
      _clock.advance(const Duration(seconds: 61));
      await n.tick();
      expect(_project(c)!.progress, 20);
    },
  );

  test('resetting a landmark (a testing aid) lets it be built again', () async {
    final (c, n) = await ready();
    await n.startLandmark(Landmark.eiffel, 60);
    await finish(c, n, 60);
    await n.resetLandmark(Landmark.eiffel);
    expect(_project(c), isNull);
    await n.startLandmark(Landmark.eiffel, 30);
    expect(_project(c)!.progress, 0);
    // It is saved, not just shown.
    final again = _container();
    final town = (await again.read(focusControllerProvider.future)).town;
    expect(town.buildings.where((b) => b.landmark != null), hasLength(1));
  });

  test('a landmark cannot be reset while a session is running', () async {
    final (_, n) = await ready();
    await n.startLandmark(Landmark.eiffel, 30);
    await expectLater(n.resetLandmark(Landmark.eiffel), throwsStateError);
  });

  test('a landmark that is not unlocked cannot be started', () async {
    final (_, n) = await ready(xp: 299);
    await expectLater(n.startLandmark(Landmark.eiffel, 30), throwsStateError);
  });
}
