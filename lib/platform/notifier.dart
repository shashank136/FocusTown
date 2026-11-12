/// Away warnings shown when the user leaves the app during a session.
abstract class Notifier {
  /// Asks the user for permission; returns whether it is granted.
  Future<bool> requestPermission();

  /// Whether notifications are currently allowed.
  Future<bool> hasPermission();

  /// Shows the 10 s warning now and, if [passAvailable], schedules the
  /// pass warning for 10 s later. With the weekly [emergency] pause armed the
  /// user has 10 minutes: say so now and warn again 2 minutes before the end.
  Future<void> scheduleAwayWarnings({
    required bool passAvailable,
    bool emergency = false,
  });

  /// Removes both warnings, shown or scheduled.
  Future<void> cancelAwayWarnings();
}
