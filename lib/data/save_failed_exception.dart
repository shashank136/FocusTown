/// A write to the database failed twice. The message is meant for the user.
class SaveFailedException implements Exception {
  /// Creates the exception.
  const new();

  /// What the user reads.
  String get message => "Couldn't save your session. Try again.";

  @override
  String toString() => message;
}
