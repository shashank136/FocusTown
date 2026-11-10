import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/clock.dart';

/// The app-wide [Clock]; tests override it with a fake.
final clockProvider = Provider<Clock>((ref) => SystemClock());

/// The on-disk database; tests override it with an in-memory one.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'focus_town'));
  ref.onDispose(db.close);
  return db;
});

/// Reads and writes the stored town and sessions.
final townRepositoryProvider = Provider<TownRepository>(
  (ref) =>
      TownRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// The session controller.
final focusControllerProvider =
    AsyncNotifierProvider<FocusController, FocusState>(FocusController.new);
