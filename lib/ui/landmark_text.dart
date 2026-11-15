import 'package:focus_town/domain/plot_grid.dart';

/// What to tell the player when [title] cannot be started because no free area
/// of [size] exists: what it needs and how to make room.
String noRoomText(String title, Footprint size) {
  if (size.area == 1) {
    return '$title needs a free plot, and every plot is used. Expand the '
        'island to make room.';
  }
  final text =
      '$title needs ${size.cols} x ${size.rows} free plots in one piece, not '
      'across a road. There is no such area on your island. Expand the '
      'island to make room.';
  // The roads cut the land into pieces of 4 plots, so a block bigger than 4
  // both ways only fits at a corner, where two sides of new land meet.
  if (size.cols > 4 && size.rows > 4) {
    return '$text A block this big only fits where the roads do not cut it: '
        'expand two neighbouring sides, so the corner between them is land '
        'too.';
  }
  return text;
}
