import 'dart:async';
import 'dart:ui' as ui;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/render/tier_preview.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/voxel_world.dart';
import 'package:focus_town/platform/fallback_lifecycle_source.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/lifecycle_router.dart';
import 'package:focus_town/platform/local_notifier.dart';
import 'package:focus_town/platform/notifier.dart' as warnings;
import 'package:focus_town/platform/power_state.dart';

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

/// What the town world depends on. `stage` is 0 when nothing is building.
typedef TownWorldKey = ({TownState town, Session? active, int stage});

/// The town as blocks. Rebuilt only when the town or the build stage changes,
/// never on a plain redraw.
// ignore: specify_nonobvious_property_types, the family type is not exported
final townWorldProvider = Provider.family<VoxelWorld, TownWorldKey>((ref, key) {
  final active = key.active;
  // Mid-stage progress, so floating point can never land on a stage edge.
  final progress = active == null
      ? 0.0
      : (key.stage - 0.5) / maxStage(active.tier);
  return buildTownWorld(key.town, active: active, progress: progress);
});

/// The blocks of the town world that show a face, back to front.
// ignore: specify_nonobvious_property_types, the family type is not exported
final visibleBlocksProvider = Provider.family<List<VisibleBlock>, TownWorldKey>(
  (ref, key) => ref.watch(townWorldProvider(key)).sortedVisible(),
);

/// The build stage of [active] at [progress] (0..1), or 0 without a session.
int activeStage(Session? active, double progress) =>
    active == null ? 0 : stageForProgress(active.tier, progress);

/// Reads the phone's battery saver state.
final powerStateProvider = Provider<PowerState>((ref) => PowerState());

class _ResumeObserver with WidgetsBindingObserver {
  new(this.onResume);
  final void Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// Whether low power mode is on: read at start, every 30 s and on resume;
/// emits only when the value changes.
final lowPowerProvider = StreamProvider<bool>((ref) {
  final power = ref.watch(powerStateProvider);
  final controller = StreamController<bool>();
  bool? last;
  Future<void> poll() async {
    final value = await power.isLowPower();
    if (controller.isClosed || value == last) return;
    last = value;
    controller.add(value);
  }

  unawaited(poll());
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => poll());
  final observer = _ResumeObserver(() => unawaited(poll()));
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(observer);
    unawaited(controller.close());
  });
  return controller.stream;
});

/// The measured frames per second of the town, updated once a second.
final fpsProvider = Provider<ValueNotifier<double>>((ref) {
  final fps = ValueNotifier<double>(0);
  ref.onDispose(fps.dispose);
  return fps;
});

/// The picture of each tier's finished building, drawn once per tier.
// ignore: specify_nonobvious_property_types, the family type is not exported
final tierPreviewProvider = FutureProvider.family<ui.Image, BuildingTier>(
  (ref, tier) => renderTierPreview(tier),
);
