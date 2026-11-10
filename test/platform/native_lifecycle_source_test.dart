import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/native_lifecycle_source.dart';

const _channel = EventChannel('focus/lifecycle/events');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> malformed;
  late bool cancelled;
  late NativeLifecycleSource source;
  late List<LifecycleEvent> seen;

  /// Starts a source whose native side sends [messages] once listened to.
  Future<void> run(List<Object?> messages, {bool error = false}) async {
    cancelled = false;
    messenger.setMockStreamHandler(
      _channel,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          messages.forEach(sink.success);
          if (error) sink.error(code: 'boom', message: 'native failure');
        },
        onCancel: (args) => cancelled = true,
      ),
    );
    source = NativeLifecycleSource(onMalformed: malformed.add);
    seen = [];
    source.events.listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() => malformed = []);
  tearDown(() {
    messenger.setMockStreamHandler(_channel, null);
    return source.dispose();
  });

  Map<String, Object?> msg(String type) => {
    'type': type,
    'wallMs': 1767258000000,
    'uptimeMs': 123456,
  };

  final stamp = TimeStamp(
    DateTime.fromMillisecondsSinceEpoch(1767258000000),
    const Duration(milliseconds: 123456),
  );

  test('isNative is true', () async {
    await run([]);
    expect(source.isNative, isTrue);
  });

  test('all six types parse with the right timestamp', () async {
    await run([
      msg('locked'),
      msg('unlocked'),
      msg('backgrounded'),
      msg('foregrounded'),
      msg('callStarted'),
      msg('callEnded'),
    ]);
    expect(seen, [
      LockedEvent(stamp),
      UnlockedEvent(stamp),
      BackgroundedEvent(stamp),
      ForegroundedEvent(stamp),
      CallStartedEvent(stamp),
      CallEndedEvent(stamp),
    ]);
    expect(malformed, isEmpty);
  });

  final bad = <String, Object?>{
    'unknown type': msg('exploded'),
    'null': null,
    'a string': 'locked',
    'missing uptimeMs': {'type': 'locked', 'wallMs': 1},
    'wallMs as a string': {'type': 'locked', 'wallMs': '1', 'uptimeMs': 2},
    'missing type': {'wallMs': 1, 'uptimeMs': 2},
  };
  for (final entry in bad.entries) {
    test('${entry.key} is skipped and reported once', () async {
      await run([entry.value]);
      expect(seen, isEmpty);
      expect(malformed, hasLength(1));
    });
  }

  test('a valid event after a malformed one is still delivered', () async {
    await run([null, msg('locked')]);
    expect(seen, [LockedEvent(stamp)]);
    expect(malformed, hasLength(1));
  });

  test('a stream error is reported and the stream stays usable', () async {
    await run([msg('locked')], error: true);
    expect(seen, [LockedEvent(stamp)]);
    expect(malformed, hasLength(1));
  });

  test('dispose cancels the subscription', () async {
    await run([]);
    await source.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
  });
}
