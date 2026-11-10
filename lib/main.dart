import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/app.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/platform/local_notifier.dart';
import 'package:focus_town/platform/platform_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = await bootstrapPlatform();
  final notifier = LocalNotifier();
  await notifier.initialize();
  runApp(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(platform.clock),
        lifecycleSourceProvider.overrideWithValue(platform.source),
        notifierProvider.overrideWithValue(notifier),
      ],
      child: const FocusTownApp(),
    ),
  );
}
