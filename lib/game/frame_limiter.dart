/// How fast the town may redraw.
enum FrameMode {
  /// 15 frames per second.
  normal(15),

  /// 10 frames per second (battery saver).
  lowPower(10),

  /// No frames (app in the background).
  paused(0);

  new(this.fps);

  /// Frames per second allowed in this mode.
  final int fps;
}

/// Decides, from the time it is given, whether a frame may be drawn.
class FrameLimiter {
  /// How fast frames are allowed.
  FrameMode mode = FrameMode.normal;

  Duration? _lastAllowed;

  /// Whether a frame may be drawn at [now]; remembers it if so. The first call
  /// is always allowed (unless paused), and switching mode keeps the time of
  /// the last frame.
  bool allow(Duration now) {
    if (mode == FrameMode.paused) return false;
    final last = _lastAllowed;
    final interval = Duration(microseconds: 1000000 ~/ mode.fps);
    // 1 ms of slack so a 60 Hz clock does not skip a frame on rounding.
    if (last != null &&
        now - last < interval - const Duration(milliseconds: 1)) {
      return false;
    }
    _lastAllowed = now;
    return true;
  }
}
