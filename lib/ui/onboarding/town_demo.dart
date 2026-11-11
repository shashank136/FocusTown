import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/demo/demo_script.dart';
import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/world/plot_layout.dart';

/// A tiny game that replays one [DemoKind] on the real town renderer. No
/// controller, no database: the picture comes from the pure demo script.
class DemoGame extends FlameGame {
  /// Creates a game for [kind]. With [reducedMotion] it shows the last frame
  /// of the loop and never moves.
  new(this.kind, {this.reducedMotion = false});

  /// Which demo plays.
  final DemoKind kind;

  /// Whether to show one still frame.
  final bool reducedMotion;

  /// Pauses the loop when false (the page is not on screen).
  bool active = true;

  /// Draws the town.
  final TownRenderer renderer = TownRenderer();

  /// Seconds played so far (the loop position when reduced motion is on).
  double seconds = 0;

  final ParticleSystem _smoke = ParticleSystem(2);
  bool _framed = false;
  TownState? _town;

  @override
  void update(double dt) {
    super.update(dt);
    if (reducedMotion) {
      seconds = kDemoLoop - 0.1;
    } else if (active) {
      seconds += dt;
    } else if (seconds != 0) {
      return;
    }
    final frame = demoFrame(kind, seconds);
    // The world is rebuilt only when the town really changed.
    if (frame.town != _town) {
      _town = frame.town;
      renderer.setTown(frame.town);
    }
    renderer
      ..setSite(frame.site)
      ..setWorkers(frame.workers);
    if (frame.smoke && !reducedMotion && _smoke.alive.length < 20) {
      final p = kPlots[frame.town.buildings.last.plotIndex].center;
      _smoke.burst((p.x, p.y, 2), const [0xFF4a4038], 5, life: 1.5, speed: 0.4);
    }
    if (!frame.smoke) _smoke.clear();
    _smoke.step(Duration(microseconds: (dt * 1e6).round()));
    renderer.setParticles(_smoke.alive, 1);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    renderer.paint(canvas, Size(size.x, size.y));
    final cam = renderer.camera;
    if (!_framed && cam != null && kind == DemoKind.start) {
      _framed = true;
      final site = renderer.site?.plotIndex;
      if (site != null) cam.setPose(kPlots[site].center, 14);
    }
  }
}

/// One looping onboarding picture. [active] false freezes it.
class TownDemo extends StatefulWidget {
  /// Creates a demo of [kind].
  const new({required this.kind, this.active = true, super.key});

  /// Which demo plays.
  final DemoKind kind;

  /// Whether it plays; pass false for pages that are not on screen.
  final bool active;

  @override
  State<TownDemo> createState() => _TownDemoState();
}

class _TownDemoState extends State<TownDemo> {
  DemoGame? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game ??= DemoGame(
      widget.kind,
      reducedMotion: MediaQuery.of(context).disableAnimations,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!..active = widget.active;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GameWidget<DemoGame>(game: game),
    );
  }
}
