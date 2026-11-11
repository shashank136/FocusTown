import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';

/// The end of onboarding: ask to warn the user, remember it is done, and
/// start the first 10-minute hut.
class OnboardingController {
  /// Creates the controller.
  new(this._ref);

  final Ref _ref;
  Future<void>? _finishing;

  /// Runs once however often it is called. A denied permission does not stop
  /// the first session.
  Future<void> finish() => _finishing ??= _finish();

  Future<void> _finish() async {
    await _ref.read(notifierProvider).requestPermission();
    await _ref.read(townRepositoryProvider).setOnboardingDone();
    await _ref.read(focusControllerProvider.notifier).start(10);
    _ref.invalidate(onboardingDoneProvider);
  }
}
