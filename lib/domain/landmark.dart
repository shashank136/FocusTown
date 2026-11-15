import 'package:focus_town/domain/footprint.dart';
import 'package:focus_town/domain/town_level.dart';

/// A big building that takes several sessions to build.
enum Landmark {
  /// The Great Pyramid: 12 stages of 10 minutes each, from Village.
  greatPyramid(
    title: 'Great Pyramid',
    stages: 12,
    minutesPerStage: 10,
    unlockLevel: TownLevel.village,
    footprint: Footprint.block,
  ),

  /// The Lighthouse of Alexandria: 12 stages of 15 minutes each, from Village.
  lighthouse(
    title: 'Lighthouse of Alexandria',
    stages: 12,
    minutesPerStage: 15,
    unlockLevel: TownLevel.village,
    footprint: Footprint.block,
  ),

  /// The Pagoda: 12 stages of 20 minutes each, from Town.
  pagoda(
    title: 'Pagoda',
    stages: 12,
    minutesPerStage: 20,
    unlockLevel: TownLevel.town,
    footprint: Footprint.block,
  ),

  /// The Taj Mahal: 12 stages of 25 minutes each, from Town.
  tajMahal(
    title: 'Taj Mahal',
    stages: 12,
    minutesPerStage: 25,
    unlockLevel: TownLevel.town,
    footprint: Footprint.block,
  ),

  /// The Statue of Liberty: 12 stages of 30 minutes each, from Town.
  statueOfLiberty(
    title: 'Statue of Liberty',
    stages: 12,
    minutesPerStage: 30,
    unlockLevel: TownLevel.town,
    footprint: Footprint.block,
  ),

  /// The Colosseum: 12 stages of 40 minutes each, from City.
  colosseum(
    title: 'Colosseum',
    stages: 12,
    minutesPerStage: 40,
    unlockLevel: TownLevel.city,
    footprint: Footprint.block,
  ),

  /// The Easter Island Moai: 12 stages of 20 minutes each, from Village.
  easterIsland(
    title: 'Easter Island Moai',
    stages: 12,
    minutesPerStage: 20,
    unlockLevel: TownLevel.village,
    footprint: Footprint.block,
  ),

  /// The Space Needle: 12 stages of 30 minutes each, from Town.
  spaceNeedle(
    title: 'Space Needle',
    stages: 12,
    minutesPerStage: 30,
    unlockLevel: TownLevel.town,
    footprint: Footprint.block,
  ),

  /// Chichén Itzá: 12 stages of 25 minutes each, from Town.
  chichenItza(
    title: 'Chichén Itzá',
    stages: 12,
    minutesPerStage: 25,
    unlockLevel: TownLevel.town,
    footprint: Footprint.block,
  ),

  /// Petra: 12 stages of 30 minutes each, from Town.
  petra(
    title: 'Petra',
    stages: 12,
    minutesPerStage: 30,
    unlockLevel: TownLevel.town,
    footprint: Footprint.block,
  ),

  /// Christ the Redeemer: 12 stages of 40 minutes each, from City.
  christRedeemer(
    title: 'Christ the Redeemer',
    stages: 12,
    minutesPerStage: 40,
    unlockLevel: TownLevel.city,
    footprint: Footprint.block,
  ),

  /// The Great Sphinx of Giza: 12 stages of 25 minutes each, from Town.
  sphinx(
    title: 'Great Sphinx of Giza',
    stages: 12,
    minutesPerStage: 25,
    unlockLevel: TownLevel.town,
    footprint: Footprint.block,
  ),

  /// The Eiffel Tower: 12 stages of 20 minutes each, from Village.
  eiffel(
    title: 'Eiffel Tower',
    stages: 12,
    minutesPerStage: 20,
    unlockLevel: TownLevel.village,
    footprint: Footprint.block,
  );

  new({
    required this.title,
    required this.stages,
    required this.minutesPerStage,
    required this.unlockLevel,
    required this.footprint,
  });

  /// Its name.
  final String title;

  /// How many stages it is built in.
  final int stages;

  /// Minutes of finished sessions each stage needs.
  final int minutesPerStage;

  /// The town level that unlocks it.
  final TownLevel unlockLevel;

  /// The plots it stands on: a rectangle of free plots in one piece.
  final Footprint footprint;

  /// Minutes in all.
  int get totalMinutes => stages * minutesPerStage;
}
