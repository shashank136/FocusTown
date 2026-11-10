import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';

/// Which part of the end-of-session show is playing.
enum TransitionPhase {
  /// Dust and the site workers leaving (1 second).
  celebrate,

  /// Nothing more to show.
  done,
}

/// The short show after a session ends. Pure: time goes in through [step].
class SiteTransition {
  /// A celebration after a completed building.
  new celebrate() : _length = const Duration(seconds: 1);

  final Duration _length;
  Duration _elapsed = Duration.zero;

  /// The current phase.
  TransitionPhase get phase =>
      _elapsed >= _length ? TransitionPhase.done : TransitionPhase.celebrate;

  /// How far the show has come, 0 to 1.
  double get progress =>
      (_elapsed.inMicroseconds / _length.inMicroseconds).clamp(0.0, 1.0);

  /// 1 at the start, 0 at the end.
  double get fade => 1 - progress;

  /// Moves time on by [dt].
  void step(Duration dt) => _elapsed += dt;
}

// The roads run along x = 31.6 and y = 32.4.
const _roadX = 31.6;
const _roadY = 32.4;

/// Where [workers] are [t] (0 to 1) of the way to the nearest road line,
/// walking.
List<PlacedWorker> workersLeaving(List<PlacedWorker> workers, double t) => [
  for (final w in workers) _toRoad(w, t),
];

PlacedWorker _toRoad(PlacedWorker w, double t) {
  final dx = _roadX - w.worker.x;
  final dy = _roadY - w.worker.y;
  final alongX = dx.abs() <= dy.abs(); // walk to the vertical road
  final x = alongX ? w.worker.x + dx * t : w.worker.x;
  final y = alongX ? w.worker.y : w.worker.y + dy * t;
  final facing = alongX ? (dx.sign.toInt(), 0) : (0, dy.sign.toInt());
  return PlacedWorker(
    Worker(
      x: x,
      y: y,
      shirt: w.worker.shirt,
      facing: facing == (0, 0) ? w.worker.facing : facing,
    ),
    (t * 8).floor().isEven ? Pose.walk1 : Pose.walk2,
  );
}
