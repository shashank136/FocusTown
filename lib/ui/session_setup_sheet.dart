import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/session_setup.dart';
import 'package:focus_town/domain/town.dart';

const _recoveryBanner =
    'The Last Builder. All your builders are gone. A wanderer will build '
    'small huts (10 to 20 minutes) and cannot be lost. Finish huts until '
    'you have 3 builders.';

/// Bottom sheet: pick how long to focus, see what it builds and what is at
/// risk, then start (on the next free plot) or choose the plot first.
class SessionSetupSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  ConsumerState<SessionSetupSheet> createState() => _SessionSetupSheetState();
}

class _SessionSetupSheetState extends ConsumerState<SessionSetupSheet> {
  late final Future<int> _last = ref
      .read(townRepositoryProvider)
      .lastDurationMinutes();
  FixedExtentScrollController? _wheel;
  int? _selected; // minutes

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (town.inRecoveryMode)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_recoveryBanner, style: theme.textTheme.bodyMedium),
            ),
          ),
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
                    Center(
                      child: Text(
                        '${o.minutes} min',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: o.enabled ? null : theme.disabledColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(option.tier.name, style: theme.textTheme.titleMedium),
        _preview(option),
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
          Text(
            option.reason!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: option.enabled ? () => _choosePlot(minutes) : null,
              child: const Text('Choose plot…'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: option.enabled
                  ? () => unawaited(_start(minutes))
                  : null,
              child: const Text('Start'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preview(DurationOption option) {
    final image = ref.watch(tierPreviewProvider(option.tier));
    return SizedBox(
      height: 96,
      child: image.when(
        data: (img) => RawImage(image: img, width: 96, height: 96),
        loading: () => const SizedBox(width: 96, height: 96),
        error: (_, _) => const SizedBox(width: 96, height: 96),
      ),
    );
  }

  Future<void> _start(int minutes) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(focusControllerProvider.notifier).start(minutes);
      await ref.read(townRepositoryProvider).saveLastDuration(minutes);
      navigator.pop();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _choosePlot(int minutes) {
    unawaited(ref.read(townRepositoryProvider).saveLastDuration(minutes));
    ref.read(placementProvider.notifier).begin(minutes);
    Navigator.of(context).pop();
  }
}
