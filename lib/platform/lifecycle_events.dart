// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/time_stamp.dart';

/// Something the phone did that matters to a focus session.
sealed class LifecycleEvent {
  /// Creates an event stamped with [timestamp].
  const new(this.timestamp);

  /// When it happened.
  final TimeStamp timestamp;

  /// Short name for logs.
  String get name;

  @override
  bool operator ==(Object other) =>
      other is LifecycleEvent &&
      other.runtimeType == runtimeType &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(runtimeType, timestamp);
}

/// The screen was locked.
final class LockedEvent extends LifecycleEvent {
  /// Creates the event.
  const new(super.timestamp);

  @override
  String get name => 'locked';
}

/// The screen was unlocked.
final class UnlockedEvent extends LifecycleEvent {
  /// Creates the event.
  const new(super.timestamp);

  @override
  String get name => 'unlocked';
}

/// The app left the foreground.
final class BackgroundedEvent extends LifecycleEvent {
  /// Creates the event.
  const new(super.timestamp);

  @override
  String get name => 'backgrounded';
}

/// The app came back to the foreground.
final class ForegroundedEvent extends LifecycleEvent {
  /// Creates the event.
  const new(super.timestamp);

  @override
  String get name => 'foregrounded';
}

/// A phone call started.
final class CallStartedEvent extends LifecycleEvent {
  /// Creates the event.
  const new(super.timestamp);

  @override
  String get name => 'callStarted';
}

/// A phone call ended.
final class CallEndedEvent extends LifecycleEvent {
  /// Creates the event.
  const new(super.timestamp);

  @override
  String get name => 'callEnded';
}

/// A stream of [LifecycleEvent]s from the phone.
abstract class LifecycleSource {
  /// Events in the order they happened.
  Stream<LifecycleEvent> get events;

  /// True when backed by native code that can tell a lock from a switch.
  bool get isNative;

  /// Stops listening and closes [events].
  Future<void> dispose();
}
