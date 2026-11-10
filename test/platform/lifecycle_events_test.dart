import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/testing/fake_lifecycle_source.dart';

void main() {
  final t = TimeStamp(DateTime(2026), const Duration(seconds: 5));
  final later = TimeStamp(DateTime(2026), const Duration(seconds: 6));

  final named = <String, LifecycleEvent>{
    'locked': LockedEvent(t),
    'unlocked': UnlockedEvent(t),
    'backgrounded': BackgroundedEvent(t),
    'foregrounded': ForegroundedEvent(t),
    'callStarted': CallStartedEvent(t),
    'callEnded': CallEndedEvent(t),
  };

  group('events', () {
    named.forEach((name, event) {
      test('$name reports its name and keeps its timestamp', () {
        expect(event.name, name);
        expect(event.timestamp, t);
      });
    });

    test('same type and timestamp are equal, with the same hash', () {
      expect(LockedEvent(t), LockedEvent(t));
      expect(LockedEvent(t).hashCode, LockedEvent(t).hashCode);
    });

    test('different timestamp or different type are not equal', () {
      expect(LockedEvent(t), isNot(LockedEvent(later)));
      expect(LockedEvent(t), isNot(UnlockedEvent(t)));
    });
  });

  group('FakeLifecycleSource', () {
    test('isNative defaults to false and can be set', () {
      expect(FakeLifecycleSource().isNative, isFalse);
      expect(FakeLifecycleSource(isNative: true).isNative, isTrue);
    });

    test('emit delivers events to a listener in order', () async {
      final source = FakeLifecycleSource();
      final seen = <LifecycleEvent>[];
      source.events.listen(seen.add);
      source
        ..emit(LockedEvent(t))
        ..emit(UnlockedEvent(later));
      await Future<void>.delayed(Duration.zero);
      expect(seen, [LockedEvent(t), UnlockedEvent(later)]);
    });

    test('dispose completes the stream', () async {
      final source = FakeLifecycleSource();
      final done = source.events.toList();
      source.emit(LockedEvent(t));
      await source.dispose();
      expect(await done, [LockedEvent(t)]);
    });
  });
}
