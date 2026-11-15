import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/ui/landmark_text.dart';

void main() {
  test('it says what is needed and what to do', () {
    expect(
      noRoomText('Great Sphinx', const Footprint(4, 2)),
      'Great Sphinx needs 4 x 2 free plots in one piece, not across a road. '
      'There is no such area on your island. Expand the island to make room.',
    );
  });

  test('one plot is said as a plot', () {
    expect(
      noRoomText('Christ the Redeemer', Footprint.one),
      'Christ the Redeemer needs a free plot, and every plot is used. '
      'Expand the island to make room.',
    );
  });

  test('a block bigger than 4 both ways needs two neighbouring sides', () {
    final text = noRoomText('Great Pyramid', const Footprint(5, 5));
    expect(
      text,
      startsWith(
        'Great Pyramid needs 5 x 5 free plots in one piece, not across a '
        'road. There is no such area on your island. Expand the island to '
        'make room.',
      ),
    );
    expect(text, contains('two neighbouring sides'));
    // A 5 x 4 fits in one strip of new land, so it does not say it.
    expect(
      noRoomText('Taj Mahal', const Footprint(5, 4)),
      isNot(contains('neighbouring')),
    );
  });
}
