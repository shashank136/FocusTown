import 'package:focus_town/platform/notifier.dart';

/// Test double that records what the app asked for.
class FakeNotifier implements Notifier {
  /// Creates a fake. [grants] decides whether a permission request succeeds.
  new({this.grants = true});

  /// Whether [requestPermission] grants permission.
  final bool grants;

  /// Whether permission is currently granted.
  bool permissionGranted = false;

  /// Calls in order: `schedule(passAvailable: x)`, `cancel`,
  /// `requestPermission`.
  final List<String> calls = [];

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    if (grants) permissionGranted = true;
    return permissionGranted;
  }

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> scheduleAwayWarnings({
    required bool passAvailable,
    bool emergency = false,
  }) async {
    calls.add(
      emergency
          ? 'schedule(emergency)'
          : 'schedule(passAvailable: $passAvailable)',
    );
  }

  @override
  Future<void> cancelAwayWarnings() async {
    calls.add('cancel');
  }
}
