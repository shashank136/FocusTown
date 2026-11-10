import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/frame_limiter.dart';

// Calls `allow` at 60 Hz for [seconds] and returns how many were allowed.
int _allowedPerSecond(FrameLimiter l, {double seconds = 1, int startUs = 0}) {
  var allowed = 0;
  final frames = (60 * seconds).round();
  for (var i = 0; i < frames; i++) {
    if (l.allow(Duration(microseconds: startUs + i * 16667))) allowed++;
  }
  return allowed;
}

void main() {
  test('the modes have the documented rates', () {
    expect(FrameMode.normal.fps, 15);
    expect(FrameMode.lowPower.fps, 10);
    expect(FrameMode.paused.fps, 0);
  });

  test('normal allows about 15 of 60 frames', () {
    expect(_allowedPerSecond(FrameLimiter()), inInclusiveRange(14, 16));
  });

  test('low power allows about 10 of 60 frames', () {
    final l = FrameLimiter()..mode = FrameMode.lowPower;
    expect(_allowedPerSecond(l), inInclusiveRange(9, 11));
  });

  test('paused allows none', () {
    final l = FrameLimiter()..mode = FrameMode.paused;
    expect(_allowedPerSecond(l), 0);
  });

  test('the first call is always allowed', () {
    expect(FrameLimiter().allow(const Duration(seconds: 5)), isTrue);
    final low = FrameLimiter()..mode = FrameMode.lowPower;
    expect(low.allow(Duration.zero), isTrue);
  });

  test('switching to low power mid second lowers the rate', () {
    final l = FrameLimiter();
    final first = _allowedPerSecond(l, seconds: 0.5);
    l.mode = FrameMode.lowPower;
    final second = _allowedPerSecond(l, seconds: 0.5, startUs: 500000);
    expect(first, greaterThan(second));
    expect(first + second, inInclusiveRange(11, 14));
  });

  test('resuming from paused allows the next call immediately', () {
    final l = FrameLimiter();
    expect(l.allow(Duration.zero), isTrue);
    l.mode = FrameMode.paused;
    expect(l.allow(const Duration(milliseconds: 20)), isFalse);
    expect(l.allow(const Duration(seconds: 3)), isFalse);
    l.mode = FrameMode.normal;
    expect(l.allow(const Duration(seconds: 3, milliseconds: 1)), isTrue);
  });

  test('a call that is too soon is refused and does not move the clock', () {
    final l = FrameLimiter();
    expect(l.allow(Duration.zero), isTrue);
    expect(l.allow(const Duration(milliseconds: 10)), isFalse);
    // 66 ms after the last allowed frame (0), not after the refused one.
    expect(l.allow(const Duration(milliseconds: 66)), isTrue);
  });
}
