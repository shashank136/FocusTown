import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/tips.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/tip.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/render_guard.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/ui/debug_screen.dart';
import 'package:focus_town/ui/hud.dart';
import 'package:focus_town/ui/result_dialogs.dart';
import 'package:focus_town/ui/session_panel.dart';
import 'package:focus_town/ui/session_setup_sheet.dart';
import 'package:focus_town/ui/town_summary.dart';

/// The town, full screen. Debug builds add a small bug button (top-left) that
/// opens the debug screen.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates the home screen. [game] is for tests; it defaults to a new game.
  const new({this.game, super.key});

  /// The game to draw with, or null to create one.
  final TownGame? game;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final TownGame _game =
      widget.game ??
      TownGame(
        fps: ref.read(fpsProvider),
        clock: ref.read(clockProvider),
        guard: RenderGuard(ref.read(localLogProvider)),
      );

  Timer? _tick;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Completion is decided from the stored clock; this only asks the
    // controller to look once a second while a session runs.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.read(focusControllerProvider).value?.active != null) {
        unawaited(ref.read(focusControllerProvider.notifier).tick());
      }
    });
    final startup = ref.read(startupMessageProvider);
    if (startup != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(startup)));
      });
    }
    // Battery saver: fewer frames per second.
    ref.listenManual(lowPowerProvider, (prev, next) {
      _game.lowPower = next.value ?? false;
    }, fireImmediately: true);
    // The bridge: the game redraws only when the stored town itself changes,
    // not on every session event.
    ref.listenManual(focusControllerProvider, (prev, next) {
      final focus = next.value;
      if (focus == null) return;
      _game.setFocus(focus);
      // A session just became active (or was found running at launch): glide
      // the camera to its site.
      if (focus.active != null && prev?.value?.active == null) {
        _game.focusOnSite(sessionSitePlot(focus.town, focus.active!));
      }
      _syncPlacement();
    }, fireImmediately: true);
    ref.listenManual(placementProvider, (prev, next) {
      _syncPlacement();
      // Choosing land: step back to see the coast.
      if (next != null && next.land && !(prev?.land ?? false)) {
        _game.showIsland();
      }
    });
    // The free pass was just spent: explain it, once.
    ref.listenManual(focusControllerProvider, (prev, next) {
      final used = next.value?.active?.passUsed ?? false;
      final was = prev?.value?.active?.passUsed ?? false;
      if (used && !was) unawaited(_passTip());
    });
    // Tell the user how a session ended, once, then clear the result.
    ref.listenManual(focusControllerProvider, (prev, next) {
      final result = next.value?.lastResult;
      if (result == null || _showingResult) return;
      _showingResult = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final tips = await ref.read(tipsProvider.future);
        if (!mounted) return;
        final growth =
            result.outcome == SessionOutcome.completed &&
            result.workersGained > 0 &&
            !tips.contains(Tip.growth);
        final recovery = result.recoveryStarted;
        await showResultDialog(
          context,
          result,
          growthTip: growth,
          recoveryFull: !tips.contains(Tip.recovery),
        );
        final marks = ref.read(tipsProvider.notifier);
        if (growth) await marks.markShown(Tip.growth);
        if (recovery) await marks.markShown(Tip.recovery);
        _showingResult = false;
        if (mounted) ref.read(focusControllerProvider.notifier).clearResult();
      });
    }, fireImmediately: true);
  }

  Future<void> _dismissNote() async {
    await ref.read(tipsProvider.notifier).markShown(Tip.notificationNote);
    ref.invalidate(notificationNoteProvider);
  }

  Future<void> _passTip() async {
    final tips = ref.read(tipsProvider.notifier);
    if (!await tips.shouldShow(Tip.pass) || !mounted) return;
    await tips.markShown(Tip.pass);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Free pass spent'),
        content: const Text(
          'Emergency pass used. You were away more than 10 seconds, so we '
          'spent your free pass. You get one per session. Once a week you can '
          'also press Emergency pause on the session screen before you leave: '
          'it lets you be away for up to 10 minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // Outlines on the free plots while the user is choosing one.
  void _syncPlacement() {
    final placement = ref.read(placementProvider);
    final town = ref.read(focusControllerProvider).value?.town;
    _game.setPlacement(
      placement == null || town == null
          ? const {}
          : placement.land
          ? {
              for (var i = 0; i < claimableParcels(town.parcels).length; i++)
                kLandBase + i,
            }
          : {
              for (var i = 0; i < TownRules.plotCountOf(town); i++)
                if (TownRules.isPlotFree(
                  town,
                  i,
                  BuildingTier.forMinutes(placement.minutes),
                ))
                  i,
            },
      placement?.plot,
      span:
          placement != null &&
              !placement.land &&
              plotsOf(BuildingTier.forMinutes(placement.minutes)) == 4
          ? 2
          : 1,
    );
  }

  // A tap on a ruin offers to repair it (not while a session is running).
  Future<void> _tapTown(Offset at) async {
    final town = ref.read(focusControllerProvider).value?.town;
    final plot = _game.plotAtScreen(Vec2(at.dx, at.dy));
    if (town == null || plot == null || !TownRules.canRepair(town, plot)) {
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repair this ruin?'),
        content: const Text(
          'Focus for 10 minutes to clear it. Nothing is at risk: if you '
          'leave, the ruin just stays.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Repair (10 min)'),
          ),
        ],
      ),
    );
    if (go ?? false) {
      await ref.read(focusControllerProvider.notifier).startRepair(plot);
    }
  }

  void _pick(Offset at) {
    final plot = _game.plotAtScreen(Vec2(at.dx, at.dy));
    if (plot != null) ref.read(placementProvider.notifier).select(plot);
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nothing is drawn while the app is not in the foreground.
    _game.inBackground = state != AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    _game.reducedMotion = MediaQuery.of(context).disableAnimations;
    final town = ref.watch(
      focusControllerProvider.select((f) => f.value?.town),
    );
    final placement = ref.watch(placementProvider);
    final active = ref.watch(
      focusControllerProvider.select((f) => f.value?.active),
    );
    return Scaffold(
      body: Stack(
        children: [
          Semantics(
            label: town == null ? null : townSummary(town),
            child: GameWidget(game: _game),
          ),
          // Tapping a ruin offers a repair; pan and zoom still work.
          if (active == null && placement == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => unawaited(_tapTown(d.localPosition)),
              ),
            ),
          // Streak, level, workers and plots, clear of the debug button.
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(56, 4, 8, 0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Hud(),
                ),
              ),
            ),
          ),
          // Warnings are off: say so once.
          if (ref.watch(notificationNoteProvider).value ?? false)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Warnings are off. We can't tell you before "
                            'your builders stop. Turn on notifications in '
                            'Settings.',
                          ),
                          TextButton(
                            onPressed: () => unawaited(_dismissNote()),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // While building: the countdown, progress and Abandon.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: const SessionPanel(),
                ),
              ),
            ),
          ),
          // The way in: pick a duration and start (hidden while building).
          if (active == null && placement == null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 56),
                    ),
                    onPressed: () => unawaited(
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => const SessionSetupSheet(),
                      ),
                    ),
                    child: const Text('Start focus'),
                  ),
                ),
              ),
            ),
          // Choose-a-plot mode: taps pick a plot; pan and zoom still work.
          if (placement != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _pick(d.localPosition),
              ),
            ),
          if (placement != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            placement.land
                                ? 'Choose land for your '
                                      '${placement.minutes}-minute session'
                                : 'Choose a plot for your '
                                      '${placement.minutes}-minute build',
                          ),
                          if (placement.land)
                            SwitchListTile(
                              dense: true,
                              title: const Text('Make it a garden'),
                              subtitle: const Text(
                                'Open space: no building can stand here.',
                              ),
                              value: placement.garden,
                              onChanged: (_) => ref
                                  .read(placementProvider.notifier)
                                  .toggleGarden(),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: ref
                                    .read(placementProvider.notifier)
                                    .cancel,
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: placement.plot == null
                                    ? null
                                    : () => unawaited(
                                        ref
                                            .read(placementProvider.notifier)
                                            .confirm(),
                                      ),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // "Ready to place": follows the floating building while it shows.
          ValueListenableBuilder<Vec2?>(
            valueListenable: _game.readyLabel,
            builder: (context, at, _) => at == null
                ? const SizedBox.shrink()
                : Positioned(
                    left: at.x - 60,
                    top: at.y - 24,
                    width: 120,
                    child: const IgnorePointer(
                      child: Text(
                        'Ready to place',
                        key: ValueKey('ready-label'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                tooltip: 'Recenter town',
                icon: const Icon(Icons.my_location),
                color: Colors.black54,
                iconSize: 28,
                onPressed: _game.recenter,
              ),
            ),
          ),
          // Debug builds only: a small button, below the status bar.
          if (kDebugMode)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: 'Open debug screen',
                  icon: const Icon(Icons.bug_report_outlined),
                  color: Colors.black54,
                  iconSize: 28,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DebugScreen(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
