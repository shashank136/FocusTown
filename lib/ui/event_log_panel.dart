import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';

/// Debug panel listing the last lifecycle events.
class EventLogPanel extends ConsumerWidget {
  /// Creates the panel.
  const new({super.key});

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _time(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'
      '.${t.millisecond.toString().padLeft(3, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final native = ref.watch(lifecycleSourceProvider).isNative;
    final events = ref.watch(eventLogProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event log (${native ? 'native' : 'fallback'})'),
        for (final e in events) Text('${_time(e.timestamp.wall)} ${e.name}'),
      ],
    );
  }
}
