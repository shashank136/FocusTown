import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town_rules.dart';

/// Owns the town and the live session; the UI only reads and calls this.
class FocusController extends AsyncNotifier<FocusState> {
  @override
  Future<FocusState> build() async {
    final town = await ref.watch(townRepositoryProvider).loadOrCreate();
    return FocusState(town: town);
  }

  /// Dismisses the last result.
  void clearResult() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearLastResult: true));
  }

  /// Starts a session of [minutes]; it exists only once it is saved.
  Future<void> start(int minutes) async {
    final current = await future;
    if (current.active != null) {
      throw StateError('A session is already active');
    }
    if (!TownRules.canStart(current.town, minutes)) {
      throw StateError('Cannot start $minutes minutes with this town');
    }
    final now = TimeStamp.now(ref.read(clockProvider));
    final session = SessionEngine.start(
      id: 's${now.wall.microsecondsSinceEpoch}',
      minutes: minutes,
      workersAvailable: current.town.workers,
      recovery: current.town.inRecoveryMode,
      now: now,
    );
    // Save first: a session that was not saved never starts.
    await ref
        .read(townRepositoryProvider)
        .saveSessionStarted(current.town, session);
    state = AsyncData(current.copyWith(active: session));
  }
}
