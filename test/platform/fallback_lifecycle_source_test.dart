import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/fallback_lifecycle_source.dart';
import 'package:focus_town/platform/lifecycle_events.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late FakeClock clock;
  late FallbackLifecycleSource source;
  late List<LifecycleEvent> seen;

  setUp(() {
    clock = FakeClock();
    source = FallbackLifecycleSource(clock);
    seen = [];
    source.events.listen(seen.add);
  });
  tearDown(() => source.dispose());

  Future<void> change(AppLifecycleState s) async {
    binding.handleAppLifecycleStateChanged(s);
    await Future<void>.delayed(Duration.zero);
  }

  test('paused emits one LockedEvent stamped from the clock', () async {
    clock.advance(const Duration(seconds: 7));
    await change(AppLifecycleState.paused);
    expect(seen, [LockedEvent(TimeStamp.now(clock))]);
  });

  test('resumed emits UnlockedEvent then ForegroundedEvent', () async {
    await change(AppLifecycleState.resumed);
    expect(seen.map((e) => e.name), ['unlocked', 'foregrounded']);
  });

  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    test('${s.name} emits nothing', () async {
      await change(s);
      expect(seen, isEmpty);
    });
  }

  test('after dispose no events arrive', () async {
    await source.dispose();
    await change(AppLifecycleState.paused);
    expect(seen, isEmpty);
  });

  test('isNative is false', () {
    expect(source.isNative, isFalse);
  });
}
