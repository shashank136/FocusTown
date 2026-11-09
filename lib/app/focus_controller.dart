import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';

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
}
