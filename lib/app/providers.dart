import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/platform/fallback_lifecycle_source.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/lifecycle_router.dart';
import 'package:focus_town/platform/local_notifier.dart';
import 'package:focus_town/platform/notifier.dart' as warnings;

/// The app-wide [Clock]; tests override it with a fake.
final clockProvider = Provider<Clock>((ref) => SystemClock());

/// The on-disk database; tests override it with an in-memory one.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'focus_town'));
  ref.onDispose(db.close);
  return db;
});

/// Reads and writes the stored town and sessions.
final townRepositoryProvider = Provider<TownRepository>(
  (ref) =>
      TownRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// The session controller.
final focusControllerProvider =
    AsyncNotifierProvider<FocusController, FocusState>(FocusController.new);

/// Where lifecycle events come from. Fallback until native code exists.
final lifecycleSourceProvider = Provider<LifecycleSource>((ref) {
  final source = FallbackLifecycleSource(ref.watch(clockProvider));
  ref.onDispose(source.dispose);
  return source;
});

/// The most recent lifecycle events, newest first.
class EventLog extends Notifier<List<LifecycleEvent>> {
  @override
  List<LifecycleEvent> build() => const [];

  /// Records [event], keeping only the newest [_limit].
  void add(LifecycleEvent event) =>
      state = [event, ...state].take(_limit).toList();

  static const _limit = 20;
}

/// See [EventLog].
final eventLogProvider = NotifierProvider<EventLog, List<LifecycleEvent>>(
  EventLog.new,
);

/// Routes lifecycle events to the controller; read it once to start it.
final lifecycleRouterProvider = Provider<LifecycleRouter>((ref) {
  final router = LifecycleRouter(
    ref.watch(lifecycleSourceProvider),
    ref.watch(focusControllerProvider.notifier),
    ref.watch(clockProvider),
    onEvent: ref.read(eventLogProvider.notifier).add,
  )..start();
  ref.onDispose(router.dispose);
  return router;
});

/// Shows away warnings. `main()` overrides it with an initialized notifier.
final notifierProvider = Provider<warnings.Notifier>((ref) => LocalNotifier());
