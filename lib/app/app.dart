import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/ui/debug_screen.dart';

/// Root widget of the app; starts routing lifecycle events.
class FocusTownApp extends ConsumerStatefulWidget {
  /// Creates the root widget.
  const new({super.key});

  @override
  ConsumerState<FocusTownApp> createState() => _FocusTownAppState();
}

class _FocusTownAppState extends ConsumerState<FocusTownApp> {
  Timer? _flushTimer;

  @override
  void initState() {
    super.initState();
    final router = ref.read(lifecycleRouterProvider);
    // Forwards a held app switch once the 500 ms lock window has passed.
    _flushTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(router.flushExpired()),
    );
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(home: DebugScreen());
}
