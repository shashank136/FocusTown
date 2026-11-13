import 'package:focus_town/domain/town_level.dart';

/// A big building that takes several sessions to build.
enum Landmark {
  /// The Great Pyramid: 12 stages of 10 minutes each, from Village.
  greatPyramid(
    title: 'Great Pyramid',
    stages: 12,
    minutesPerStage: 10,
    unlockLevel: TownLevel.village,
  ),

  /// The Lighthouse of Alexandria: 12 stages of 15 minutes each, from Village.
  lighthouse(
    title: 'Lighthouse of Alexandria',
    stages: 12,
    minutesPerStage: 15,
    unlockLevel: TownLevel.village,
  ),

  /// The Eiffel Tower: 12 stages of 20 minutes each, from Village.
  eiffel(
    title: 'Eiffel Tower',
    stages: 12,
    minutesPerStage: 20,
    unlockLevel: TownLevel.village,
  );

  new({
    required this.title,
    required this.stages,
    required this.minutesPerStage,
    required this.unlockLevel,
  });

  /// Its name.
  final String title;

  /// How many stages it is built in.
  final int stages;

  /// Minutes of finished sessions each stage needs.
  final int minutesPerStage;

  /// The town level that unlocks it.
  final TownLevel unlockLevel;

  /// Minutes in all.
  int get totalMinutes => stages * minutesPerStage;
}
