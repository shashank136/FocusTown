import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/domain/clock.dart';

/// The app-wide [Clock]; tests override it with a fake.
final clockProvider = Provider<Clock>((ref) => SystemClock());
