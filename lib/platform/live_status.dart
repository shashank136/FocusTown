// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// What the lock screen shows for the running session.
class LiveStatus {
  /// Creates a status.
  const new({required this.endsAt, required this.title, required this.away});

  /// When the session is planned to end (the lock screen counts down to it).
  final DateTime endsAt;

  /// What is being built: a tier name, or `repair`.
  final String title;

  /// True while the user is away and the builders are waiting.
  final bool away;

  @override
  bool operator ==(Object other) =>
      other is LiveStatus &&
      other.endsAt == endsAt &&
      other.title == title &&
      other.away == away;

  @override
  int get hashCode => Object.hash(endsAt, title, away);
}

/// Shows the running session on the lock screen (an iOS Live Activity).
abstract class LiveStatusSink {
  /// Starts the status, or updates it when one is already showing.
  Future<void> show(LiveStatus status);

  /// Removes the status.
  Future<void> end();
}
