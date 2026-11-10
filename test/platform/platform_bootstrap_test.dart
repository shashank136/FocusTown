import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/platform/native_uptime_clock.dart';
import 'package:focus_town/platform/platform_bootstrap.dart';

const _methods = MethodChannel('focus/lifecycle');
const _events = EventChannel('focus/lifecycle/events');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(_methods, null)
      ..setMockStreamHandler(_events, null);
  });

  // The native source listens to its event channel as soon as it is made.
  void mockEvents() => messenger.setMockStreamHandler(
    _events,
    MockStreamHandler.inline(onListen: (args, sink) {}),
  );

  group('NativeUptimeClock', () {
    test('starts at the native value and grows with elapsed time', () {
      var elapsed = Duration.zero;
      final clock = NativeUptimeClock(
        const Duration(seconds: 5),
        elapsed: () => elapsed,
      );
      expect(clock.uptime(), const Duration(seconds: 5));
      elapsed = const Duration(seconds: 3);
      expect(clock.uptime(), const Duration(seconds: 8));
    });

    test('wall time is the system wall time', () {
      final clock = NativeUptimeClock(Duration.zero);
      final before = DateTime.now();
      final wall = clock.nowWall();
      expect(wall.difference(before).inSeconds, 0);
    });
  });

  group('bootstrapPlatform', () {
    test('a responding channel gives the native clock and source', () async {
      mockEvents();
      messenger.setMockMethodCallHandler(_methods, (call) async {
        expect(call.method, 'uptimeMs');
        return 90000;
      });
      final p = await bootstrapPlatform();
      expect(p.clock, isA<NativeUptimeClock>());
      expect(
        p.clock.uptime(),
        greaterThanOrEqualTo(const Duration(seconds: 90)),
      );
      expect(p.source.isNative, isTrue);
      await p.source.dispose();
    });

    test('a missing plugin falls back to the system clock', () async {
      final p = await bootstrapPlatform();
      expect(p.clock, isA<SystemClock>());
      expect(p.source.isNative, isFalse);
      await p.source.dispose();
    });

    test('a platform error falls back', () async {
      messenger.setMockMethodCallHandler(
        _methods,
        (call) async => throw PlatformException(code: 'nope'),
      );
      final p = await bootstrapPlatform();
      expect(p.clock, isA<SystemClock>());
      expect(p.source.isNative, isFalse);
      await p.source.dispose();
    });

    test('a channel that never answers falls back after the timeout', () async {
      messenger.setMockMethodCallHandler(
        _methods,
        (call) => Future<Object?>.delayed(const Duration(minutes: 5)),
      );
      final p = await bootstrapPlatform(
        timeout: const Duration(milliseconds: 50),
      );
      expect(p.clock, isA<SystemClock>());
      expect(p.source.isNative, isFalse);
      await p.source.dispose();
    });

    test('a non-int answer falls back', () async {
      messenger.setMockMethodCallHandler(_methods, (call) async => 'soon');
      final p = await bootstrapPlatform();
      expect(p.clock, isA<SystemClock>());
      expect(p.source.isNative, isFalse);
      await p.source.dispose();
    });
  });
}
