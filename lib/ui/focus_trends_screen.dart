import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/focus_stats.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/town_rules.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Your focus": how much time was focused lately, and the trend.
class FocusTrendsScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(focusStatsProvider);
    final today = LocalDate.fromDateTime(ref.watch(clockProvider).nowWall());
    return Scaffold(
      appBar: AppBar(title: const Text('Your focus')),
      body: stats.when(
        data: (s) => s.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Finish your first session to see how your focus grows.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _Body(s, today),
        error: (e, _) => const Center(child: Text("Couldn't read your focus.")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const new(this.stats, this.today);

  final FocusStats stats;
  final LocalDate today;

  String get _sentence {
    final change = stats.weekChange;
    if (change == null) {
      return 'Keep going: after a week you can compare it with the one before.';
    }
    final pct = (change.abs() * 100).round();
    if (pct == 0) return 'The same as the 7 days before.';
    return '$pct% ${change > 0 ? 'more' : 'less'} than the 7 days before.';
  }

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) today.addDays(i - 6)];
    final thisWeek = TownRules.weekStart(today);
    final weeks = [for (var i = 0; i < 8; i++) thisWeek.addDays(-7 * (7 - i))];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_sentence, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        const Text('Last 7 days'),
        _Bars(
          values: stats.minutesPerDay,
          names: [
            for (final d in days)
              _weekdays[DateTime(d.year, d.month, d.day).weekday - 1],
          ],
          labels: [
            for (final d in days)
              _weekdays[DateTime(d.year, d.month, d.day).weekday - 1][0],
          ],
        ),
        const SizedBox(height: 24),
        const Text('Last 8 weeks'),
        _Bars(
          values: stats.minutesPerWeek,
          names: [for (final w in weeks) 'Week of ${w.day}/${w.month}'],
          labels: [for (final w in weeks) '${w.day}/${w.month}'],
        ),
        const SizedBox(height: 24),
        _Row('Current streak', _days(stats.currentStreak)),
        _Row('Longest streak', _days(stats.longestStreak)),
        _Row('Completed', '${(stats.completionRate * 100).round()}%'),
        _Row('Average session', '${stats.averageMinutes.round()} min'),
        _Row('Longest session', '${stats.longestMinutes} min'),
      ],
    );
  }

  String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
}

class _Row extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );
}

/// One bar per value; every bar reads as "name: n minutes".
class _Bars extends StatelessWidget {
  const new({required this.values, required this.names, required this.labels});

  final List<int> values;
  final List<String> names;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final top = values.reduce((a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                container: true,
                label: '${names[i]}: ${values[i]} minutes',
                excludeSemantics: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: top == 0
                            ? 0.02
                            : 0.02 + 0.8 * values[i] / top,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    Text(labels[i], style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
