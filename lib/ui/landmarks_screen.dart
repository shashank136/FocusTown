import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/ui/session_setup_sheet.dart';

/// The landmarks: one card each, with its picture, its total time and where
/// it stands (locked, not started, in progress or built).
class LandmarksScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Landmarks')),
      body: focus == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final l in Landmark.values)
                  _Card(l, focus.town, busy: focus.active != null),
              ],
            ),
    );
  }
}

String _hours(int minutes) {
  final h = minutes / 60;
  final text = h == h.roundToDouble() ? '${h.round()}' : h.toStringAsFixed(1);
  return 'About $text ${h == 1 ? 'hour' : 'hours'} over many sessions';
}

class _Card extends ConsumerWidget {
  const new(this.landmark, this.town, {required this.busy});

  final Landmark landmark;
  final TownState town;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = TownRules.landmarkState(town, landmark);
    final project = TownRules.landmarkProject(town, landmark);
    final level = landmark.unlockLevel;
    final image = ref.watch(landmarkPreviewProvider(landmark));
    final theme = Theme.of(context);
    final (status, button) = switch (state) {
      LandmarkState.locked => (
        'Unlocks at ${_capital(level.name)} (${level.minXp} minutes of focus)',
        null,
      ),
      LandmarkState.busy => ('Finish the ${_inProgress(town)} first.', null),
      LandmarkState.noRoom => (
        'No free 2 x 2 block of plots. Extend your land or clear a plot.',
        null,
      ),
      LandmarkState.ready => ('Not started', 'Start'),
      LandmarkState.inProgress => (
        'Stage ${project!.stage} of ${landmark.stages} '
            '(${project.progress} of ${landmark.totalMinutes} minutes)',
        'Continue',
      ),
      LandmarkState.built => ('Built', null),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: image.when(
                data: (img) => RawImage(image: img, width: 96, height: 96),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(landmark.title, style: theme.textTheme.titleMedium),
                  Text(_hours(landmark.totalMinutes)),
                  const SizedBox(height: 4),
                  Text(status),
                  if (state == LandmarkState.inProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(
                        value: project!.progress / landmark.totalMinutes,
                      ),
                    ),
                  if (button != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(_choose(context)),
                        child: Text(button),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Opens the session sheet on this landmark; once a session has started,
  // returns to the island.
  Future<void> _choose(BuildContext context) async {
    final started = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SessionSetupSheet(landmark: landmark),
    );
    if ((started ?? false) && context.mounted) Navigator.of(context).pop();
  }
}

// The title of the landmark being built, for the ones that wait for it.
String _inProgress(TownState town) => town.buildings
    .firstWhere(
      (b) => b.landmark != null && b.status == BuildingStatus.building,
    )
    .landmark!
    .title;

String _capital(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
