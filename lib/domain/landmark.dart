/// A big building that takes several sessions to build.
enum Landmark {
  /// The Eiffel Tower: 12 stages of 20 minutes each.
  eiffel(title: 'Eiffel Tower', stages: 12, minutesPerStage: 20);

  new({
    required this.title,
    required this.stages,
    required this.minutesPerStage,
  });

  /// Its name.
  final String title;

  /// How many stages it is built in.
  final int stages;

  /// Minutes of finished sessions each stage needs.
  final int minutesPerStage;

  /// Minutes in all.
  int get totalMinutes => stages * minutesPerStage;
}
