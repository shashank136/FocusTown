import 'package:flutter/material.dart';
import 'package:focus_town/ui/debug_screen.dart';

/// Root widget of the app.
class FocusTownApp extends StatelessWidget {
  /// Creates the root widget.
  const new({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: DebugScreen());
}
