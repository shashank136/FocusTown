import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/app.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/db_recovery.dart';
import 'package:focus_town/platform/local_notifier.dart';
import 'package:focus_town/platform/platform_bootstrap.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = await bootstrapPlatform();
  final notifier = LocalNotifier();
  await notifier.initialize();
  final opened = await openDatabaseSafely(
    dir: await getApplicationDocumentsDirectory(),
    schemaVersion: AppDatabase.currentSchemaVersion,
    open: (file) => AppDatabase(
      LazyDatabase(() => NativeDatabase.createInBackground(file)),
    ),
    clock: platform.clock,
  );
  runApp(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(platform.clock),
        databaseProvider.overrideWithValue(opened.db),
        startupMessageProvider.overrideWithValue(
          opened.startedFresh
              ? "We couldn't load your town and started a new one."
              : null,
        ),
        lifecycleSourceProvider.overrideWithValue(platform.source),
        notifierProvider.overrideWithValue(notifier),
      ],
      child: const FocusTownApp(),
    ),
  );
}
