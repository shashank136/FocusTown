import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/building_look.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/camera/camera_transition.dart';
import 'package:focus_town/game/camera/town_camera.dart';
import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/effects/site_transition.dart';
import 'package:focus_town/game/frame_limiter.dart';
import 'package:focus_town/game/render_guard.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/vec2.dart';

/// The Flame game that draws the town and lets the user pan and zoom it.
///
/// The gesture handlers are plain methods so tests need no real touches.
class TownGame extends FlameGame
    with
        ScaleDetector,
        ScrollDetector,
        // DoubleTapDetector is deprecated but shares the legacy gesture system
        // with the other two; the newer callbacks would add a second system.
        // ignore: deprecated_member_use
        DoubleTapDetector {
  /// Creates the game. [fps] (optional) receives the measured frames per
  /// second once a second; [clock] (default: the system clock) decides how far
  /// the construction has come.
  new({
    ValueNotifier<double>? fps,
    Clock? clock,
    TownRenderer? renderer,
    RenderGuard? guard,
  }) : renderer = renderer ?? TownRenderer(),
       guard = guard ?? RenderGuard(null),
       // ignore: prefer_initializing_formals, a named parameter cannot be private
       _fps = fps,
       _clock = clock ?? SystemClock();

  final ValueNotifier<double>? _fps;
  final Clock _clock;

  /// Where the "Ready to place" label goes on screen, or null when hidden.
  final ValueNotifier<Vec2?> readyLabel = ValueNotifier(null);

  /// Draws the sky and the town.
  final TownRenderer renderer;

  /// Falls back to a still picture when drawing fails or crawls.
  final RenderGuard guard;

  /// Caps how often a fresh frame is drawn.
  final FrameLimiter limiter = FrameLimiter();

  /// How many fresh frames were drawn so far (the rest replayed the last one).
  int framesDrawn = 0;

  FocusState? _focus;
  TownState? _town;
  Duration _elapsed = Duration.zero;
  Picture? _lastFrame;
  bool _redraw = true;
  bool _inBackground = false;
  bool _lowPower = false;
  Duration _fpsWindowStart = Duration.zero;
  int _fpsWindowFrames = 0;
  int _fpsWindowRenders = 0;

  double _lastScale = 1;
  Vec2? _doubleTapAt;
  CameraTransition? _transition;
  Plot? _siteToFocus;

  // The last building site, remembered because the stored town moves on to
  // the next free plot the moment a session ends.
  Plot? _lastPlot;
  List<PlacedWorker> _lastSiteWorkers = const [];
  SiteTransition? _show;
  List<PlacedWorker> _leaving = const [];
  Plot? _smokeAt;
  Plot? _readyPlot;
  BuildingTier? _readyTier;
  int _readyLook = 0;
  final ParticleSystem _particles = ParticleSystem(1);

  /// Shows [town]; call on every change of the stored town.
  void setTown(TownState town) {
    _redraw = true;
    renderer.setTown(town);
  }

  /// Gives the game what to draw: the town (rebuilt only when it changed) and
  /// the running session (which decides where the workers are).
  void setFocus(FocusState focus) {
    final result = focus.lastResult;
    final plot = _lastPlot;
    if (result != null &&
        !identical(result, _focus?.lastResult) &&
        plot != null) {
      if (result.outcome == SessionOutcome.completed) _celebrate(plot);
      // A lost repair loses nothing: no smoke, no fallen workers.
      if (result.outcome == SessionOutcome.failed &&
          !result.repair &&
          !result.land) {
        _fail(plot);
      }
      if (result.outcome == SessionOutcome.queued) {
        final queue = focus.town.queue;
        _queue(plot, result.tier, queue.isEmpty ? 0 : lookIndex(queue.last.id));
      }
    }
    final active = focus.active;
    if (active != null) {
      _lastPlot = sessionSitePlot(focus.town, active);
    }
    // The world depends only on the buildings and the unlocked plots; other
    // changes (XP, the emergency pause) must not rebuild it.
    final old = _town;
    _town = focus.town;
    if (old == null ||
        old.plotsUnlocked != focus.town.plotsUnlocked ||
        !listEquals(old.buildings, focus.town.buildings)) {
      setTown(focus.town);
    }
    _focus = focus;
  }

  void _celebrate(Plot plot) {
    _show = SiteTransition.celebrate();
    _leaving = _lastSiteWorkers;
    if (!_lowPower && !reducedMotion) {
      _particles.burst(
        (plot.center.x, plot.center.y, 3),
        const [0xFFc69c5d, 0xFFbcbfc5, 0xFFa8875c],
        40,
      );
    }
  }

  void _queue(Plot plot, BuildingTier tier, int look) {
    _show = SiteTransition.ready();
    _readyPlot = plot;
    _readyTier = tier;
    _readyLook = look;
    _leaving = _lastSiteWorkers;
  }

  // The floating building and its label follow the show, 0.4 opaque at most.
  void _updateReady() {
    final plot = _readyPlot;
    final tier = _readyTier;
    final show = _show;
    final cam = renderer.camera;
    if (plot == null ||
        tier == null ||
        cam == null ||
        show?.phase != TransitionPhase.ready) {
      renderer.setPreview(null);
      readyLabel.value = null;
      return;
    }
    renderer.setPreview(
      ReadyPreview(tier, plot, 0.4 * show!.fade, look: _readyLook),
    );
    final top = maxStage(tier) + 4.0;
    final at = project(plot.center.x, plot.center.y, top, cam.tile, cam.origin);
    readyLabel.value = at;
  }

  void _fail(Plot plot) {
    _show = SiteTransition.fail();
    _smokeAt = plot;
    _leaving = _lastSiteWorkers;
  }

  // Smoke keeps coming for the whole failure phase: top up to about 25.
  void _topUpSmoke() {
    final plot = _smokeAt;
    if (plot == null || _lowPower || reducedMotion) return;
    final missing = 25 - _particles.alive.length;
    if (missing <= 0) return;
    _particles.burst(
      (plot.center.x, plot.center.y, 2),
      const [0xFF4a4038],
      missing,
      life: 1.5,
      speed: 0.4,
    );
  }

  /// True while the app is in the background: no frames, engine paused.
  bool get inBackground => _inBackground;
  set inBackground(bool value) {
    _inBackground = value;
    _applyMode();
    if (value) {
      pauseEngine();
    } else {
      resumeEngine();
      _redraw = true;
    }
  }

  /// True while the battery saver is on: fewer frames per second.
  bool get lowPower => _lowPower;
  set lowPower(bool value) {
    _lowPower = value;
    _applyMode();
  }

  /// True when the system asked for less motion: workers stand still.
  bool reducedMotion = false;

  void _applyMode() => limiter.mode = _inBackground
      ? FrameMode.paused
      : (_lowPower ? FrameMode.lowPower : FrameMode.normal);

  /// One finger dragged by [delta] pixels.
  void onPan(Vec2 delta) {
    _transition = null;
    _redraw = true;
    renderer.camera?.panBy(delta);
  }

  /// Pinch around [focal]; [factor] is the change since the last update.
  void onPinch(Vec2 focal, double factor) {
    _transition = null;
    _redraw = true;
    renderer.camera?.zoomAt(focal, factor);
  }

  /// Mouse wheel at [pos]; a negative [dy] (wheel up) zooms in.
  void onWheel(Vec2 pos, double dy) {
    _transition = null;
    _redraw = true;
    renderer.camera?.zoomAt(pos, math.exp(-dy * 0.002));
  }

  /// Double tap at [pos]: zoom in 1.5x around it. (Not `onDoubleTap`: Flame's
  /// mixin already owns that name with another signature.)
  void onDoubleTapAt(Vec2 pos) {
    _transition = null;
    _redraw = true;
    renderer.camera?.zoomAt(pos, 1.5);
  }

  /// Outlines the [free] plots and fills [selected] (choose-a-plot mode); an
  /// empty set turns the outlines off.
  void setPlacement(Set<int> free, int? selected) {
    renderer.setPlotOverlay(free, selected);
    _redraw = true;
  }

  /// The plot under the screen point [p] (its ground is drawn one block up),
  /// or null over roads and open land.
  int? plotAtScreen(Vec2 p) {
    final cam = renderer.camera;
    if (cam == null) return null;
    final g = unprojectGround(p.x, p.y + cam.tile, cam.tile, cam.origin);
    final x = g.x.floor();
    final y = g.y.floor();
    // Choosing land: the outlined parcels are not plots yet.
    for (final i in renderer.plotOutlines.where((i) => i >= kLandBase)) {
      final plot = plotFor(i, renderer.parcels);
      if (x >= plot.originX &&
          x < plot.originX + kPlotSize &&
          y >= plot.originY &&
          y < plot.originY + kPlotSize) {
        return i;
      }
    }
    return plotAtWith(renderer.parcels, x, y)?.index;
  }

  /// Glides the camera to [plot] (zooming in to at least tile 14). If the first
  /// frame has not been drawn yet the glide starts as soon as it has.
  // ignore: use_setters_to_change_properties, a command, not a property
  void focusOnSite(Plot plot) => _siteToFocus = plot;

  /// Glides out to show the whole island (choosing land).
  void showIsland() {
    final cam = renderer.camera;
    if (cam == null) return;
    final target = TownCamera(cam.viewSize, box: cam.box);
    _transition = CameraTransition(from: cam.pose, to: target.pose);
  }

  /// Glides back to the unlocked plots.
  void recenter() {
    final cam = renderer.camera;
    if (cam == null) return;
    final target = TownCamera(cam.viewSize, box: cam.box)
      ..fitToRegion(renderer.unlockedRegion);
    _transition = CameraTransition(from: cam.pose, to: target.pose);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += Duration(microseconds: (dt * 1e6).round());
    _publishFps();
    // A degraded town is a still picture: no camera, workers or effects.
    if (guard.degraded) return;
    _updateCamera(dt);
    final step = Duration(microseconds: (dt * 1e6).round());
    _particles.step(step);
    _show?.step(step);
    if (_show?.phase == TransitionPhase.done) {
      _show = null;
      _smokeAt = null;
      _readyPlot = null;
      _particles.clear();
    }
    _topUpSmoke();
    if (limiter.allow(_elapsed)) {
      _updateSite();
      _updateReady();
      _simulateWorkers();
      renderer.setParticles(_particles.alive, _show?.fade ?? 0);
      _redraw = true;
    }
  }

  void _updateCamera(double dt) {
    final cam = renderer.camera;
    if (cam == null) return;
    final site = _siteToFocus;
    if (site != null) {
      _siteToFocus = null;
      _transition = CameraTransition(
        from: cam.pose,
        to: CameraPose(site.center, math.max(cam.tile, 14)),
      );
    }
    final t = _transition;
    if (t == null) return;
    // With reduced motion the glide is a jump.
    final pose = t.step(
      reducedMotion
          ? CameraTransition.duration
          : Duration(microseconds: (dt * 1e6).round()),
    );
    cam.setPose(pose.center, pose.tile);
    _redraw = true;
    if (t.isDone) _transition = null;
  }

  // The stage comes from the clock on every frame, never from stored state.
  void _updateSite() {
    final active = _focus?.active;
    // A repair builds nothing: the ruin stays until the repair is done.
    if (active == null || active.isRepair || active.isLand) {
      renderer.setSite(null);
      return;
    }
    final progress = SessionEngine.progress(active, TimeStamp.now(_clock));
    renderer.setSite(
      ActiveSite(
        active.tier,
        stageForProgress(active.tier, progress),
        plotIndex: active.plotIndex,
        look: lookIndex(active.id),
      ),
    );
  }

  // Where every worker is at the current game time.
  void _simulateWorkers() {
    final focus = _focus;
    if (focus == null) return;
    final seconds = _elapsed.inMicroseconds / 1e6;
    final active = focus.active;
    var spare = spareWorkerCount(focus.town, active);
    final site = <PlacedWorker>[];
    if (active != null) {
      var onSite = active.workersAssigned;
      if (active.isRepair) {
        // One repairer at the ruin; the other workers keep walking.
        onSite = 1;
      } else if (active.isLand) {
        onSite = 0; // surveying, not building
      } else if (onSite == 0 && focus.town.inRecoveryMode) {
        // The Last Builder works the site alone instead of walking the road.
        onSite = 1;
        spare = 0;
      }
      site.addAll(
        siteWorkers(
          sessionSitePlot(focus.town, active),
          active.tier,
          onSite,
          seconds,
          reducedMotion: reducedMotion,
        ),
      );
      _lastSiteWorkers = site;
    }
    final show = _show;
    if (show != null) {
      if (show.phase == TransitionPhase.fail) {
        site.addAll(deadWorkers(_leaving));
      } else if (!reducedMotion) {
        site.addAll(workersLeaving(_leaving, show.progress));
      }
    }
    renderer.setWorkers([
      ...site,
      ...spareWalkers(spare, seconds, reducedMotion: reducedMotion),
    ]);
  }

  @override
  void onScaleStart(ScaleStartInfo info) => _lastScale = 1;

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final d = info.raw.focalPointDelta;
    onPan(Vec2(d.dx, d.dy));
    if (info.pointerCount > 1) {
      final scale = info.raw.scale;
      final p = info.eventPosition.widget;
      onPinch(Vec2(p.x, p.y), scale / _lastScale);
      _lastScale = scale;
    }
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final p = info.eventPosition.widget;
    onWheel(Vec2(p.x, p.y), info.scrollDelta.global.y);
  }

  @override
  void onDoubleTapDown(TapDownInfo info) {
    final p = info.eventPosition.widget;
    _doubleTapAt = Vec2(p.x, p.y);
  }

  @override
  void onDoubleTap() {
    final at = _doubleTapAt;
    if (at != null) onDoubleTapAt(at);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _fpsWindowRenders++;
    // A fresh frame only when the limiter allowed one (or the user moved the
    // view); otherwise the last frame is replayed without re-drawing blocks.
    if ((_redraw || _lastFrame == null) && !guard.degraded) {
      _redraw = false;
      final recorder = PictureRecorder();
      try {
        renderer.paint(Canvas(recorder), Size(size.x, size.y));
        _lastFrame?.dispose();
        _lastFrame = recorder.endRecording();
        framesDrawn++;
        _countFrame();
      } on Object catch (e) {
        recorder.endRecording().dispose();
        guard.recordError(e);
      }
    }
    final frame = _lastFrame;
    if (frame != null) canvas.drawPicture(frame);
  }

  // Frames are counted while painting but published from update: a listener
  // that rebuilds widgets must not be told in the middle of a paint.
  void _countFrame() => _fpsWindowFrames++;

  // Publishes frames per second once a second.
  void _publishFps() {
    final window = _elapsed - _fpsWindowStart;
    if (window >= const Duration(seconds: 1)) {
      final fps = _fpsWindowFrames * 1e6 / window.inMicroseconds;
      // Hardly any paint in the window means a page is covering the town (or
      // started to): that says nothing about speed, so keep the last readout
      // and the guard calm.
      if (_fpsWindowRenders < 5) {
        guard.recordHidden();
      } else {
        _fps?.value = fps;
        guard.recordFps(fps, _elapsed);
      }
      _fpsWindowStart = _elapsed;
      _fpsWindowFrames = 0;
      _fpsWindowRenders = 0;
    }
  }
}
