import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/tip.dart';

/// The one-time tips already shown, stored in the town.
class Tips extends AsyncNotifier<Set<Tip>> {
  @override
  Future<Set<Tip>> build() => ref.read(townRepositoryProvider).shownTips();

  /// Whether [tip] was never shown.
  Future<bool> shouldShow(Tip tip) async => !(await future).contains(tip);

  /// Remembers that [tip] was shown.
  Future<void> markShown(Tip tip) async {
    await ref.read(townRepositoryProvider).markTipShown(tip);
    state = AsyncData({...await future, tip});
  }
}

/// See [Tips].
final tipsProvider = AsyncNotifierProvider<Tips, Set<Tip>>(Tips.new);

/// Whether to tell the user that warnings are off: after onboarding, with no
/// notification permission, until they dismiss it.
final FutureProvider<bool> notificationNoteProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      if (!await ref.read(townRepositoryProvider).isOnboardingDone())
        return false;
      if (await ref.read(notifierProvider).hasPermission()) return false;
      final tips = ref.read(tipsProvider.notifier);
      return await tips.shouldShow(Tip.notificationNote);
    });
