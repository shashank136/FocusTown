import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/app.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/platform/platform_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = await bootstrapPlatform();
  runApp(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(platform.clock),
        lifecycleSourceProvider.overrideWithValue(platform.source),
      ],
      child: const FocusTownApp(),
    ),
  );
}
