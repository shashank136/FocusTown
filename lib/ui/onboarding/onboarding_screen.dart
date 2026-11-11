import 'package:flutter/material.dart';
import 'package:focus_town/game/demo/demo_script.dart';
import 'package:focus_town/ui/onboarding/page_indicator.dart';
import 'package:focus_town/ui/onboarding/town_demo.dart';

const _titles = [
  'Your town grows while you focus.',
  'Leave the app, and your builders stop.',
  'Start your first build.',
];

/// The three first-run pages. [onStart] runs from the last page's button.
class OnboardingScreen extends StatefulWidget {
  /// Creates the screen.
  const new({required this.onStart, super.key});

  /// Called when the user taps Start on the last page.
  final VoidCallback onStart;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == _titles.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) return widget.onStart();
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (var i = 0; i < _titles.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: AspectRatio(
                              key: ValueKey('demo-area-$i'),
                              aspectRatio: 1,
                              child: TownDemo(
                                kind: DemoKind.values[i],
                                active: i == _page,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _titles[i],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall,
                          ),
                          if (i == _titles.length - 1) ...[
                            const SizedBox(height: 12),
                            Text(
                              '10-minute hut',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'So we can warn you before your builders stop.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            PageIndicator(count: _titles.length, index: _page),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _next,
              child: Text(_last ? 'Start' : 'Next'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
