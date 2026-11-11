import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/local_log.dart';
import 'package:focus_town/platform/resilient_lifecycle_source.dart';
import 'package:focus_town/platform/testing/fake_lifecycle_source.dart';

void main() {
  late FakeClock clock;
  late FakeLifecycleSource native;
  late FakeLifecycleSource fallback;
  late LocalLog log;
  late ResilientLifecycleSource source;
  late List<LifecycleEvent> seen;

  setUp(() {
    clock = FakeClock();
    native = FakeLifecycleSource(isNative: true);
    fallback = FakeLifecycleSource();
    log = LocalLog(null, clock);
    source = ResilientLifecycleSource(native, fallback, clock, log);
    seen = [];
    source.events.listen(seen.add);
  });

  TimeStamp now() => TimeStamp.now(clock);

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('a healthy native source forwards only its own events', () async {
    final locked = LockedEvent(now());
    native.emit(locked);
    fallback.emit(LockedEvent(now()));
    clock.advance(const Duration(seconds: 3));
    source.check();
    await flush();
    expect(seen, [locked]);
    expect(source.isNative, isTrue);
    expect(log.lines, isEmpty);
  });

  test('a silent bridge switches to the fallback after 2 seconds', () async {
    fallback.emit(LockedEvent(now()));
    clock.advance(const Duration(seconds: 1));
    source.check();
    expect(source.isNative, isTrue);
    clock.advance(const Duration(seconds: 1));
    source.check();
    await flush();
    expect(source.isNative, isFalse);
    expect(log.lines, hasLength(1));
    source.check();
    expect(log.lines, hasLength(1));
  });

  test('a late native event within 2 seconds keeps the bridge', () async {
    fallback.emit(LockedEvent(now()));
    clock.advance(const Duration(milliseconds: 1500));
    native.emit(BackgroundedEvent(now()));
    clock.advance(const Duration(seconds: 5));
    source.check();
    expect(source.isNative, isTrue);
  });

  test('a native event just before the fallback one counts too', () async {
    native.emit(BackgroundedEvent(now()));
    clock.advance(const Duration(milliseconds: 500));
    fallback.emit(LockedEvent(now()));
    clock.advance(const Duration(seconds: 5));
    source.check();
    expect(source.isNative, isTrue);
  });

  test('after the switch fallback events are forwarded', () async {
    fallback.emit(LockedEvent(now()));
    clock.advance(const Duration(seconds: 2));
    source.check();
    final back = UnlockedEvent(now());
    fallback.emit(back);
    final fg = ForegroundedEvent(now());
    fallback.emit(fg);
    await flush();
    expect(seen.whereType<UnlockedEvent>(), [back]);
    expect(seen.whereType<ForegroundedEvent>(), [fg]);
  });

  test('native events are ignored after the switch', () async {
    fallback.emit(LockedEvent(now()));
    clock.advance(const Duration(seconds: 2));
    source.check();
    native.emit(BackgroundedEvent(now()));
    await flush();
    expect(seen.whereType<BackgroundedEvent>(), isEmpty);
  });

  test('no switch when the fallback never reports a background', () async {
    clock.advance(const Duration(minutes: 10));
    source.check();
    fallback.emit(UnlockedEvent(now()));
    await flush();
    expect(source.isNative, isTrue);
    expect(seen, isEmpty);
  });

  test('the next event also checks the deadline', () async {
    fallback.emit(LockedEvent(now()));
    clock.advance(const Duration(seconds: 3));
    fallback.emit(UnlockedEvent(now()));
    await flush();
    expect(source.isNative, isFalse);
  });
}
