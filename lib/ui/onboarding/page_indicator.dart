import 'package:flutter/material.dart';

/// A row of dots with the one at [index] highlighted.
class PageIndicator extends StatelessWidget {
  /// Creates an indicator for [count] pages.
  const new({required this.count, required this.index, super.key});

  /// Number of pages.
  final int count;

  /// The current page.
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Page ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              key: ValueKey('page-dot-$i'),
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index ? scheme.primary : scheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}
