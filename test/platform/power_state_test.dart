import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/platform/power_state.dart';

const _channel = MethodChannel('focus/lifecycle');

class _FakePower implements PowerState {
  bool low = false;
  int calls = 0;

  @override
  Future<bool> isLowPower() async {
    calls++;
    return low;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  group('PowerState', () {
    test('returns true and false from the channel', () async {
      messenger.setMockMethodCallHandler(_channel, (call) async {
        expect(call.method, 'lowPowerMode');
        return true;
      });
      expect(await PowerState().isLowPower(), isTrue);
      messenger.setMockMethodCallHandler(_channel, (call) async => false);
      expect(await PowerState().isLowPower(), isFalse);
    });

    test('a missing plugin means not low power', () async {
      expect(await PowerState().isLowPower(), isFalse);
    });

    test('a platform error means not low power', () async {
      messenger.setMockMethodCallHandler(
        _channel,
        (call) async => throw PlatformException(code: 'nope'),
      );
      expect(await PowerState().isLowPower(), isFalse);
    });

    test('a non-bool answer means not low power', () async {
      messenger.setMockMethodCallHandler(_channel, (call) async => 'yes');
      expect(await PowerState().isLowPower(), isFalse);
    });
  });

  group('lowPowerProvider', () {
    late _FakePower power;
    late ProviderContainer container;
    late List<bool> seen;

    // Created inside each test body so its timers run on the test clock.
    void start() {
      power = _FakePower();
      container = ProviderContainer(
        overrides: [powerStateProvider.overrideWithValue(power)],
      );
      seen = [];
      container.listen(lowPowerProvider, (prev, next) {
        final v = next.value;
        if (v != null) seen.add(v);
      });
    }

    testWidgets('emits the initial value, then only changes', (tester) async {
      start();
      await tester.pump();
      expect(seen, [false]);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(power.calls, 2); // re-read, nothing new to say
      expect(seen, [false]);
      power.low = true;
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(seen, [false, true]);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(seen, [false, true]);
      container.dispose();
    });

    testWidgets('re-reads when the app resumes', (tester) async {
      start();
      await tester.pump();
      power.low = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(seen, [false, true]);
      container.dispose();
    });

    testWidgets('stops polling when disposed', (tester) async {
      start();
      await tester.pump();
      container.dispose();
      final calls = power.calls;
      await tester.pump(const Duration(seconds: 90));
      expect(power.calls, calls);
    });
  });
}
