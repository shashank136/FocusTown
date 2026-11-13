import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/session_setup.dart';
import 'package:focus_town/domain/building_look.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

const _recoveryBanner =
    'The Last Builder. All your builders are gone. A wanderer will build '
    'small huts (10 to 20 minutes) and cannot be lost. Finish huts until '
    'you have 3 builders.';

/// Bottom sheet: pick how long to focus, see what it builds and what is at
/// risk, then start (on the next free plot) or choose the plot first.
class SessionSetupSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({this.landmark, super.key});

  /// The landmark to put the time into, or null for a new building.
  final Landmark? landmark;

  @override
  ConsumerState<SessionSetupSheet> createState() => _SessionSetupSheetState();
}

class _SessionSetupSheetState extends ConsumerState<SessionSetupSheet> {
  late final Future<int> _last = ref
      .read(townRepositoryProvider)
      .lastDurationMinutes();
  FixedExtentScrollController? _wheel;
  int? _selected; // minutes
  int _look = 0; // the look of the building, 0 is the classic one
  late Landmark? _landmark = widget.landmark;

  @override
  void dispose() {
    _wheel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = ref.watch(focusControllerProvider).value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: focus == null
            ? const SizedBox(height: 120)
            : FutureBuilder<int>(
                future: _last,
                builder: (context, last) => last.hasData
                    ? _content(focus.town, last.requireData)
                    : const SizedBox(height: 120),
              ),
      ),
    );
  }

  Widget _content(TownState town, int lastUsed) {
    final options = durationOptions(town);
    final minutes = _selected ??= defaultMinutes(options, lastUsed);
    _wheel ??= FixedExtentScrollController(
      initialItem: options.indexWhere((o) => o.minutes == minutes),
    );
    final option = options.firstWhere((o) => o.minutes == minutes);
    final theme = Theme.of(context);
    final landmarks = [
      for (final l in Landmark.values)
        if (TownRules.canStartLandmark(town, l)) l,
    ];
    final landmark = landmarks.contains(_landmark) ? _landmark : null;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (town.inRecoveryMode)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_recoveryBanner, style: theme.textTheme.bodyMedium),
              ),
            ),
          if (landmarks.isNotEmpty) _target(landmarks, landmark),
          SizedBox(
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Marks the selected row.
                IgnorePointer(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ListWheelScrollView(
                  controller: _wheel,
                  itemExtent: 40,
                  // A curved, magnified dial: rows tilt away from the middle.
                  diameterRatio: 1.8,
                  perspective: 0.004,
                  useMagnifier: true,
                  magnification: 1.15,
                  overAndUnderCenterOpacity: 0.35,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (i) {
                    // A detent: a small tap and a click for every step.
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(SystemSound.play(SystemSoundType.click));
                    setState(() => _selected = options[i].minutes);
                  },
                  children: [
                    for (final o in options)
                      Semantics(
                        label:
                            '${o.minutes} minutes, ${o.tier.name}'
                            '${o.reason == null ? '' : ', ${o.reason}'}',
                        excludeSemantics: true,
                        child: Center(
                          child: Text(
                            '${o.minutes} min',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: o.enabled ? null : theme.disabledColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (landmark != null)
            ..._landmarkPart(town, landmark, minutes)
          else
            ..._buildingPart(town, option, minutes),
        ],
      ),
    );
  }

  // What to build with the time: a new building, or one of the landmarks
  // that can be worked on now.
  Widget _target(List<Landmark> landmarks, Landmark? chosen) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('New building'),
          selected: chosen == null,
          onSelected: (_) => setState(() => _landmark = null),
        ),
        for (final l in landmarks)
          ChoiceChip(
            label: Text(l.title),
            selected: chosen == l,
            onSelected: (_) => setState(() => _landmark = l),
          ),
      ],
    ),
  );

  // The time goes into [landmark]: how many whole stages it makes, and the
  // minutes left over, which count toward the next stage. Nothing is at risk
  // but progress.
  List<Widget> _landmarkPart(TownState town, Landmark landmark, int minutes) {
    final started = TownRules.landmarkProject(town, landmark) != null;
    final stages = minutes ~/ landmark.minutesPerStage;
    final rest = minutes % landmark.minutesPerStage;
    final text = stages > 0 && rest > 0
        ? 'Adds $stages stage${stages == 1 ? '' : 's'} and $rest min toward '
              'the next'
        : stages > 0
        ? 'Adds $stages stage${stages == 1 ? '' : 's'}'
        : 'Adds $rest min toward the next stage';
    return [
      Text(landmark.title, style: Theme.of(context).textTheme.titleMedium),
      Text(text),
      const Text(
        'Nothing is at risk but progress: leaving costs one stage.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          // A landmark already started stays where it stands.
          if (!started)
            TextButton(
              onPressed: () => _choosePlot(minutes, landmark: landmark),
              child: const Text('Choose plot…'),
            ),
          FilledButton(
            onPressed: () => unawaited(_startLandmark(landmark, minutes)),
            child: const Text('Start'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildingPart(
    TownState town,
    DurationOption option,
    int minutes,
  ) {
    final theme = Theme.of(context);
    return [
      Text(option.tier.name, style: theme.textTheme.titleMedium),
      _looks(option.tier),
      if (option.workersAtRisk > 0)
        Text(
          'Risks ${option.workersAtRisk} '
          'worker${option.workersAtRisk == 1 ? '' : 's'}',
        ),
      if (option.workersGained > 0)
        Text(
          '+${option.workersGained} '
          'worker${option.workersGained == 1 ? '' : 's'} if you finish',
        ),
      if (option.reason != null)
        Text(option.reason!, style: TextStyle(color: theme.colorScheme.error)),
      if (TownRules.nextFreePlot(town, option.tier) == null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _roomNote(town, option.tier),
            textAlign: TextAlign.center,
          ),
        ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          TextButton(
            onPressed:
                option.enabled &&
                    TownRules.nextFreePlot(town, option.tier) != null
                ? () => _choosePlot(minutes)
                : null,
            child: const Text('Choose plot…'),
          ),
          TextButton(onPressed: _extendLand, child: const Text('Extend land…')),
          TextButton(onPressed: _makeGarden, child: const Text('Make garden…')),
          FilledButton(
            onPressed: option.enabled ? () => unawaited(_start(minutes)) : null,
            child: const Text('Start'),
          ),
        ],
      ),
    ];
  }

  // Why there is no room for a [tier] now, and what makes some.
  static String _roomNote(TownState town, BuildingTier tier) {
    final ruins = town.buildings.any((b) => b.status == BuildingStatus.ruin);
    final head = plotsOf(tier) == 1
        ? 'Every plot is used.'
        : 'There is no free 2 x 2 block of plots for a castle.';
    return '$head A finished build waits until there is room. Tap Extend '
        'land to add some${ruins ? ', or tap a ruin to repair it' : ''}.';
  }

  // The looks to choose from, each shown as the building it will be.
  Widget _looks(BuildingTier tier) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var look = 0; look < kLooksPerTier; look++) _lookTile(tier, look),
    ],
  );

  Widget _lookTile(BuildingTier tier, int look) {
    final image = ref.watch(tierPreviewProvider((tier, look)));
    final selected = _look == look;
    final theme = Theme.of(context);
    final name = lookName(tier, look);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _look = look),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: selected ? 3 : 1,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 80,
                child: image.when(
                  data: (img) => RawImage(image: img, width: 80, height: 80),
                  loading: () => const SizedBox(width: 80, height: 80),
                  error: (_, _) => const SizedBox(width: 80, height: 80),
                ),
              ),
              Text(name),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(int minutes) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(focusControllerProvider.notifier)
          .start(minutes, look: _look);
      await ref.read(townRepositoryProvider).saveLastDuration(minutes);
      navigator.pop();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _startLandmark(Landmark landmark, int minutes) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(focusControllerProvider.notifier)
          .startLandmark(landmark, minutes);
      await ref.read(townRepositoryProvider).saveLastDuration(minutes);
      navigator.pop(true);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _makeGarden() {
    ref.read(placementProvider.notifier).beginGarden();
    Navigator.of(context).pop();
  }

  void _extendLand() {
    ref.read(placementProvider.notifier).beginLand();
    Navigator.of(context).pop();
  }

  void _choosePlot(int minutes, {Landmark? landmark}) {
    unawaited(ref.read(townRepositoryProvider).saveLastDuration(minutes));
    ref
        .read(placementProvider.notifier)
        .begin(minutes, look: _look, landmark: landmark);
    Navigator.of(context).pop();
  }
}
